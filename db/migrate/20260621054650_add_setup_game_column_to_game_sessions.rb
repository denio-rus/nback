class AddSetupGameColumnToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :setup_game, :jsonb
  end
end
