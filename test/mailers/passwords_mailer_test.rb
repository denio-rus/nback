require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup { @user = users(:one) }

  test "reset link carries the language of the request" do
    I18n.with_locale(:ru) do
      mail = PasswordsMailer.reset(@user)

      assert_match %r{http://example\.com/ru/passwords/[^/]+/edit}, mail.html_part.body.to_s
      assert_match %r{http://example\.com/ru/passwords/[^/]+/edit}, mail.text_part.body.to_s
    end
  end

  test "reset link uses English for the English locale" do
    I18n.with_locale(:en) do
      mail = PasswordsMailer.reset(@user)

      assert_match %r{/en/passwords/[^/]+/edit}, mail.html_part.body.to_s
    end
  end

  test "mailer keeps the host from the environment" do
    mail = PasswordsMailer.reset(@user)

    assert_match "example.com", mail.html_part.body.to_s
  end
end
