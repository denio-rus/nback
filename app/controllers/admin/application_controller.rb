class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    unless Current.user&.has_role?(:admin)
      redirect_to games_path, alert: t("admin.forbidden")
    end
  end
end
