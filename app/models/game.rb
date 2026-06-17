class Game < ApplicationRecord
  validates :name, presence: true

  has_many :game_sessions

  def game_strategy
    @game_strategy ||= "Games::#{name.camelize}Strategy".constantize.new
  end

  delegate :next_stimulus, to: :game_strategy
end
