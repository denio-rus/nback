require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params(overrides = {})
    { user: { nickname: "newbie", email: "newbie@example.com", email_confirmation: "newbie@example.com",
              password: "secret-pass", password_confirmation: "secret-pass" }.merge(overrides) }
  end

  test "new" do
    get new_registration_path

    assert_response :success
    assert_select "input[name=?]", "user[nickname]"
    assert_select "input[name=?]", "user[email]"
    assert_select "input[name=?]", "user[email_confirmation]"
    assert_select "input[name=?][type=password]", "user[password]"
    assert_select "input[name=?][type=password]", "user[password_confirmation]"
    assert_select "select[name=?] option[value='']", "user[gender]"
    assert_select "select[name=?] option[value='']", "user[age_decade]"
    assert_select "body", /real name/i
  end

  test "creates unconfirmed user and sends mail with token link" do
    assert_difference "User.count", 1 do
      assert_emails 1 do
        post registrations_path, params: valid_params
      end
    end

    user = User.find_by!(nickname: "newbie")
    assert_not user.confirmed?
    assert_nil cookies[:session_id]
    assert_equal 0, user.sessions.count
    assert_redirected_to check_mail_registrations_path

    token = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/email_confirmations/([^\s]+)}, 1]
    assert_equal user, User.find_by_token_for(:email_confirmation, token)
  end

  test "check mail page renders" do
    get check_mail_registrations_path
    assert_response :success
  end

  test "link in mail has locale prefix" do
    post "/ru/registrations", params: valid_params

    mail = ActionMailer::Base.deliveries.last
    assert_match %r{http://example\.com/ru/email_confirmations/[^/\s"]+}, mail.html_part.body.to_s
    assert_match %r{http://example\.com/ru/email_confirmations/[^/\s"]+}, mail.text_part.body.to_s
    assert_equal I18n.t("mailers.registrations.confirm.subject", locale: :ru), mail.subject
  end

  test "mail goes to typed address and address is not stored in any users column" do
    post registrations_path, params: valid_params(email: "Typed.Address@Example.com", email_confirmation: "typed.address@example.com")

    assert_equal [ "Typed.Address@Example.com" ], ActionMailer::Base.deliveries.last.to
    row = User.connection.select_one("SELECT * FROM users WHERE lower(nickname) = 'newbie'")
    assert_not_includes row.values.map(&:to_s).join(" ").downcase, "typed.address"
    assert_equal User.email_digest_for("typed.address@example.com"), row["email_digest"]
  end

  test "deliver_now used: no job is queued with the address" do
    assert_no_enqueued_jobs do
      post registrations_path, params: valid_params
    end
    assert_equal 0, SolidQueue::Job.count if defined?(SolidQueue::Job) && SolidQueue::Job.table_exists?
  end

  test "mismatching email confirmation does not create user" do
    assert_no_difference "User.count" do
      assert_emails 0 do
        post registrations_path, params: valid_params(email_confirmation: "typo@example.com")
      end
    end

    assert_response :unprocessable_entity
  end

  test "missing email confirmation does not create user" do
    assert_no_difference "User.count" do
      post registrations_path, params: valid_params(email_confirmation: "")
    end
    assert_response :unprocessable_entity
  end

  test "mismatching password confirmation does not create user" do
    assert_no_difference "User.count" do
      post registrations_path, params: valid_params(password_confirmation: "different")
    end
    assert_response :unprocessable_entity
  end

  test "nickname 2 chars is rejected" do
    assert_no_difference "User.count" do
      post registrations_path, params: valid_params(nickname: "ab")
    end
    assert_response :unprocessable_entity
  end

  test "bad email format is rejected" do
    assert_no_difference "User.count" do
      post registrations_path, params: valid_params(email: "not-an-email", email_confirmation: "not-an-email")
    end
    assert_response :unprocessable_entity
  end

  test "unconfirmed duplicate is replaced" do
    old = User.create!(nickname: "stale", email: "newbie@example.com", password: "old-password")

    assert_no_difference "User.count" do
      post registrations_path, params: valid_params
    end

    assert_not User.exists?(old.id)
    assert User.exists?(nickname: "newbie")
    assert_redirected_to check_mail_registrations_path
  end

  test "a failed sign up keeps the unconfirmed account it would have replaced" do
    old = User.create!(nickname: "stale", email: "newbie@example.com", password: "old-password")

    post registrations_path, params: valid_params(nickname: "ab")

    assert_response :unprocessable_entity
    assert User.exists?(old.id)
  end

  test "confirmed duplicate shows error" do
    assert_no_difference "User.count" do
      assert_emails 0 do
        post registrations_path, params: valid_params(email: "one@example.com", email_confirmation: "one@example.com")
      end
    end

    assert_response :unprocessable_entity
    assert User.exists?(users(:one).id)
  end

  test "taken nickname is rejected ignoring case" do
    assert_no_difference "User.count" do
      post registrations_path, params: valid_params(nickname: "ONE")
    end
    assert_response :unprocessable_entity
  end

  test "gender and age are saved when given and optional otherwise" do
    post registrations_path, params: valid_params(gender: "female", age_decade: "30")
    assert_equal [ "female", 30 ], User.find_by!(nickname: "newbie").then { |u| [ u.gender, u.age_decade ] }

    post registrations_path, params: valid_params(nickname: "second", email: "second@example.com", email_confirmation: "second@example.com", gender: "", age_decade: "")
    second = User.find_by!(nickname: "second")
    assert_nil second.gender
    assert_nil second.age_decade
  end

  test "role, confirmation and activity cannot be set by the form" do
    post registrations_path, params: valid_params(confirmed_at: Time.current.to_s, active: "false", email_digest: "x" * 64)

    user = User.find_by!(nickname: "newbie")
    assert_not user.confirmed?
    assert user.active?
    assert_equal User.email_digest_for("newbie@example.com"), user.email_digest
  end

  test "password and email are filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(user: { email: "a@b.co", email_confirmation: "a@b.co", password: "p", password_confirmation: "p" })

    assert_equal({ email: "[FILTERED]", email_confirmation: "[FILTERED]", password: "[FILTERED]", password_confirmation: "[FILTERED]" }, filtered[:user])
  end
end
