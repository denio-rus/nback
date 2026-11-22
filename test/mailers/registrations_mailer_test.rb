require "test_helper"

class RegistrationsMailerTest < ActionMailer::TestCase
  setup { @user = users(:one) }

  test "mail goes to the address passed in" do
    mail = RegistrationsMailer.confirm(@user, "typed@example.com")

    assert_equal [ "typed@example.com" ], mail.to
  end

  test "link carries the token and the language prefix" do
    I18n.with_locale(:ru) do
      mail = RegistrationsMailer.confirm(@user, "typed@example.com")

      assert_match %r{http://example\.com/ru/email_confirmations/[^/\s"]+}, mail.html_part.body.to_s
      assert_match %r{http://example\.com/ru/email_confirmations/[^/\s"]+}, mail.text_part.body.to_s
      assert_equal "Подтвердите адрес почты", mail.subject
    end
  end

  test "token in the link finds the user" do
    mail = RegistrationsMailer.confirm(@user, "typed@example.com")
    token = mail.text_part.body.to_s[%r{/email_confirmations/([^\s]+)}, 1]

    assert_equal @user, User.find_by_token_for(:email_confirmation, token)
  end

  test "english subject" do
    I18n.with_locale(:en) do
      assert_equal "Confirm your email address", RegistrationsMailer.confirm(@user, "typed@example.com").subject
    end
  end
end
