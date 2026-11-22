require "test_helper"

class GameSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "nback")
  end

  def start_session
    post game_game_sessions_path(@game)
    GameSession.order(:id).last
  end

  test "submit_result stores only whitelisted keys" do
    session = start_session
    total = session.setup_game["sequence"].size

    post submit_result_game_game_session_path(@game, session),
         params: { result: { correct: total - 1, errors: 1, total_trials: total, evil: 1 } },
         as: :json

    assert_response :success
    assert_equal({ "correct" => total - 1, "errors" => 1, "total_trials" => total },
                 session.reload.result)
    assert_not_nil session.played_at
  end

  test "submit_result rejects an impossible result with 422" do
    session = start_session

    post submit_result_game_game_session_path(@game, session),
         params: { result: { correct: 999, errors: 0, total_trials: 20 } },
         as: :json

    assert_response :unprocessable_entity
    assert_nil session.reload.result
  end
end
