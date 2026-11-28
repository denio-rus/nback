require "test_helper"

class Admin::FeedbackMessagesControllerTest < ActionDispatch::IntegrationTest
  test "admin sees list" do
    sign_in_as_admin users(:admin)

    get admin_feedback_messages_url

    assert_response :success
    assert_includes response.body, feedback_messages(:one).body
  end

  test "list shows newest first and at most 200 messages" do
    sign_in_as_admin users(:admin)
    FeedbackMessage.delete_all
    201.times { |i| FeedbackMessage.create!(kind: "idea", locale: "en", body: "note-#{i}", created_at: i.minutes.ago) }

    get admin_feedback_messages_url

    assert_select "[data-feedback-message]", 200
    assert_select "[data-feedback-message]:first-of-type", text: /note-0/
    assert_no_match(/note-200/, response.body)
  end

  test "list shows an empty state" do
    sign_in_as_admin users(:admin)
    FeedbackMessage.delete_all

    get admin_feedback_messages_url

    assert_response :success
    assert_select "[data-feedback-message]", 0
    assert_select "[data-empty]"
  end

  test "body with script is escaped in admin list" do
    sign_in_as_admin users(:admin)
    FeedbackMessage.create!(kind: "bug", locale: "en", body: "<script>alert(1)</script>")

    get admin_feedback_messages_url

    assert_no_match(%r{<script>alert\(1\)</script>}, response.body)
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "player gets redirected" do
    sign_in(users(:one))

    get admin_feedback_messages_url

    assert_redirected_to games_url
  end

  test "player cannot delete" do
    sign_in(users(:one))

    assert_no_difference("FeedbackMessage.count") do
      delete admin_feedback_message_url(feedback_messages(:one))
    end
    assert_redirected_to games_url
  end

  test "anonymous gets redirected" do
    get admin_feedback_messages_url

    assert_redirected_to new_session_url
  end

  test "anonymous cannot delete" do
    assert_no_difference("FeedbackMessage.count") do
      delete admin_feedback_message_url(feedback_messages(:one))
    end
    assert_redirected_to new_session_url
  end

  test "admin deletes message" do
    sign_in_as_admin users(:admin)

    assert_difference("FeedbackMessage.count", -1) do
      delete admin_feedback_message_url(feedback_messages(:one))
    end
    assert_redirected_to admin_feedback_messages_url
  end

  test "admin page renders in every language without missing translations" do
    sign_in_as_admin users(:admin)

    I18n.available_locales.each do |locale|
      get admin_feedback_messages_url(locale: locale)

      assert_response :success
      assert_no_match(/translation missing/i, response.body)
    end
  end

  test "admin list does not show who wrote a message" do
    sign_in_as_admin users(:admin)

    get admin_feedback_messages_url

    assert_no_match(/user_id|ip_address/i, response.body)
  end
end
