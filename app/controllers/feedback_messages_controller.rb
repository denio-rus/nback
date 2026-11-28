# Anonymous feedback. The throttle counts by IP in the cache, the IP itself is
# never stored with the message.
class FeedbackMessagesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_feedback_message_path, alert: I18n.t("feedback.rate_limited") }

  def new
    @feedback_message = FeedbackMessage.new(kind: "idea")
  end

  def create
    # A person never sees the hidden field. A bot fills it in: look successful, store nothing.
    return redirect_to(new_feedback_message_path, notice: t("feedback.thanks"), status: :see_other) if params[:website].present?

    @feedback_message = FeedbackMessage.new(feedback_params.merge(locale: I18n.locale.to_s))
    if @feedback_message.save
      redirect_to new_feedback_message_path, notice: t("feedback.thanks"), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def feedback_params
    params.expect(feedback_message: [ :body, :kind ])
  end
end
