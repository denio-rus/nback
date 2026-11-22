class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 20, within: 3.minutes, only: :show, with: -> { redirect_to new_registration_path, alert: I18n.t("sessions.rate_limited") }

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token].to_s)

    if user
      # Following the same link twice is harmless.
      user.update!(confirmed_at: Time.current) unless user.confirmed?
      start_new_session_for user
      redirect_to games_path, notice: t(".confirmed")
    else
      redirect_to new_registration_path, alert: t(".invalid")
    end
  end
end
