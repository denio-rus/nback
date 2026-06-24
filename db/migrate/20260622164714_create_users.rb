class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :nickname, null: false
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :nickname, unique: true
  end
end
