class RegistrationsMailer < ApplicationMailer
  # The address is passed in because the database only keeps its digest.
  def confirm(user, email)
    @token = user.generate_token_for(:email_confirmation)
    mail subject: I18n.t("mailers.registrations.confirm.subject"), to: email
  end
end
