class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: false

      t.timestamps
    end
  end
end
