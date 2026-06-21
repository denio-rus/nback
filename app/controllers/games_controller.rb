require "ostruct"

class GamesController < ApplicationController
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
