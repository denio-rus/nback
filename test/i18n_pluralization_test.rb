require "test_helper"

class I18nPluralizationTest < ActiveSupport::TestCase
  def plural(count, locale) = I18n.t("insights.summary.count", count: count, locale: locale)

  test "russian uses one, few and many forms" do
    assert_equal "1 прохождение", plural(1, :ru)
    assert_equal "21 прохождение", plural(21, :ru)
    assert_equal "2 прохождения", plural(2, :ru)
    assert_equal "4 прохождения", plural(4, :ru)
    assert_equal "5 прохождений", plural(5, :ru)
    assert_equal "11 прохождений", plural(11, :ru)
    assert_equal "12 прохождений", plural(12, :ru)
    assert_equal "0 прохождений", plural(0, :ru)
    assert_equal "102 прохождения", plural(102, :ru)
  end

  test "english keeps one and other" do
    assert_equal "1 play-through", plural(1, :en)
    assert_equal "2 play-throughs", plural(2, :en)
    assert_equal "0 play-throughs", plural(0, :en)
  end
end
