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

  test "index shows nicknames but never email digests" do
    get admin_users_url

    assert_includes response.body, users(:one).nickname
    User.pluck(:email_digest).each do |digest|
      assert_not_includes response.body, digest
    end
  end

  test "show and edit pages do not contain the email digest" do
    get admin_user_url(users(:one))
    assert_not_includes response.body, users(:one).email_digest

    get edit_admin_user_url(users(:one))
    assert_not_includes response.body, users(:one).email_digest
    assert_select "input[name=?]", "user[email]", count: 0
  end

  test "admins cannot create users: an account needs a confirmed email" do
    assert_no_difference("User.count") do
      post "/en/admin/users", params: { user: { nickname: "newuser", password: "password" } }
    end
    assert_response :not_found
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
    patch admin_user_url(users(:two)), params: { user: { active: false } }

    assert_redirected_to admin_user_url(users(:two))
    assert_not users(:two).reload.active?
  end

  test "update ignores nickname and email parameters" do
    digest = users(:two).email_digest
    patch admin_user_url(users(:two)), params: { user: { nickname: "renamed", email: "other@example.com", active: true } }

    assert_equal "two", users(:two).reload.nickname
    assert_equal digest, users(:two).email_digest
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      delete admin_user_url(@user)
    end

    assert_redirected_to admin_users_url
  end
end
