class CreateCheckIns < ActiveRecord::Migration[8.1]
  def change
    create_table :check_ins do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :sleep_hours, precision: 3, scale: 1
      t.string :day_phase
      t.jsonb :flags, null: false, default: {}

      t.timestamps
    end
  end
end
