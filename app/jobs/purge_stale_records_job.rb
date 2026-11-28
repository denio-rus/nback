# Hourly cleanup of data that must not pile up (see config/recurring.yml).
class PurgeStaleRecordsJob < ApplicationJob
  queue_as :default

  ANONYMOUS_SESSION_TTL = 24.hours
  UNCONFIRMED_USER_TTL = 24.hours
  FEEDBACK_TTL = 90.days

  def perform
    purge_anonymous_game_sessions
    purge_unconfirmed_users
    purge_old_feedback
  end

  private

  # Runs without an account have no owner and no history, nothing depends on them.
  def purge_anonymous_game_sessions
    GameSession.where(user_id: nil).where(created_at: ...ANONYMOUS_SESSION_TTL.ago).delete_all
  end

  # destroy (not delete) so that sessions, check-ins and game sessions of the user go too.
  def purge_unconfirmed_users
    User.where(confirmed_at: nil).where(created_at: ...UNCONFIRMED_USER_TTL.ago).find_each(&:destroy)
  end

  def purge_old_feedback
    FeedbackMessage.where(created_at: ...FEEDBACK_TTL.ago).delete_all
  end
end
