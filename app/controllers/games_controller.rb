class GamesController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session

  def index
    @games = Game.where(active: true).order(:category, :system_name)
  end

  def show
    @game = Game.where(active: true).find(params[:id])
  end

  def play
    redirect_to game_game_sessions_path(game_id: params[:id])
  end
end
