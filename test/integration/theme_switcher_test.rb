require "test_helper"

class ThemeSwitcherTest < ActionDispatch::IntegrationTest
  test "head sets the theme before the stylesheet is applied" do
    get "/en/games"

    script_at = response.body.index("localStorage")
    stylesheet_at = response.body.index("<link rel=\"stylesheet\"")
    assert script_at, "inline theme script is missing"
    assert stylesheet_at
    assert_operator script_at, :<, stylesheet_at
  end

  test "inline script only accepts themes from the THEMES list" do
    get "/en/games"

    assert_includes response.body, ApplicationHelper::THEMES.to_json
    assert_includes response.body, "prefers-color-scheme"
  end

  test "the server does not set a theme" do
    get "/en/games"

    assert_select "html[data-theme]", count: 0
  end

  test "switcher has one button per theme with a localized name" do
    get "/ru/games"

    assert_select "[data-controller=theme] button", count: ApplicationHelper::THEMES.size
    assert_select "[data-controller=theme] button[data-theme-name-param=dark]", text: "Тёмная"
    assert_select "[data-controller=theme] button[data-theme-name-param=light]", text: "Светлая"

    get "/en/games"
    assert_select "[data-controller=theme] button[data-theme-name-param=dark]", text: "Dark"
  end

  test "switcher buttons are real buttons that do not submit forms" do
    get "/en/games"

    assert_select "[data-controller=theme] button[type=button]", count: ApplicationHelper::THEMES.size
  end
end
