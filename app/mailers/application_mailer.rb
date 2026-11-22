class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Links in mails must carry the language prefix, otherwise they return 404.
  # The host comes from the environment config and is merged at send time.
  def default_url_options
    Rails.application.config.action_mailer.default_url_options.to_h.merge(locale: I18n.locale)
  end
end
