require "test_helper"

class PurgeStaleRecordsJobTest < ActiveSupport::TestCase
  setup { @game = games(:one) }

  test "deletes anonymous game sessions older than 24 hours" do
    stale = GameSession.create!(game: @game, created_at: 25.hours.ago)

    PurgeStaleRecordsJob.perform_now

    assert_not GameSession.exists?(stale.id)
  end

  test "keeps anonymous game sessions younger than 24 hours" do
    fresh = GameSession.create!(game: @game, created_at: 23.hours.ago)

    PurgeStaleRecordsJob.perform_now

    assert GameSession.exists?(fresh.id)
  end

  test "keeps old game sessions that belong to an account" do
    old = GameSession.create!(game: @game, user: users(:one), created_at: 30.days.ago)

    PurgeStaleRecordsJob.perform_now

    assert GameSession.exists?(old.id)
  end

  test "deletes unconfirmed users older than 24 hours" do
    stale = create_user("stale_user", confirmed_at: nil, created_at: 25.hours.ago)

    PurgeStaleRecordsJob.perform_now

    assert_not User.exists?(stale.id)
  end

  test "keeps unconfirmed users younger than 24 hours" do
    fresh = create_user("fresh_user", confirmed_at: nil, created_at: 23.hours.ago)

    PurgeStaleRecordsJob.perform_now

    assert User.exists?(fresh.id)
  end

  test "keeps confirmed users even when they are old" do
    old = create_user("old_user", confirmed_at: 40.days.ago, created_at: 40.days.ago)

    PurgeStaleRecordsJob.perform_now

    assert User.exists?(old.id)
  end

  test "deleting an unconfirmed user also removes their sessions and check-ins" do
    stale = create_user("stale_user", confirmed_at: nil, created_at: 25.hours.ago)
    stale.sessions.create!
    stale.check_ins.create!
    GameSession.create!(game: @game, user: stale)

    PurgeStaleRecordsJob.perform_now

    assert_equal 0, Session.where(user_id: stale.id).count
    assert_equal 0, CheckIn.where(user_id: stale.id).count
    assert_equal 0, GameSession.where(user_id: stale.id).count
  end

  test "deletes feedback messages older than 90 days" do
    stale = create_feedback(created_at: 91.days.ago)

    PurgeStaleRecordsJob.perform_now

    assert_not FeedbackMessage.exists?(stale.id)
  end

  test "keeps feedback messages younger than 90 days" do
    fresh = create_feedback(created_at: 89.days.ago)

    PurgeStaleRecordsJob.perform_now

    assert FeedbackMessage.exists?(fresh.id)
  end

  test "runs hourly in production" do
    config = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    task = config.fetch("production").values.find { |t| t["class"] == "PurgeStaleRecordsJob" }

    assert_not_nil task
    assert_equal "every hour", task["schedule"]
  end

  private

  def create_user(nickname, confirmed_at:, created_at:)
    user = User.new(nickname:, password: "password", confirmed_at:, created_at:)
    user.email = "#{nickname}@example.com"
    user.save!
    user
  end

  def create_feedback(created_at:)
    FeedbackMessage.create!(body: "text", kind: "idea", locale: "en", created_at:)
  end
end
