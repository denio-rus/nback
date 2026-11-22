class AddMetricsToGameSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :game_sessions, :metric, :float
    add_column :game_sessions, :metric_secondary, :float
  end
end
