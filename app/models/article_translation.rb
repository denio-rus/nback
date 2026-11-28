# The title and the Markdown body of an Article in one language.
class ArticleTranslation < ApplicationRecord
  belongs_to :article, inverse_of: :translations

  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } },
    uniqueness: { scope: :article_id }
  validates :title, :body, presence: true
end
