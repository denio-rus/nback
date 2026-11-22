class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: I18n.t("passwords.rate_limited") }

  def new
  end

  def create
    email = params[:email].to_s.strip
    user = User.find_by_email(email)
    PasswordsMailer.reset(user, email).deliver_now if user&.confirmed?

    redirect_to new_session_path, notice: t("passwords.create.sent")
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: t("passwords.update.success")
    else
      redirect_to edit_password_path(params[:token]), alert: t("passwords.update.mismatch")
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: t("passwords.invalid_token")
    end
end
