require "test_helper"

# The admin pages have no landing page of their own: the header links to them,
# and only for an admin.
class AdminNavigationTest < ActionDispatch::IntegrationTest
  test "admin sees links to users and feedback in the header" do
    sign_in_as_admin users(:admin)

    get games_url

    assert_select "nav a[href=?]", admin_users_path
    assert_select "nav a[href=?]", admin_feedback_messages_path
    assert_select "nav a[href=?]", admin_articles_path
  end

  test "player does not see admin links" do
    sign_in(users(:one))

    get games_url

    assert_select "nav a[href=?]", admin_users_path, count: 0
    assert_select "nav a[href=?]", admin_feedback_messages_path, count: 0
    assert_select "nav a[href=?]", admin_articles_path, count: 0
  end

  test "anonymous does not see admin links" do
    get games_url

    assert_select "nav a[href=?]", admin_users_path, count: 0
    assert_select "nav a[href=?]", admin_feedback_messages_path, count: 0
    assert_select "nav a[href=?]", admin_articles_path, count: 0
  end

  I18n.available_locales.each do |locale|
    test "admin links keep the #{locale} prefix and have translations" do
      sign_in_as_admin users(:admin)

      get games_url(locale: locale)

      assert_no_match(/translation missing/i, response.body)
      assert_select "nav a[href=?]", admin_feedback_messages_path(locale: locale)
      assert_select "nav a[href=?]", admin_articles_path(locale: locale)
    end
  end
end
