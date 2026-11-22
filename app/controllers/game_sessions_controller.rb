class GameSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  before_action :set_active_game, only: :create
  before_action :set_game_session, only: %i[play submit_result]

  def create
    @game_session = @game.game_sessions.new(
      setup_game: @game.game_strategy.setup_game,
      user: Current.user
    )

    if @game_session.save
      redirect_to play_game_game_session_path(@game, @game_session)
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  end

  def play
  end

  def submit_result
    return render json: { error: "already_submitted" }, status: :conflict if @game_session.played_at

    strategy = @game.game_strategy
    result = strategy.handle_result(@game_session.setup_game, params[:result])

    if @game_session.update(
      played_at: Time.current,
      result: result,
      metric: strategy.primary_metric(result),
      metric_secondary: strategy.secondary_metric(result)
    )
      render json: @game_session, status: :ok
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  rescue Games::BaseStrategy::InvalidResult => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_active_game
    @game = Game.where(active: true).find(params[:game_id])
  end

  # A session is reachable only through its own game. A session with an owner
  # is reachable only by that owner; anonymous sessions stay open by id.
  def set_game_session
    @game_session = GameSession.includes(:game).find_by!(id: params[:id], game_id: params[:game_id])
    @game = @game_session.game
    raise ActiveRecord::RecordNotFound unless owner_or_anonymous?(@game_session)
  end

  def owner_or_anonymous?(game_session)
    game_session.user_id.nil? || game_session.user_id == Current.user&.id
  end
end
