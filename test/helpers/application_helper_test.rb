require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "THEMES lists light and dark" do
    assert_equal %w[light dark], ApplicationHelper::THEMES
    assert ApplicationHelper::THEMES.frozen?
  end

  test "every theme has a name in every language" do
    I18n.available_locales.each do |locale|
      ApplicationHelper::THEMES.each do |theme|
        assert I18n.t("themes.#{theme}", locale: locale, default: "").present?, "#{locale}: themes.#{theme}"
      end
      assert I18n.t("themes.label", locale: locale, default: "").present?, "#{locale}: themes.label"
    end
  end
end
