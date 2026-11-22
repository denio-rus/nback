# Entry point for "/": picks a language once from Accept-Language and redirects.
class RootController < ApplicationController
  allow_unauthenticated_access

  def show
    response.headers["Vary"] = "Accept-Language"
    redirect_to games_path(locale: preferred_locale)
  end

  private

  # The first supported language tag wins. The header is untrusted: only a
  # value found in available_locales is ever used.
  def preferred_locale
    tags = request.headers["Accept-Language"].to_s.first(200).split(",")
    candidates = tags.map { |tag| tag.split(";").first.to_s.strip.split("-").first.to_s.downcase }
    candidates.find { |code| available_codes.include?(code) } || I18n.default_locale.to_s
  end

  def available_codes = I18n.available_locales.map(&:to_s)
end
