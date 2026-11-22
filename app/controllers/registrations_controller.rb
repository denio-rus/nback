class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: I18n.t("registrations.rate_limited") }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if register(@user)
      # The typed address goes to the mailer and nowhere else.
      RegistrationsMailer.confirm(@user, @user.email).deliver_now
      redirect_to check_mail_registrations_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def check_mail
  end

  private

  # An account that was never confirmed does not block its address: the new
  # sign up replaces it. If the new account is invalid the old one stays.
  def register(user)
    saved = false
    User.transaction do
      stale = User.find_by_email(user.email)
      stale.destroy! if stale && !stale.confirmed?

      saved = user.save(context: :registration)
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  def user_params
    params.expect(user: [ :nickname, :email, :email_confirmation, :password, :password_confirmation, :gender, :age_decade ])
  end
end
