require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "mail is sent to the address as typed, only for a known user" do
    assert_emails 1 do
      post passwords_path, params: { email: "  One@Example.com " }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "One@Example.com" ], mail.to
    assert_redirected_to new_session_path
  end

  test "mail is delivered at once and never queued with the address" do
    assert_no_enqueued_emails do
      assert_no_enqueued_jobs do
        post passwords_path, params: { email: "one@example.com" }
      end
    end
  end

  test "known and unknown email give identical response" do
    post passwords_path, params: { email: "one@example.com" }
    known = [ response.status, response.location, flash[:notice] ]

    post passwords_path, params: { email: "missing-user@example.com" }
    unknown = [ response.status, response.location, flash[:notice] ]

    assert_equal known, unknown
    assert_equal I18n.t("passwords.create.sent", locale: :en), flash[:notice]
  end

  test "unknown email sends no mail" do
    assert_emails 0 do
      post passwords_path, params: { email: "missing-user@example.com" }
    end
    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "unconfirmed user gets no mail but the same answer" do
    @user.update_columns(confirmed_at: nil)

    assert_emails 0 do
      post passwords_path, params: { email: "one@example.com" }
    end
    assert_redirected_to new_session_path
    assert_equal I18n.t("passwords.create.sent", locale: :en), flash[:notice]
  end

  test "missing email gives the same answer" do
    assert_emails 0 do
      post passwords_path
    end
    assert_redirected_to new_session_path
  end

  test "reset link has locale prefix" do
    post "/ru/passwords", params: { email: "one@example.com" }

    mail = ActionMailer::Base.deliveries.last
    assert_match %r{http://example\.com/ru/passwords/[^/]+/edit}, mail.text_part.body.to_s
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "Password has been reset"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "Passwords did not match"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
