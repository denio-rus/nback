class UsersController < ApplicationController
  before_action :set_user
  rate_limit to: 10, within: 3.minutes, only: :destroy, with: -> { redirect_to user_path(Current.user), alert: I18n.t("sessions.rate_limited") }

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: t(".success"), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Deleting needs the password again: a stolen session must not be enough.
  def destroy
    if @user.authenticate(params[:password].to_s)
      terminate_session
      @user.destroy!
      redirect_to games_path, notice: t(".success"), status: :see_other
    else
      redirect_to user_path(@user), alert: t(".wrong_password"), status: :see_other
    end
  end

  private
    # People only ever see their own profile; another id is a 404.
    def set_user
      @user = Current.user
      raise ActiveRecord::RecordNotFound unless @user && params[:id].to_s == @user.id.to_s
    end

    # Nickname and email cannot be changed here.
    def user_params
      params.expect(user: [ :gender, :age_decade ])
    end
end
