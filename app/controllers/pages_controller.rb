# Static pages. The texts live in config/locales/pages.*.yml.
class PagesController < ApplicationController
  allow_unauthenticated_access
  # The header shows the signed in user even on a public page.
  before_action :resume_session

  def about
  end
end
