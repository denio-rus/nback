require_relative "application_system_test_case"

# Plays the real reaction_time game in headless Chrome: translated texts,
# the Rails-built submit url and the stored result.
class ReactionTimeGameTest < ApplicationSystemTestCase
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "reaction_time")
  end

  def start_game(locale)
    visit game_path(@game, locale: locale)
    click_on I18n.t("games.show.play", locale: locale)
  end

  test "english texts are shown and the controller connects" do
    start_game(:en)

    assert_selector "h1", text: "Simple reaction time"
    assert_text "Press \"Start\""
    assert_button "Start test"
  end

  test "russian texts are shown" do
    start_game(:ru)

    assert_selector "h1", text: "Тест простой реакции"
    assert_button "Начать тест"
  end

  test "a real key press is stored through the prefixed submit url" do
    start_game(:ru)
    click_on "Начать тест"

    # Press space as soon as the circle turns green, ten times.
    10.times do |index|
      assert_text "Попытка #{index + 1} / 10", wait: 10
      assert_selector "[data-games--reaction-time-target=circle].bg-success", wait: 6
      find("body").send_keys(:space)
      assert_text "Попытка #{index + 1}: ", wait: 3
    end

    assert_text "Тест завершён!", wait: 15
    session = GameSession.order(:id).last
    assert_not_nil session.reload.played_at
    assert_equal 10, session.result["reactions"].size
    assert(session.result["reactions"].all? { |ms| ms.is_a?(Integer) })
    assert_not_nil session.metric
  end
end
