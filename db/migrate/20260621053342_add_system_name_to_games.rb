class AddSystemNameToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :system_name, :string, null: false

    add_index :games, :system_name, unique: true
  end
end
