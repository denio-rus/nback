require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  EVALUATIVE = /worse|better|tired|хуже|лучше|усталость/i

  setup do
    Games::Registry.sync!
    Game.where(system_name: Games::Registry.system_names).update_all(active: true)
    @game = Game.find_by!(system_name: "reaction_time")
    @user = users(:one)
    @day = Time.zone.local(2026, 6, 1, 12)
  end

  def play(metric, user: @user, game: @game, check_in: nil, days: 0, secondary: 1)
    GameSession.create!(game: game, user: user, check_in: check_in, setup_game: {}, result: {},
                        metric: metric, metric_secondary: secondary, played_at: @day + days.days)
  end

  def note(flags: {}, user: @user, **rest) = user.check_ins.create!(flags: flags, **rest)

  def points = css_select("[data-point]")

  test "index groups games by category" do
    sign_in_as(@user)
    play(300)
    get insights_path

    assert_response :success
    sections = css_select("[data-category]").map { |node| node["data-category"] }
    present = Game.where(active: true).distinct.pluck(:category)
    assert_equal Games::CATEGORIES.select { |key| present.include?(key) }, sections
    assert_select "[data-category=vigilance] h2", text: "Vigilance"
  end

  test "index shows the number of play-throughs and a note for games without any" do
    sign_in_as(@user)
    2.times { |i| play(300 + i) }
    play(310, user: users(:two))
    get insights_path

    assert_select "[data-game='#{@game.id}']", text: /2 play-throughs/
    assert_select "[data-game='#{@game.id}'] a[href=?]", insight_path(@game)
    assert_select "[data-game='#{Game.find_by!(system_name: 'nback').id}']", text: /No play-throughs yet/
  end

  test "index lists only active games" do
    sign_in_as(@user)
    Game.find_by!(system_name: "nback").update!(active: false)
    get insights_path

    assert_select "[data-game='#{Game.find_by!(system_name: 'nback').id}']", 0
  end

  test "show lists a link to every point" do
    sign_in_as(@user)
    sessions = 3.times.map { |i| play(300 + i, days: i) }
    get insight_path(@game)

    assert_response :success
    links = css_select("[data-chart=dates] a[data-point]").map { |node| node["href"] }
    assert_equal sessions.map { |s| game_session_path(s) }, links
  end

  test "a point shows the main metric with the secondary one in brackets" do
    sign_in_as(@user)
    play(312, secondary: 4)
    get insight_path(@game)

    assert_select "[data-chart=dates] a[data-point] title", text: /312 ms \(missed: 4\)/
  end

  test "show hides median under 5 points" do
    sign_in_as(@user)
    4.times { |i| play(300 + i, days: i) }
    get insight_path(@game)

    assert_select "[data-summary=all]", text: /4 play-throughs/
    assert_select "[data-summary=all]", text: /median/i, count: 0
  end

  test "show displays median at 5 points" do
    sign_in_as(@user)
    5.times { |i| play(300 + i, days: i) }
    get insight_path(@game)

    assert_select "[data-summary=all]", text: "5 play-throughs, median 302 ms, range 300 to 304 ms"
  end

  test "show has one block per flag with and without counts" do
    sign_in_as(@user)
    play(300, check_in: note(flags: { "rested" => true }))
    play(310, check_in: note(flags: { "rested" => false }))
    play(320, check_in: note(flags: { "rested" => false }))
    get insight_path(@game)

    assert_equal CheckIn::FLAGS.sort, css_select("[data-flag]").map { |node| node["data-flag"] }.sort
    assert_select "[data-flag=rested] [data-summary=with]", text: "With “Feeling rested”: 1 play-through"
    assert_select "[data-flag=rested] [data-summary=without]", text: "Without “Feeling rested”: 2 play-throughs"
  end

  test "flag groups use a circle with the flag and a diamond without it" do
    sign_in_as(@user)
    play(300, check_in: note(flags: { "rested" => true }))
    play(310, check_in: note(flags: { "rested" => false }))
    get insight_path(@game)

    assert_select "[data-flag=rested] svg [data-group=with] a[data-point] circle", 1
    assert_select "[data-flag=rested] svg [data-group=without] a[data-point] polygon", 1
  end

  test "sleep chart is shown only with sleep hours and points link to the session" do
    sign_in_as(@user)
    noted = play(300, check_in: note(sleep_hours: 6.5))
    play(310)
    get insight_path(@game)

    assert_equal [ game_session_path(noted) ], css_select("[data-chart=sleep] a[data-point]").map { |n| n["href"] }
    assert_select "[data-chart=sleep] [data-axis-label]", text: "Hours of sleep"
  end

  test "no sleep chart without sleep hours" do
    sign_in_as(@user)
    play(300, check_in: note(flags: { "rested" => true }))
    get insight_path(@game)

    assert_select "[data-chart=sleep]", 0
  end

  test "day phase groups appear only for phases with points" do
    sign_in_as(@user)
    play(300, check_in: note(day_phase: "night"))
    get insight_path(@game)

    assert_select "[data-day-phase]", 1
    assert_select "[data-day-phase=night]", text: "Night: 1 play-through"
  end

  test "show without play-throughs says so and has no chart" do
    sign_in_as(@user)
    get insight_path(@game)

    assert_response :success
    assert_select "[data-chart]", 0
    assert_select "main", text: /No play-throughs yet/
  end

  test "the same-device note is shown" do
    sign_in_as(@user)
    play(300)
    get insight_path(@game)

    assert_select "[data-same-device]", text: "Compare play-throughs on the same device"
  end

  test "other users data never appears" do
    sign_in_as(@user)
    stranger = play(777, user: users(:two), check_in: note(user: users(:two), flags: { "rested" => true }, sleep_hours: 9))
    mine = play(300)
    get insight_path(@game)

    assert_response :success
    assert_equal [ game_session_path(mine) ], css_select("a[data-point]").map { |n| n["href"] }.uniq
    assert_no_match(/777|#{game_session_path(stranger)}/, response.body)
  end

  test "an inactive or unknown game is a 404" do
    sign_in_as(@user)
    @game.update!(active: false)
    get insight_path(@game)
    assert_response :not_found

    get insight_path(id: 0)
    assert_response :not_found
  end

  test "anonymous redirected to sign in" do
    get insights_path
    assert_redirected_to new_session_path

    get insight_path(@game)
    assert_redirected_to new_session_path
  end

  test "the header links to the page for a signed in user only" do
    get games_path
    assert_select "nav a[href=?]", insights_path, 0

    sign_in_as(@user)
    get games_path
    assert_select "nav a[href=?]", insights_path, text: "My trends"
  end

  I18n.available_locales.each do |locale|
    test "pages have no evaluative words and no missing translations in #{locale}" do
      sign_in_as(@user)
      Game.where(system_name: Games::Registry.system_names).find_each do |game|
        6.times do |i|
          play(300 + i, game: game, days: i, check_in: note(flags: { "alcohol" => i.odd? }, sleep_hours: 5 + i, day_phase: "night"))
        end
      end
      [ insights_path(locale: locale), insight_path(@game, locale: locale) ].each do |path|
        get path

        assert_response :success
        assert_no_match(/translation missing/i, response.body, path)
        assert_no_match(EVALUATIVE, css_select("main").to_s, path)
      end
    end
  end
end
