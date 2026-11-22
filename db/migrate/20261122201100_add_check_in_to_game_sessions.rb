class AddCheckInToGameSessions < ActiveRecord::Migration[8.1]
  def change
    # Deleting a check-in on its own must not delete the game result.
    add_reference :game_sessions, :check_in, null: true, foreign_key: { on_delete: :nullify }
  end
end
