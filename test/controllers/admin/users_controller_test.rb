require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    sign_in_as_admin @user
  end

  test "should get index" do
    get admin_users_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_user_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count") do
      post admin_users_url, params: { user: { active: true, email_address: "newuser@example.com", nickname: "newuser", password: "password" } }
    end

    assert_redirected_to admin_user_url(User.last)
  end

  test "should show user" do
    get admin_user_url(@user)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_user_url(@user)
    assert_response :success
  end

  test "should update user" do
    patch admin_user_url(@user), params: { user: { active: @user.active, email_address: @user.email_address, nickname: @user.nickname } }
    assert_redirected_to admin_user_url(@user)
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      delete admin_user_url(@user)
    end

    assert_redirected_to admin_users_url
  end
end
