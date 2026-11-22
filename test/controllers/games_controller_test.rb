require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    Game.where(system_name: %w[MyString MyString1]).update_all(active: false)
  end

  test "should get index" do
    get games_url

    assert_response :success
  end

  test "index lists only active games" do
    Game.find_by!(system_name: "nback").update!(active: false)

    get games_url

    assert_response :success
    assert_select "h3", text: "Simple reaction time"
    assert_select "h3", text: "N-Back", count: 0
  end

  test "show hides an inactive game" do
    game = Game.find_by!(system_name: "nback")
    game.update!(active: false)

    get game_url(game)

    assert_response :not_found
  end

  test "show works for an active game" do
    get game_url(Game.find_by!(system_name: "nback"))

    assert_response :success
  end
end
