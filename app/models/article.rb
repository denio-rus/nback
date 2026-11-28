# An article or a news item written by an admin. The text is kept per language
# in ArticleTranslation; the default language is required, the others are
# optional and fall back to it.
class Article < ApplicationRecord
  KINDS = %w[article news].freeze
  SLUG_FORMAT = /\A[a-z0-9-]+\z/

  has_many :translations, class_name: "ArticleTranslation", dependent: :destroy, inverse_of: :article
  accepts_nested_attributes_for :translations,
    reject_if: ->(attributes) { attributes[:title].blank? && attributes[:body].blank? }

  validates :slug, presence: true, format: { with: SLUG_FORMAT }, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validate :default_locale_translation_present

  scope :published, -> { where(published_at: ..Time.current) }

  # The translation for the language, or the one in the default language.
  def translation_for(locale)
    by_locale = translations.index_by(&:locale)
    by_locale[locale.to_s] || by_locale[I18n.default_locale.to_s]
  end

  private

  def default_locale_translation_present
    default = I18n.default_locale.to_s
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == default }

    errors.add(:translations, :blank)
  end
end
