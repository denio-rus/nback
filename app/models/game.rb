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

  # Texts live in I18n (config/locales/games/<system_name>.<locale>.yml).
  # The name and description columns only keep the default-language copy.
  def title = I18n.t!("games.#{system_name}.title")

  def description = I18n.t!("games.#{system_name}.description")
end
