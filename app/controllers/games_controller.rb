class GamesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def index
    @games = Game.all
  end

  def show
    @game = Game.find(params[:id])
  end

  def play
    redirect_to game_game_sessions_path(game_id: params[:id])
  end
end
