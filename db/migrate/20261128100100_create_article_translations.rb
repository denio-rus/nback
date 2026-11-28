class CreateArticleTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :article_translations do |t|
      t.references :article, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :title, null: false
      t.text :body, null: false

      t.timestamps
    end
    add_index :article_translations, %i[article_id locale], unique: true
  end
end
