class GameSession < ApplicationRecord
  belongs_to :game
  belongs_to :user, optional: true
  belongs_to :check_in, optional: true
end
