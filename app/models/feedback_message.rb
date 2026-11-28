# A note from a visitor. It carries no author and no network data, so it can
# not be traced back to a person.
class FeedbackMessage < ApplicationRecord
  KINDS = %w[bug idea other].freeze
  MAX_BODY = 2000

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true, length: { maximum: MAX_BODY }
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
end
