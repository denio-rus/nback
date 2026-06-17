class Game < ApplicationRecord
    validates :name, presence: true

    has_many :game_sessions
end
