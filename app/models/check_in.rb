# What a person says about their own state before a game. Everything is
# optional and never judged: the values only give the charts something to
# group by. The database stores keys ("alcohol", "night"), texts come from I18n.
class CheckIn < ApplicationRecord
  FLAGS = %w[alcohol meds illness hungry rested].freeze
  DAY_PHASES = %w[morning day evening night].freeze

  TRUE_VALUES = [ true, "1", "true" ].freeze
  FALSE_VALUES = [ false, "0", "false" ].freeze

  belongs_to :user
  has_many :game_sessions, dependent: :nullify

  before_validation :cast_flags

  validates :sleep_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validates :day_phase, inclusion: { in: DAY_PHASES }, allow_nil: true
  validate :flags_are_known_booleans

  def flag?(key) = flags[key.to_s] == true

  def flag_keys = flags.select { |_key, value| value == true }.keys

  private

  # The form sends "1" and "0". Anything else stays as it is so that
  # validation can reject it.
  def cast_flags
    return unless flags.is_a?(Hash)

    self.flags = flags.to_h.transform_keys(&:to_s).transform_values do |value|
      if TRUE_VALUES.include?(value) then true
      elsif FALSE_VALUES.include?(value) then false
      else value
      end
    end
  end

  def flags_are_known_booleans
    return errors.add(:flags, :invalid) unless flags.is_a?(Hash)

    unknown = flags.keys.map(&:to_s) - FLAGS
    errors.add(:flags, :invalid) if unknown.any?
    errors.add(:flags, :invalid) unless flags.values.all? { |value| value == true || value == false }
  end
end
