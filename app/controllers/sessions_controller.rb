class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: I18n.t("sessions.rate_limited") }

  def new
  end

  def create
    user = User.authenticate_by(nickname: stored_nickname, password: params[:password].to_s)

    if user.nil?
      redirect_to new_session_path, alert: t(".invalid")
    elsif !user.confirmed?
      # Only a person who knows the password learns that the account is unconfirmed.
      redirect_to new_session_path, alert: t(".unconfirmed")
    else
      start_new_session_for user
      redirect_to after_authentication_url
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  # authenticate_by compares the nickname exactly, but people type it in any
  # case. An unknown nickname stays unknown (empty string), so the password is
  # still hashed and the answer takes the same time.
  def stored_nickname
    typed = params[:nickname].to_s.strip
    User.where("lower(nickname) = ?", typed.downcase).pick(:nickname) || typed
  end
end
