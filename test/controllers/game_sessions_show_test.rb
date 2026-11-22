require "test_helper"

# The breakdown page of one finished play-through: only its owner sees it.
class GameSessionsShowTest < ActionDispatch::IntegrationTest
  EVALUATIVE = /worse|better|tired|хуже|лучше|усталость/i

  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "reaction_time")
    @user = users(:one)
  end

  def trial(rt_ms, correct: !rt_ms.nil?, **extra)
    { "rt_ms" => rt_ms, "correct" => correct, "phase" => nil }.merge(extra.stringify_keys)
  end

  def finished_session(trials: nil, game: @game, user: @user, check_in: nil, played_at: Time.current, **metrics)
    strategy = game.game_strategy
    result = trials ? { "format" => 1, "trials" => trials } : { "format" => 1 }
    metrics = { metric: strategy.primary_metric(result), metric_secondary: strategy.secondary_metric(result) } if metrics.empty?
    GameSession.create!(game: game, user: user, check_in: check_in, setup_game: strategy.setup_game,
                        result: result, played_at: played_at, **metrics)
  end

  def metric_text = css_select("[data-metric]").first.text.squish

  def block_texts = css_select("[data-block]").map { |node| node.text.squish }

  test "owner sees session" do
    sign_in_as(@user)
    get game_session_path(finished_session(trials: (1..10).map { |i| trial(200 + i * 10) }))

    assert_response :success
    assert_equal "255 ms (missed: 0)", metric_text
    assert_select "h1", text: @game.title
  end

  test "other user gets 404" do
    sign_in_as(users(:two))
    get game_session_path(finished_session)

    assert_response :not_found
  end

  test "anonymous session and unknown id give 404" do
    sign_in_as(@user)
    get game_session_path(finished_session(user: nil))
    assert_response :not_found

    get game_session_path(id: 0)
    assert_response :not_found
  end

  test "anonymous redirected to sign in" do
    get game_session_path(finished_session)

    assert_redirected_to new_session_path
  end

  test "unfinished session returns 404" do
    sign_in_as(@user)
    get game_session_path(finished_session(played_at: nil, metric: nil, metric_secondary: nil))

    assert_response :not_found
  end

  test "session without trials shows only the main metric" do
    sign_in_as(@user)
    get game_session_path(finished_session(metric: 312.0, metric_secondary: nil))

    assert_response :success
    assert_equal "312 ms", metric_text
    assert_select "[data-block]", 0
    assert_select "[data-trial]", 0
  end

  test "fewer than 10 trials show only the strip" do
    sign_in_as(@user)
    get game_session_path(finished_session(trials: Array.new(9) { trial(300) }))

    assert_select "[data-block]", 0
    assert_select "[data-trial]", 9
  end

  test "100 trials show 5 blocks" do
    sign_in_as(@user)
    trials = Array.new(100) { |i| trial(300, correct: i >= 20 || i.odd?) }
    get game_session_path(finished_session(trials: trials))

    assert_equal 5, block_texts.size
    assert_equal "Block 1: median 300 ms, errors 50%", block_texts.first
    assert_equal "Block 5: median 300 ms, errors 0%", block_texts.last
    assert_select "[data-trial]", 100
  end

  test "strip uses a circle for right, a square for wrong and a dash for a miss" do
    sign_in_as(@user)
    get game_session_path(finished_session(trials: [ trial(300), trial(400, correct: false), trial(nil) ]))

    assert_equal %w[correct wrong miss], css_select("[data-trial]").map { |node| node["data-trial"] }
    assert_select "[data-trial=correct] circle.fill-success", 1
    assert_select "[data-trial=wrong] rect.fill-danger", 1
    assert_select "[data-trial=miss] line.stroke-ink-muted", 1
  end

  test "check-in values are shown as text" do
    sign_in_as(@user)
    check_in = @user.check_ins.create!(sleep_hours: 6.5, day_phase: "night", flags: { "alcohol" => true, "meds" => false })
    get game_session_path(finished_session(check_in: check_in))

    text = css_select("[data-check-in]").first.text.squish
    assert_includes text, "6.5"
    assert_includes text, "Night"
    assert_includes text, "Alcohol"
    assert_not_includes text, "Medication"
  end

  test "no check-in block without a check-in" do
    sign_in_as(@user)
    get game_session_path(finished_session)

    assert_select "[data-check-in]", 0
  end

  test "adaptive test shows one block per part and the switch cost" do
    sign_in_as(@user)
    adaptive = Game.find_by!(system_name: "adaptive_reaction_test")
    trials = [ [ 1, 300 ], [ 1, 340 ], [ 2, 450 ], [ 2, 470 ], [ 3, 320 ], [ 3, 330 ] ].map do |phase, rt|
      trial(rt, phase: phase, shown: "red", pressed: "a")
    end
    get game_session_path(finished_session(trials: trials, game: adaptive))

    assert_equal [ "Part 1: median 320 ms, errors 0%", "Part 2: median 460 ms, errors 0%",
                   "Part 3: median 325 ms, errors 0%" ], block_texts
    assert_equal "Difference between medians of parts 1 and 2: 140 ms", css_select("[data-switch-cost]").first.text.squish
  end

  test "switch cost is absent for other games" do
    sign_in_as(@user)
    get game_session_path(finished_session(trials: Array.new(10) { trial(300) }))

    assert_select "[data-switch-cost]", 0
  end

  test "a trial with text in a value is escaped" do
    sign_in_as(@user)
    get game_session_path(finished_session(trials: [ trial(300, answer: "<script>x</script>") ]))

    assert_no_match(/<script>x/, response.body)
  end

  I18n.available_locales.each do |locale|
    test "page has no evaluative words in #{locale}" do
      sign_in_as(@user)
      Game.where(system_name: Games::Registry.system_names).find_each do |game|
        trials = Array.new(30) { |i| trial(200 + i, correct: i % 4 != 0, phase: game.game_strategy.phases.first) }
        check_in = @user.check_ins.create!(sleep_hours: 5, day_phase: "night", flags: { "alcohol" => true })
        get game_session_path(finished_session(trials: trials, game: game, check_in: check_in), locale: locale)

        assert_response :success
        assert_no_match(/translation missing/i, response.body)
        assert_no_match(EVALUATIVE, css_select("main").to_s, game.system_name)
      end
    end
  end
end
