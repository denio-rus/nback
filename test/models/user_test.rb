require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.new({ nickname: "newbie", email: "newbie@example.com", password: "password", password_confirmation: "password" }.merge(attrs))
  end

  test "digest ignores case and spaces" do
    assert_equal User.email_digest_for("a@b.co"), User.email_digest_for("  A@B.CO ")
  end

  test "digest is a hex HMAC-SHA256" do
    assert_match(/\A\h{64}\z/, User.email_digest_for("a@b.co"))
  end

  test "digest differs with another pepper" do
    original = User.email_digest_for("a@b.co")

    with_pepper("another-pepper") do
      assert_not_equal original, User.email_digest_for("a@b.co")
    end
  end

  test "find_by_email finds a user by any spelling of the address" do
    assert_equal users(:one), User.find_by_email(" One@Example.com ")
    assert_nil User.find_by_email("nobody@example.com")
    assert_nil User.find_by_email(nil)
  end

  test "email is not stored as plain text" do
    user = build_user(email: "secret.address@example.com")
    user.save!

    stored = User.connection.select_one("SELECT * FROM users WHERE id = #{user.id}")
    assert_not_includes stored.values.map(&:to_s).join(" "), "secret.address"
    assert_not_includes user.attributes.values.map(&:to_s).join(" "), "secret.address"
    assert_not_includes User.column_names, "email_address"
  end

  test "setting email sets the digest" do
    user = User.new(email: "x@example.com")

    assert_equal User.email_digest_for("x@example.com"), user.email_digest
  end

  test "valid user" do
    assert build_user.valid?, build_user.tap(&:valid?).errors.full_messages.to_sentence
  end

  test "nickname accepts 3 to 20 letters, digits, underscore, dash and dot" do
    %w[abc a_b-c.d A1b2C3 aaaaaaaaaaaaaaaaaaaa].each do |nickname|
      assert build_user(nickname: nickname).valid?, nickname
    end
  end

  test "nickname 3-20 chars only allowed symbols" do
    [ "ab", "a" * 21, "has space", "semi;colon", "кириллица", "a@b.c", "", nil ].each do |nickname|
      assert_not build_user(nickname: nickname).valid?, nickname.inspect
    end
  end

  test "nickname with a trailing newline is rejected" do
    assert_not build_user(nickname: "abc\n").valid?
  end

  test "nickname unique ignoring case" do
    assert_not build_user(nickname: "ONE").valid?
    assert_not build_user(nickname: "One").valid?
  end

  test "nickname cannot change after create" do
    user = users(:one)

    assert_raises(ActiveRecord::ReadonlyAttributeError) { user.update(nickname: "different") }
  end

  test "bad email format is invalid" do
    [ "no-at-sign", "a@", "@b.co", "a b@c.co" ].each do |email|
      user = build_user(email: email)
      assert_not user.valid?, email
      assert user.errors[:email].any?, email
    end
  end

  test "email is required" do
    user = build_user(email: nil)
    assert_not user.valid?
    assert user.errors[:email_digest].any?
  end

  test "email digest must be unique" do
    assert_not build_user(email: "one@example.com").valid?
  end

  test "gender is one of the list or empty" do
    %w[female male other].each { |gender| assert build_user(gender: gender).valid?, gender }
    assert build_user(gender: nil).valid?
    assert_not build_user(gender: "robot").valid?
  end

  test "age decade is 10 to 90 in steps of ten or empty" do
    (10..90).step(10) { |age| assert build_user(age_decade: age).valid?, age }
    assert build_user(age_decade: nil).valid?
    [ 0, 15, 100, -10 ].each { |age| assert_not build_user(age_decade: age).valid?, age }
  end

  test "confirmed? follows confirmed_at" do
    assert users(:one).confirmed?
    assert_not build_user.confirmed?
    assert_not build_user(confirmed_at: nil).confirmed?
  end

  test "token for confirmation works and expires after 24 hours" do
    user = users(:one)
    token = user.generate_token_for(:email_confirmation)

    assert_equal user, User.find_by_token_for(:email_confirmation, token)

    travel 23.hours do
      assert_equal user, User.find_by_token_for(:email_confirmation, token)
    end
    travel 25.hours do
      assert_nil User.find_by_token_for(:email_confirmation, token)
    end
  end

  test "token for confirmation stops working after the password changes" do
    user = users(:one)
    token = user.generate_token_for(:email_confirmation)

    user.update!(password: "another-password", password_confirmation: "another-password")

    assert_nil User.find_by_token_for(:email_confirmation, token)
  end

  test "destroy removes game sessions" do
    user = users(:one)
    game = games(:one)
    2.times { GameSession.create!(user: user, game: game) }

    assert_difference -> { GameSession.where(user_id: user.id).count }, -2 do
      user.destroy!
    end
  end

  private

  def with_pepper(value)
    original = Rails.configuration.x.email_pepper
    Rails.configuration.x.email_pepper = value
    yield
  ensure
    Rails.configuration.x.email_pepper = original
  end
end
