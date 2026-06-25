class Game < ApplicationRecord
  validates :name, :system_name, presence: true

  has_many :game_sessions

  def game_strategy
    @game_strategy ||= "Games::#{system_name.camelize}Strategy".constantize.new
  end

  delegate :setup_game, :handle_result, to: :game_strategy
end
