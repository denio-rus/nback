require "test_helper"

class FeedbackMessageTest < ActiveSupport::TestCase
  def build(attributes = {})
    FeedbackMessage.new({ kind: "idea", body: "Hello", locale: "en" }.merge(attributes))
  end

  test "a valid message" do
    assert build.valid?
  end

  test "body must be present" do
    assert_not build(body: "").valid?
    assert_not build(body: nil).valid?
  end

  test "body is limited to 2000 characters" do
    assert build(body: "a" * 2000).valid?
    assert_not build(body: "a" * 2001).valid?
  end

  test "kind must be bug, idea or other" do
    %w[bug idea other].each { |kind| assert build(kind: kind).valid?, kind }
    assert_not build(kind: "spam").valid?
    assert_not build(kind: nil).valid?
  end

  test "locale must be an available language" do
    I18n.available_locales.each { |locale| assert build(locale: locale.to_s).valid?, locale }
    assert_not build(locale: "xx").valid?
  end

  test "no user_id or ip stored" do
    columns = FeedbackMessage.column_names

    assert_equal %w[body created_at id kind locale updated_at], columns.sort
    assert_empty columns.grep(/user|ip|agent|session/)
  end
end
