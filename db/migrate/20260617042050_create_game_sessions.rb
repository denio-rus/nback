class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.jsonb :result
      t.datetime :played_at
      t.references :game, null: false, foreign_key: true

      t.timestamps
    end
  end
end
