require "test_helper"

class FeedbackMessagesControllerTest < ActionDispatch::IntegrationTest
  def send_feedback(attributes = {}, locale: :en, website: nil)
    params = { feedback_message: { kind: "idea", body: "Nice" }.merge(attributes) }
    params[:website] = website if website
    post feedback_messages_path(locale: locale), params: params
  end

  test "the form is open to anonymous visitors" do
    get new_feedback_message_path

    assert_response :success
    assert_select "form textarea[name=?]", "feedback_message[body]"
  end

  test "the form tells not to write personal data" do
    get new_feedback_message_path

    assert_select "main", text: /do not write personal data/
  end

  test "creates message with locale from URL" do
    assert_difference "FeedbackMessage.count", 1 do
      send_feedback({ kind: "bug", body: "It broke" }, locale: :ru)
    end

    message = FeedbackMessage.order(:id).last
    assert_equal [ "bug", "It broke", "ru" ], [ message.kind, message.body, message.locale ]
    assert_redirected_to new_feedback_message_path(locale: :ru)
  end

  test "locale is taken from the URL, not from parameters" do
    send_feedback({ locale: "ru" }, locale: :en)

    assert_equal "en", FeedbackMessage.order(:id).last.locale
  end

  test "rejects body over 2000" do
    assert_no_difference "FeedbackMessage.count" do
      send_feedback({ body: "a" * 2001 })
    end
    assert_response :unprocessable_content
  end

  test "rejects empty body" do
    assert_no_difference "FeedbackMessage.count" do
      send_feedback({ body: "" })
    end
    assert_response :unprocessable_content
  end

  test "rejects unknown kind" do
    assert_no_difference "FeedbackMessage.count" do
      send_feedback({ kind: "spam" })
    end
    assert_response :unprocessable_content
  end

  test "a missing feedback_message parameter is a bad request" do
    post feedback_messages_path, params: { other: 1 }

    assert_response :bad_request
  end

  test "honeypot silently drops message" do
    assert_no_difference "FeedbackMessage.count" do
      send_feedback({}, website: "http://spam.example")
    end
    assert_redirected_to new_feedback_message_path
    follow_redirect!
    assert_select "body", text: /Thank you/
  end

  test "the honeypot field is hidden and not focusable" do
    get new_feedback_message_path

    assert_select ".hidden input[name=website][tabindex='-1'][autocomplete=off]"
  end

  test "6th request in an hour is throttled" do
    5.times { send_feedback }
    assert_equal 5, FeedbackMessage.where(body: "Nice").count

    assert_no_difference "FeedbackMessage.count" do
      send_feedback
    end
    assert_redirected_to new_feedback_message_path
    assert_equal I18n.t("feedback.rate_limited", locale: :en), flash[:alert]
  end

  test "a script in the body is stored as text" do
    send_feedback({ body: "<script>alert(1)</script>" })

    assert_equal "<script>alert(1)</script>", FeedbackMessage.order(:id).last.body
  end
end
