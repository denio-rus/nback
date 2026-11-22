require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "signs in by nickname" do
    post session_path, params: { nickname: @user.nickname, password: "password" }

    assert_redirected_to games_path
    assert cookies[:session_id]
  end

  test "nickname lookup ignores case and surrounding spaces" do
    post session_path, params: { nickname: "  #{@user.nickname.upcase} ", password: "password" }

    assert_redirected_to games_path
    assert cookies[:session_id]
  end

  test "email address is not a way to sign in" do
    post session_path, params: { nickname: "one@example.com", password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "wrong password does not sign in" do
    post session_path, params: { nickname: @user.nickname, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "wrong nickname and wrong password give identical redirect and message" do
    post session_path, params: { nickname: @user.nickname, password: "wrong" }
    wrong_password = [ response.location, flash[:alert] ]

    post session_path, params: { nickname: "nobody-here", password: "password" }
    wrong_nickname = [ response.location, flash[:alert] ]

    assert_equal wrong_password, wrong_nickname
    assert_equal I18n.t("sessions.create.invalid", locale: :en), flash[:alert]
  end

  test "missing parameters give the same answer as wrong ones" do
    post session_path

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.create.invalid", locale: :en), flash[:alert]
  end

  test "unconfirmed user cannot sign in" do
    @user.update_columns(confirmed_at: nil)

    post session_path, params: { nickname: @user.nickname, password: "password" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.create.unconfirmed", locale: :en), flash[:alert]
    assert_nil cookies[:session_id]
    assert_equal 0, @user.sessions.count
  end

  test "unconfirmed user with a wrong password is told nothing about confirmation" do
    @user.update_columns(confirmed_at: nil)

    post session_path, params: { nickname: @user.nickname, password: "wrong" }

    assert_equal I18n.t("sessions.create.invalid", locale: :en), flash[:alert]
  end

  test "rate limit blocks the 11th attempt in 3 minutes" do
    10.times do
      post session_path, params: { nickname: @user.nickname, password: "wrong" }
      assert_equal I18n.t("sessions.create.invalid", locale: :en), flash[:alert]
    end

    post session_path, params: { nickname: @user.nickname, password: "password" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.rate_limited", locale: :en), flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
