require_relative "application_system_test_case"

# Plays the real Stroop game in headless Chrome: translated texts, the color
# buttons keep their English data-color keys, and the result is stored.
class StroopTestGameTest < ApplicationSystemTestCase
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "stroop_test")
  end

  def start_game(locale)
    visit game_path(@game, locale: locale)
    click_on I18n.t("games.show.play", locale: locale)
  end

  test "english texts are shown" do
    start_game(:en)

    assert_selector "h1", text: "Stroop test"
    assert_text "Press \"Start\""
    assert_button "Start"
  end

  test "russian texts are shown and color keys stay in English" do
    start_game(:ru)

    assert_selector "h1", text: "Тест Струпа"
    click_on "Начать"

    assert_button "Красный"
    assert_button "Зелёный"
    assert_selector "button[data-color=red]", text: "Красный"
    assert_selector "button[data-color=yellow]", text: "Жёлтый"
  end

  test "a full play-through is stored" do
    start_game(:en)
    click_on "Start"

    # 50 stimuli of 2000 ms plus the start delay.
    assert_text "Game over!", wait: 120
    session = GameSession.order(:id).last
    assert_not_nil session.reload.played_at
    trials = session.result["trials"]
    assert_equal 50, trials.size
    assert(trials.all? { |trial| trial["answer"].nil? && trial["rt_ms"].nil? && trial["correct"] == false })
  end

  test "a real click is stored with the pressed color and a time" do
    start_game(:en)
    click_on "Start"
    assert_selector "button[data-color=red]", wait: 5
    sleep 1.2 # the first stimulus appears one second after Start
    find("button[data-color=red]").click

    assert_text "Game over!", wait: 120
    first = GameSession.order(:id).last.reload.result["trials"].first
    assert_equal "red", first["answer"]
    assert_kind_of Integer, first["rt_ms"]
    assert_equal (@game.game_sessions.order(:id).last.setup_game["sequence"].first.last == "red"), first["correct"]
  end
end
