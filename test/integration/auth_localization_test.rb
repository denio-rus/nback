require "test_helper"

class AuthLocalizationTest < ActionDispatch::IntegrationTest
  test "sign in page is localized" do
    get "/en/session/new"
    assert_select "h1", "Sign in"

    get "/ru/session/new"
    assert_select "h1", "Вход"
    assert_select "input[type=submit][value=?]", "Войти"
  end

  test "sign up page is localized and asks not to use a real name" do
    get "/en/registrations/new"
    assert_select "h1", "Sign up"
    assert_select "body", /real name/i

    get "/ru/registrations/new"
    assert_select "h1", "Регистрация"
    assert_select "body", /настоящее имя/i
    assert_select "input[type=submit][value=?]", "Зарегистрироваться"
  end

  test "forgot password and update password pages are localized" do
    get "/ru/passwords/new"
    assert_select "h1", "Забыли пароль?"

    get edit_password_path(users(:one).password_reset_token, locale: :ru)
    assert_select "h1", "Новый пароль"
  end

  test "profile page is localized" do
    sign_in_as(users(:one))

    get "/ru/users/#{users(:one).id}"
    assert_select "h1", "Профиль"
    assert_select "body", /Ник/
  end

  test "wrong credentials give a flash in the request language" do
    post "/ru/session", params: { email_address: "nobody@example.com", password: "x" }
    follow_redirect!

    assert_select "#alert", /Неверн/
  end

  test "password reset request flash is in Russian for /ru" do
    post "/ru/passwords", params: { email_address: "nobody@example.com" }
    assert_redirected_to "/ru/session/new"
    follow_redirect!

    assert_select "#notice", /Если такой адрес/
  end

  test "an invalid reset token flash is in Russian for /ru" do
    get "/ru/passwords/bad-token/edit"
    assert_redirected_to "/ru/passwords/new"
    follow_redirect!

    assert_select "#alert", /Ссылка/
  end

  test "admin access denied message is localized" do
    sign_in_as(users(:one))

    get "/ru/admin/users"

    assert_redirected_to "/ru/games"
    follow_redirect!
    assert_select "body", /Доступ запрещён/
  end

  test "password mail is in the language of the request" do
    user = users(:one)

    I18n.with_locale(:ru) do
      mail = PasswordsMailer.reset(user)

      assert_equal "Сброс пароля", mail.subject
      assert_match "Сбросить пароль", mail.text_part.body.to_s
      assert_match "/ru/passwords/", mail.html_part.body.to_s
    end
    I18n.with_locale(:en) do
      assert_equal "Reset your password", PasswordsMailer.reset(user).subject
    end
  end

  test "auth views contain no hardcoded Cyrillic text" do
    files = Dir[Rails.root.join("app/views/{sessions,registrations,passwords,passwords_mailer,users}/**/*.erb")]
    offenders = files.select { |file| File.read(file).gsub(/<%#.*?%>/m, "").match?(/\p{Cyrillic}/) }

    assert_empty offenders.map { |path| path.sub("#{Rails.root}/", "") }
  end
end
