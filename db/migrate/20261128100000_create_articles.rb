# An article or a news item. The texts live in article_translations, one row
# per language.
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :slug, null: false
      t.string :kind, null: false, default: "article"
      t.datetime :published_at

      t.timestamps
    end
    add_index :articles, :slug, unique: true
    add_index :articles, :kind
  end
end
