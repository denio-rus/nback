class PasswordsMailer < ApplicationMailer
  # The address is passed in because the database only keeps its digest.
  def reset(user, email)
    @user = user
    mail subject: I18n.t("mailers.passwords.reset.subject"), to: email
  end
end
