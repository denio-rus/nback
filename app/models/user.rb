class User < ApplicationRecord
  NICKNAME_FORMAT = /\A[A-Za-z0-9_.\-]{3,20}\z/
  GENDERS = %w[female male other].freeze
  AGE_DECADES = (10..90).step(10).to_a.freeze

  rolify
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :game_sessions, dependent: :destroy
  has_many :check_ins, dependent: :destroy

  # The address itself is never stored: only its HMAC (see email_pepper.rb).
  attr_readonly :nickname
  attr_reader :email

  generates_token_for :email_confirmation, expires_in: 24.hours do
    password_salt&.last(10)
  end

  # The form sends an empty string for "prefer not to say".
  normalizes :gender, with: ->(value) { value.presence }

  validates :nickname, format: { with: NICKNAME_FORMAT }
  validates :nickname, uniqueness: { case_sensitive: false }
  validates :email_digest, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
  # Typed twice at sign up; the second copy is only compared, never stored.
  validates :email, confirmation: { case_sensitive: false }
  validates :email_confirmation, presence: true, on: :registration
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :age_decade, inclusion: { in: AGE_DECADES }, allow_nil: true

  class << self
    def email_digest_for(email)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.email_pepper, email.to_s.strip.downcase)
    end

    def find_by_email(email)
      return if email.blank?

      find_by(email_digest: email_digest_for(email))
    end
  end

  # Virtual attribute: remembers the typed address only for validation and for
  # the mail that is sent right after sign up; the database gets the digest.
  def email=(value)
    @email = value.to_s.strip.presence
    self.email_digest = @email && self.class.email_digest_for(@email)
  end

  def email_confirmation=(value)
    @email_confirmation = value.to_s.strip.presence
  end

  def confirmed? = confirmed_at.present?

  def add_default_role = add_role(:player)
end
