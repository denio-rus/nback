require "test_helper"

# The optional check-in before a game: form for signed in users, skipped for
# anonymous visitors, never required.
class CheckInFormTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "reaction_time")
    @user = users(:one)
  end

  def start(params = {})
    post game_game_sessions_path(@game), params: params
  end

  def last_session = GameSession.order(:id).last

  test "game page sends a signed in user to the form" do
    sign_in_as(@user)
    get game_path(@game)

    assert_select "a[href=?]", new_game_game_session_path(@game)
  end

  test "game page lets an anonymous visitor start at once" do
    get game_path(@game)

    assert_select "a[href=?][data-turbo-method=post]", game_game_sessions_path(@game)
  end

  test "new shows form for signed in user" do
    sign_in_as(@user)
    get new_game_game_session_path(@game)

    assert_response :success
    assert_select "form[action=?]", game_game_sessions_path(@game)
    assert_select "input[name=?][step=?]", "check_in[sleep_hours]", "0.5"
    CheckIn::DAY_PHASES.each do |phase|
      assert_select "input[type=radio][name=?][value=?]", "check_in[day_phase]", phase
    end
    assert_select "input[type=radio][checked]", count: 0
    CheckIn::FLAGS.each do |flag|
      assert_select "input[type=checkbox][name=?]", "check_in[flags][#{flag}]"
    end
    assert_select "button[name=skip], input[name=skip]", count: 1
    assert_select "body", /graphs|charts/i
  end

  test "anonymous does not see the form" do
    get new_game_game_session_path(@game)

    assert_redirected_to game_path(@game)
    assert_select "form[action=?]", game_game_sessions_path(@game), count: 0
  end

  test "anonymous start creates no check-in even if one is sent" do
    assert_no_difference "CheckIn.count" do
      assert_difference "GameSession.count", 1 do
        start(check_in: { day_phase: "night" })
      end
    end
    assert_nil last_session.check_in_id
  end

  test "skip creates session without check_in" do
    sign_in_as(@user)

    assert_no_difference "CheckIn.count" do
      assert_difference "GameSession.count", 1 do
        start(skip: "1", check_in: { day_phase: "night", sleep_hours: "6" })
      end
    end
    assert_nil last_session.check_in_id
    assert_redirected_to play_game_game_session_path(@game, last_session)
  end

  test "an empty form creates session without check_in" do
    sign_in_as(@user)

    assert_no_difference "CheckIn.count" do
      assert_difference "GameSession.count", 1 do
        start(check_in: { sleep_hours: "", day_phase: "", flags: { alcohol: "0", meds: "0", rested: "0" } })
      end
    end
    assert_nil last_session.check_in_id
  end

  test "starting with no parameters at all still works" do
    sign_in_as(@user)

    assert_difference "GameSession.count", 1 do
      start
    end
    assert_nil last_session.check_in_id
  end

  test "submitted form creates check_in and links it" do
    sign_in_as(@user)

    assert_difference [ "CheckIn.count", "GameSession.count" ], 1 do
      start(check_in: { sleep_hours: "6.5", day_phase: "evening", flags: { alcohol: "1", meds: "0", rested: "1" } })
    end

    check_in = CheckIn.order(:id).last
    assert_equal @user, check_in.user
    assert_equal BigDecimal("6.5"), check_in.sleep_hours
    assert_equal "evening", check_in.day_phase
    assert_equal %w[alcohol rested], check_in.flag_keys.sort
    assert_equal check_in, last_session.check_in
    assert_equal @user, last_session.user
    assert_redirected_to play_game_game_session_path(@game, last_session)
  end

  test "a form with only a day phase is enough" do
    sign_in_as(@user)

    assert_difference "CheckIn.count", 1 do
      start(check_in: { day_phase: "morning" })
    end
    assert_nil CheckIn.order(:id).last.sleep_hours
  end

  test "unknown flag key is rejected: it never reaches the database" do
    sign_in_as(@user)

    start(check_in: { day_phase: "day", flags: { cannabis: "1", alcohol: "1" } })

    assert_equal({ "alcohol" => true }, CheckIn.order(:id).last.flags)
  end

  test "a form with only an unknown flag creates no check-in" do
    sign_in_as(@user)

    assert_no_difference "CheckIn.count" do
      start(check_in: { flags: { cannabis: "1" } })
    end
  end

  test "non boolean flag value is rejected" do
    sign_in_as(@user)

    assert_no_difference [ "CheckIn.count", "GameSession.count" ] do
      start(check_in: { flags: { alcohol: "maybe" } })
    end
    assert_response :unprocessable_content
  end

  test "unknown day phase is rejected" do
    sign_in_as(@user)

    assert_no_difference [ "CheckIn.count", "GameSession.count" ] do
      start(check_in: { day_phase: "lunch" })
    end
    assert_response :unprocessable_content
  end

  test "invalid sleep_hours re-renders form" do
    sign_in_as(@user)

    assert_no_difference [ "CheckIn.count", "GameSession.count" ] do
      start(check_in: { sleep_hours: "99", day_phase: "day" })
    end

    assert_response :unprocessable_content
    assert_select "form[action=?]", game_game_sessions_path(@game)
    assert_select "#error_explanation li", minimum: 1
    assert_select "input[name=?][value=?]", "check_in[sleep_hours]", "99"
    assert_select "input[type=radio][value=day][checked]"
  end

  test "sleep_hours that is not a number is rejected" do
    sign_in_as(@user)

    assert_no_difference "GameSession.count" do
      start(check_in: { sleep_hours: "lots" })
    end
    assert_response :unprocessable_content
  end

  test "check_in belongs to current user even if a user id is sent" do
    sign_in_as(@user)

    start(check_in: { day_phase: "day", user_id: users(:two).id })

    assert_equal @user, CheckIn.order(:id).last.user
    assert_equal 0, users(:two).check_ins.where(day_phase: "day").count
  end

  test "an inactive game gives no form and no session" do
    sign_in_as(@user)
    @game.update!(active: false)

    get new_game_game_session_path(@game)
    assert_response :not_found

    assert_no_difference [ "CheckIn.count", "GameSession.count" ] do
      start(check_in: { day_phase: "day" })
    end
    assert_response :not_found
  end

  test "the form and its errors are in the language of the request" do
    sign_in_as(@user)

    get new_game_game_session_path(@game, locale: :ru)
    assert_select "button[name=skip]", text: I18n.t("check_ins.form.skip", locale: :ru)
    assert_no_match(/translation missing/i, response.body)

    post game_game_sessions_path(@game, locale: :ru), params: { check_in: { sleep_hours: "99" } }
    assert_select "#error_explanation", text: /#{I18n.t("check_ins.form.errors.sleep_hours", locale: :ru)}/
  end

  test "form texts do not judge the person" do
    %i[en ru].each do |locale|
      texts = I18n.t("check_ins", locale: locale).to_s
      assert_no_match(/\b(worse|better|normal|bad|good|tired|fatigue)\b/i, texts) if locale == :en
      assert_no_match(/(хуже|лучше|норма|плохо|устал)/i, texts) if locale == :ru
    end
  end
end
