require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @game = games(:one)
  end

  def play_twice(user)
    2.times { GameSession.create!(user: user, game: @game) }
  end

  test "anonymous gets redirected to sign in" do
    get user_path(@user)
    assert_redirected_to new_session_path

    delete user_path(@user), params: { password: "password" }
    assert_redirected_to new_session_path
    assert User.exists?(@user.id)
  end

  test "show" do
    sign_in_as(@user)
    get user_path(@user)

    assert_response :success
    assert_select "input[type=password][name=password]"
    assert_select "body", /game results/i
  end

  test "profile does not show the email digest" do
    sign_in_as(@user)
    get user_path(@user)

    assert_not_includes response.body, @user.email_digest
  end

  test "user can delete own account with password" do
    sign_in_as(@user)

    assert_difference "User.count", -1 do
      delete user_path(@user), params: { password: "password" }
    end

    assert_redirected_to games_path
    assert_not User.exists?(@user.id)
    assert_empty cookies[:session_id].to_s
    assert_equal 0, Session.where(user_id: @user.id).count
  end

  test "wrong password keeps account" do
    sign_in_as(@user)
    play_twice(@user)

    assert_no_difference [ "User.count", "GameSession.count" ] do
      delete user_path(@user), params: { password: "wrong" }
    end

    assert_redirected_to user_path(@user)
    assert_equal I18n.t("users.destroy.wrong_password", locale: :en), flash[:alert]
  end

  test "missing password keeps account" do
    sign_in_as(@user)

    assert_no_difference "User.count" do
      delete user_path(@user)
    end
    assert_redirected_to user_path(@user)
  end

  test "deleting removes game_sessions" do
    sign_in_as(@user)
    play_twice(@user)
    play_twice(users(:two))

    assert_difference "GameSession.count", -2 do
      delete user_path(@user), params: { password: "password" }
    end

    assert_equal 0, GameSession.where(user_id: @user.id).count
    assert_equal 2, GameSession.where(user_id: users(:two).id).count
  end

  test "cannot delete another user (404)" do
    sign_in_as(@user)

    assert_no_difference "User.count" do
      delete user_path(users(:two)), params: { password: "password" }
    end
    assert_response :not_found
  end

  test "cannot see or edit another user (404)" do
    sign_in_as(@user)

    get user_path(users(:two))
    assert_response :not_found

    get edit_user_path(users(:two))
    assert_response :not_found

    patch user_path(users(:two)), params: { user: { gender: "male" } }
    assert_response :not_found
    assert_nil users(:two).reload.gender
  end

  test "update changes only gender and age" do
    sign_in_as(@user)

    patch user_path(@user), params: { user: { gender: "female", age_decade: "40" } }

    assert_redirected_to user_path(@user)
    assert_equal [ "female", 40 ], [ @user.reload.gender, @user.age_decade ]
  end

  test "update ignores nickname param" do
    sign_in_as(@user)
    digest = @user.email_digest

    patch user_path(@user), params: { user: { nickname: "renamed", email: "other@example.com", gender: "male" } }

    assert_equal "one", @user.reload.nickname
    assert_equal digest, @user.email_digest
    assert_equal "male", @user.gender
  end

  test "update with an invalid value renders the form again" do
    sign_in_as(@user)

    patch user_path(@user), params: { user: { gender: "robot" } }

    assert_response :unprocessable_content
    assert_nil @user.reload.gender
  end

  test "edit shows only the optional fields" do
    sign_in_as(@user)
    get edit_user_path(@user)

    assert_response :success
    assert_select "select[name=?]", "user[gender]"
    assert_select "select[name=?]", "user[age_decade]"
    assert_select "input[name=?]", "user[nickname]", count: 0
    assert_select "input[name=?]", "user[email]", count: 0
  end
end
