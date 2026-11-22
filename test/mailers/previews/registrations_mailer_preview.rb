# Preview this email at http://localhost:3000/rails/mailers/registrations_mailer/confirm
class RegistrationsMailerPreview < ActionMailer::Preview
  def confirm
    RegistrationsMailer.confirm(User.take, "preview@example.com")
  end
end
