require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  EVALUATIVE = /worse|better|tired|хуже|лучше|усталость|норма/i
  # One section per required statement of Task 8.3.
  SECTIONS = %w[project not_medical same_device data email deletion].freeze

  I18n.available_locales.each do |locale|
    test "about page renders every statement in #{locale}" do
      get about_url(locale: locale)

      assert_response :success
      assert_select "html[lang=?]", locale.to_s
      assert_no_match(/translation missing/i, response.body)

      main = css_select("main").text.squish
      assert_includes main, I18n.t("pages.about.title", locale: locale)
      SECTIONS.each do |section|
        assert_includes main, I18n.t("pages.about.sections.#{section}.title", locale: locale), section
        assert_includes main, I18n.t("pages.about.sections.#{section}.body", locale: locale).squish, section
      end
    end

    test "about page has no evaluative words in #{locale}" do
      get about_url(locale: locale)

      assert_no_match(EVALUATIVE, css_select("main").text)
    end

    test "about page is linked from the header in #{locale}" do
      get games_url(locale: locale)

      assert_select "nav a[href=?]", about_path(locale: locale)
    end
  end

  test "about page names the project" do
    get about_url

    assert_includes css_select("main").text, "MindAtPlay"
  end

  test "about page is open to anonymous visitors" do
    get about_url

    assert_response :success
  end

  test "about page shows the header of a signed in user" do
    sign_in(users(:one))

    get about_url

    assert_select "nav", text: /#{users(:one).nickname}/
  end

  test "about page for an unknown language is 404" do
    get "/xx/about"

    assert_response :not_found
  end

  test "about page contains no form and no user input" do
    get about_url

    assert_select "main form", 0
  end
end
