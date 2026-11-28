# Anonymous on purpose: no user_id, no IP, no user agent. Only the text, the
# kind and the language of the page it was sent from.
class CreateFeedbackMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_messages do |t|
      t.string :kind, null: false
      t.text :body, null: false
      t.string :locale, null: false

      t.timestamps
    end
    add_index :feedback_messages, :created_at
  end
end
