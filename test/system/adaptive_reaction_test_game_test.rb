require_relative "application_system_test_case"

# Plays the real adaptive game in headless Chrome: the rule screen before each
# part, two answer buttons, and the trials stored through the submit url.
class AdaptiveReactionTestGameTest < ApplicationSystemTestCase
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "adaptive_reaction_test")
  end

  def start_game(locale)
    visit game_path(@game, locale: locale)
    click_on I18n.t("games.show.play", locale: locale)
  end

  test "english texts and the rule of part 1 are shown" do
    start_game(:en)
    click_on "Start"

    assert_text "Part 1 of 3"
    assert_text "Rule: red is A, green is B"
    assert_button "Begin"
  end

  test "russian texts are shown" do
    start_game(:ru)
    click_on "Начать"

    assert_text "Правило: красный это А, зелёный это Б"
    assert_button "Приступить"
  end

  # The server only checks the colors, so the pauses are shortened to keep the test quick.
  def shorten_pauses
    assert_button "Start" # the play page is loaded, so the session exists
    session = GameSession.where.not(setup_game: nil).order(:id).last
    setup = session.setup_game
    setup["sequence"].transform_values! { |part| part.map { |_delay, color| [ 50, color ] } }
    setup["stimulus_duration"] = 600
    session.update!(setup_game: setup)
    page.refresh
  end

  test "a real play-through stores 105 trials, the first answer and the swapped rule" do
    start_game(:en)
    shorten_pauses
    click_on "Start"
    rules = { 1 => "Rule: red is A, green is B", 2 => "Rule: red is B, green is A", 3 => "Rule: red is A, green is B" }

    3.times do |index|
      assert_text rules.fetch(index + 1), wait: 60
      click_on "Begin"
      next unless index.zero?

      # Answer the first stimulus as soon as the circle shows its color.
      assert_selector "[data-games--adaptive-reaction-test-target=circle].bg-stimulus-red, " \
                      "[data-games--adaptive-reaction-test-target=circle].bg-stimulus-green", wait: 5
      find("button[data-button=a]").click
    end

    assert_text "Test finished!", wait: 240
    session = GameSession.order(:id).last
    # The result is sent right after the finish text appears, so wait for it.
    Timeout.timeout(10) { sleep 0.2 until session.reload.played_at }
    trials = session.result["trials"]
    assert_equal 105, trials.size
    assert_equal [ 1, 2, 3 ], trials.map { |trial| trial["phase"] }.uniq
    assert_equal "a", trials.first["pressed"]
    assert_kind_of Integer, trials.first["rt_ms"]
    assert(trials.drop(1).all? { |trial| trial["pressed"].nil? && trial["correct"] == false })
  end
end
