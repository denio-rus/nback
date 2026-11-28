# Admin view of anonymous feedback: newest first, delete only.
class Admin::FeedbackMessagesController < Admin::ApplicationController
  LIST_LIMIT = 200

  def index
    @limit = LIST_LIMIT
    @feedback_messages = FeedbackMessage.order(created_at: :desc, id: :desc).limit(@limit)
  end

  def destroy
    FeedbackMessage.find(params.expect(:id)).destroy!
    redirect_to admin_feedback_messages_path, notice: t("admin.feedback_messages.destroyed"), status: :see_other
  end
end
