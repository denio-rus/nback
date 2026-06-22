class User < ApplicationRecord
  validates :nickname, :email, presence: true
  validates :nickname, :email, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
