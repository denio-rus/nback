# "My trends": charts of the signed in user's own play-throughs. Nothing here
# reads another person's data: every query starts from Current.user.
class InsightsController < ApplicationController
  def index
    @games_by_category = Game.where(active: true).order(:system_name).group_by(&:category)
    @sections = Games::CATEGORIES.select { |key| @games_by_category.key?(key) }
    @counts = Current.user.game_sessions.where.not(played_at: nil).where.not(metric: nil).group(:game_id).count
  end

  def show
    @game = Game.where(active: true).find(params[:id])
    @strategy = @game.game_strategy
    @series = Insights::Series.new(user: Current.user, game: @game)
  end
end
