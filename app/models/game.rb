class Game < ApplicationRecord
  validates :name, :system_name, presence: true
  validates :category, inclusion: { in: Games::CATEGORIES }

  has_many :game_sessions

  # Looked up through the registry: system_name is checked against strategy
  # files and never constantized directly.
  def game_strategy
    @game_strategy ||= Games::Registry.strategy_for(system_name)
  end

  delegate :setup_game, to: :game_strategy
end
