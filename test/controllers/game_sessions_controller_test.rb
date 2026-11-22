require "test_helper"

class GameSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "nback")
    @user = users(:one)
  end

  def start_session
    post game_game_sessions_path(@game)
    GameSession.order(:id).last
  end

  # One trial per stimulus. Every answer is right except the first one: there is
  # nothing to match yet, so pressing Match there is exactly one error.
  def valid_result(session)
    sequence = session.setup_game["sequence"]
    n = session.setup_game["n"]
    trials = sequence.each_index.map do |index|
      match = index >= n && sequence[index] == sequence[index - n]
      { rt_ms: nil, correct: true, phase: nil, pressed: index.zero? ? true : match }
    end
    { trials: trials }
  end

  def submit(session, result, game: @game)
    post submit_result_game_game_session_path(game, session), params: { result: result }, as: :json
  end

  test "submit_result stores only whitelisted keys" do
    session = start_session

    submit(session, valid_result(session).merge(evil: 1))

    assert_response :success
    stored = session.reload.result
    assert_equal %w[format trials], stored.keys.sort
    assert_equal 1, stored["format"]
    assert_equal [ false ], stored["trials"].first(1).map { |trial| trial["correct"] }
    assert_not stored.key?("evil")
    assert_not_nil session.played_at
  end

  test "submit_result stores primary and secondary metrics" do
    session = start_session
    total = session.setup_game["sequence"].size

    submit(session, valid_result(session))

    assert_in_delta ((total - 1).to_f / total * 100).round(1), session.reload.metric, 0.01
    assert_equal 1.0, session.metric_secondary
  end

  test "submit_result rejects an impossible result with 422 and stores nothing" do
    session = start_session

    submit(session, { trials: [] })

    assert_response :unprocessable_entity
    assert_nil session.reload.result
    assert_nil session.played_at
  end

  test "submit_result accepts a result only once and keeps the first one" do
    sign_in_as(@user)
    session = start_session
    first = valid_result(session)
    submit(session, first)
    assert_response :success

    submit(session, { trials: first[:trials].map { |trial| trial.merge(pressed: !trial[:pressed]) } })

    assert_response :conflict
    kept = session.reload.result
    assert_equal 19, kept["trials"].count { |trial| trial["correct"] }
  end

  test "a session of a signed in user belongs to that user" do
    sign_in_as(@user)

    assert_equal @user.id, start_session.user_id
  end

  test "another user cannot submit to someone else's session" do
    sign_in_as(@user)
    session = start_session
    sign_out
    sign_in_as(users(:two))

    submit(session, valid_result(session))

    assert_response :not_found
    assert_nil session.reload.result
  end

  test "anonymous visitor cannot submit to a session that has a user" do
    sign_in_as(@user)
    session = start_session
    sign_out

    submit(session, valid_result(session))

    assert_response :not_found
    assert_nil session.reload.result
  end

  test "another user cannot open the play page of someone else's session" do
    sign_in_as(@user)
    session = start_session
    sign_out
    sign_in_as(users(:two))

    get play_game_game_session_path(@game, session)

    assert_response :not_found
  end

  test "anonymous play is allowed and stores no user" do
    session = start_session
    submit(session, valid_result(session))

    assert_response :success
    assert_nil session.reload.user_id
  end

  test "submit_result with a mismatching game id returns 404" do
    session = start_session
    other = Game.find_by!(system_name: "stroop_test")

    submit(session, valid_result(session), game: other)

    assert_response :not_found
    assert_nil session.reload.result
  end

  test "an inactive game cannot be started" do
    @game.update!(active: false)

    assert_no_difference "GameSession.count" do
      post game_game_sessions_path(@game)
    end
    assert_response :not_found
  end
end
