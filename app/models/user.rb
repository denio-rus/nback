class User < ApplicationRecord
  validates :nickname, :email, presence: true
  validates :nickname, :email, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
