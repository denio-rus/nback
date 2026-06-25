class User < ApplicationRecord
  validates :nickname, :email_address, presence: true
  validates :nickname, :email_address, uniqueness: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :game_sessions, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
