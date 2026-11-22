class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  # Path helpers add the current language prefix automatically.
  def default_url_options = { locale: I18n.locale }

  private

  # The route constraint already limits :locale to available_locales; the
  # check here keeps the controller safe if a route ever forgets it.
  def switch_locale(&action)
    requested = params[:locale].to_s
    locale = I18n.available_locales.map(&:to_s).include?(requested) ? requested : I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
