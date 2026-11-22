require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nickname: "fresh", email: "fresh@example.com", password: "secret-pass")
    @token = @user.generate_token_for(:email_confirmation)
  end

  test "confirmation link confirms and signs in" do
    get email_confirmation_path(@token)

    assert_redirected_to games_path
    assert @user.reload.confirmed?
    assert cookies[:session_id]
    assert_equal 1, @user.sessions.count
  end

  test "following the link twice is harmless" do
    get email_confirmation_path(@token)
    first_time = @user.reload.confirmed_at

    travel 1.hour do
      get email_confirmation_path(@token)
    end

    assert_redirected_to games_path
    assert_equal first_time, @user.reload.confirmed_at
  end

  test "expired token (25 hours) does not confirm" do
    travel 25.hours do
      get email_confirmation_path(@token)
    end

    assert_redirected_to new_registration_path
    assert_not @user.reload.confirmed?
    assert_nil cookies[:session_id]
  end

  test "tampered token does not confirm" do
    get email_confirmation_path(@token.reverse)

    assert_redirected_to new_registration_path
    assert_not @user.reload.confirmed?
    assert_nil cookies[:session_id]
  end

  test "garbage token does not confirm" do
    get email_confirmation_path("garbage")

    assert_redirected_to new_registration_path
    follow_redirect!
    assert_select "#alert"
  end

  test "a link from before a password change does not confirm" do
    @user.update!(password: "changed-pass", password_confirmation: "changed-pass")

    get email_confirmation_path(@token)

    assert_not @user.reload.confirmed?
  end

  test "messages are in the language of the request" do
    get "/ru/email_confirmations/garbage"
    follow_redirect!
    assert_select "#alert", /недействительна/
  end
end
