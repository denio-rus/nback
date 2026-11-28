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
  validate :translation_locales_unique

  scope :published, -> { where(published_at: ..Time.current) }

  # Virtual attribute behind the "publish" checkbox. "1" sets the date once and
  # keeps an existing one, "0" clears it, anything else is ignored.
  def publish=(value)
    case ActiveModel::Type::Boolean.new.cast(value)
    when true then self.published_at ||= Time.current
    when false then self.published_at = nil
    end
  end

  def publish = published_at.present?

  # The three states the admin list shows: no date, a date in the future, or live.
  def status
    if published_at.nil? then :draft
    elsif published_at > Time.current then :scheduled
    else :published
    end
  end

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

  # The database index would raise on a repeated language; report it as a validation error instead.
  def translation_locales_unique
    locales = translations.reject(&:marked_for_destruction?).map(&:locale)
    errors.add(:translations, :taken) if locales.uniq.size != locales.size
  end
end
