class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_path(@user), notice: "User was successfully updated.", status: :see_other }
      else
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @user.destroy!
    # session_delete :user_id

    respond_to do |format|
      format.html { redirect_to root_path, notice: "User was successfully destroyed.", status: :see_other }
    end
  end

  private
    def set_user
      @user = User.find(params.expect(:id))
    end

    def user_params
      params.expect(user: [ :nickname, :email_address ])
    end
end
