class GameSessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def create
    @game = Game.find(params[:game_id])
    @game_session = GameSession.new(
      game_id: params[:game_id],
      setup_game: @game.game_strategy.setup_game
    ).tap do |session|
      session.user = Current.user if Current.user
    end

    if @game_session.save
      redirect_to play_game_game_session_path(@game.id, @game_session)
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  end

  def play
    @game_session = GameSession.find(params[:id])
    @game = @game_session.game
    render :play
  end

  def submit_results
    @game_session = GameSession.find(params[:id])
    if @game_session.update(
      played_at: Time.current,
      result: @game.game_strategy.handle_result(params[:result])
    )
      render json: @game_session, status: :ok
    else
      render json: @game_session.errors, status: :unprocessable_entity
    end
  end
end
