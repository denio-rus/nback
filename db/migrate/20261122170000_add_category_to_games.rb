class AddCategoryToGames < ActiveRecord::Migration[8.1]
  def change
    # Existing rows get a placeholder so the NOT NULL constraint can be added;
    # Games::Registry.sync! overwrites it with the strategy's own category.
    add_column :games, :category, :string, null: false, default: "executive"
    change_column_default :games, :category, from: "executive", to: nil
    add_index :games, :category
  end
end
