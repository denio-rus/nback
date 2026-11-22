require_relative "application_system_test_case"

# Plays the real n-back game in headless Chrome: translated texts and the
# result stored through the prefixed submit url.
class NbackGameTest < ApplicationSystemTestCase
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "nback")
  end

  def start_game(locale)
    visit game_path(@game, locale: locale)
    click_on I18n.t("games.show.play", locale: locale)
  end

  test "english texts are shown" do
    start_game(:en)

    assert_selector "h1", text: "N-Back (N=2)"
    assert_text "Press \"Start\""
    assert_button "Start"
    assert_button "Match"
  end

  test "russian texts are shown" do
    start_game(:ru)

    assert_selector "h1", text: "N-Back (N=2)"
    assert_button "Начать"
    assert_button "Совпадает"
    assert_text "Правильно"
  end

  test "a full play-through is stored" do
    start_game(:ru)
    click_on "Начать"

    # 20 stimuli of 1500 ms plus the start delay.
    assert_text "Игра окончена!", wait: 45
    session = GameSession.order(:id).last
    assert_not_nil session.reload.played_at
    assert_equal 20, session.result["total_trials"]
    assert_equal 20, session.result["correct"] + session.result["errors"]
    assert_not_nil session.metric
  end
end
