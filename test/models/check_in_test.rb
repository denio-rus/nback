require "test_helper"

class CheckInTest < ActiveSupport::TestCase
  def build(**attrs)
    CheckIn.new({ user: users(:one) }.merge(attrs))
  end

  test "constants list the allowed flags and day phases" do
    assert_equal %w[alcohol meds illness hungry rested], CheckIn::FLAGS
    assert_equal %w[morning day evening night], CheckIn::DAY_PHASES
    assert CheckIn::FLAGS.frozen?
    assert CheckIn::DAY_PHASES.frozen?
  end

  test "valid with only day_phase" do
    assert build(day_phase: "morning").valid?
  end

  test "valid with nothing but a user" do
    check_in = build
    assert check_in.valid?, check_in.errors.full_messages.to_sentence
    assert_equal({}, check_in.flags)
  end

  test "invalid without a user" do
    assert_not CheckIn.new(day_phase: "day").valid?
  end

  test "invalid with unknown day_phase" do
    check_in = build(day_phase: "lunch")

    assert_not check_in.valid?
    assert check_in.errors[:day_phase].any?
  end

  test "every known day phase is valid" do
    CheckIn::DAY_PHASES.each { |phase| assert build(day_phase: phase).valid?, phase }
  end

  test "invalid with unknown flag key" do
    check_in = build(flags: { "cannabis" => true })

    assert_not check_in.valid?
    assert check_in.errors[:flags].any?
  end

  test "invalid with non-boolean flag value" do
    [ "yes", 5, nil, [ 1 ], { "a" => 1 } ].each do |value|
      check_in = build(flags: { "alcohol" => value })
      assert_not check_in.valid?, "#{value.inspect} must be rejected"
    end
  end

  test "form values 1 and 0 become booleans before validation" do
    check_in = build(flags: { "alcohol" => "1", "meds" => "0", "rested" => "true", "hungry" => "false" })

    assert check_in.valid?, check_in.errors.full_messages.to_sentence
    assert_equal({ "alcohol" => true, "meds" => false, "rested" => true, "hungry" => false }, check_in.flags)
  end

  test "flags must be a hash" do
    check_in = build
    check_in.flags = [ "alcohol" ]

    assert_not check_in.valid?
    assert check_in.errors[:flags].any?
  end

  test "sleep_hours is optional and between 0 and 24" do
    assert build(sleep_hours: nil).valid?
    assert build(sleep_hours: 0).valid?
    assert build(sleep_hours: 7.5).valid?
    assert build(sleep_hours: 24).valid?
    assert_not build(sleep_hours: 24.5).valid?
    assert_not build(sleep_hours: 99).valid?
    assert_not build(sleep_hours: -1).valid?
  end

  test "sleep_hours keeps one decimal" do
    check_in = build(sleep_hours: 7.5)
    check_in.save!

    assert_equal BigDecimal("7.5"), check_in.reload.sleep_hours
  end

  test "flag? tells whether a flag is on" do
    check_in = build(flags: { "alcohol" => true, "meds" => false })

    assert check_in.flag?("alcohol")
    assert check_in.flag?(:alcohol)
    assert_not check_in.flag?("meds")
    assert_not check_in.flag?("illness")
  end

  test "flag_keys lists only true flags" do
    check_in = build(flags: { "alcohol" => true, "meds" => false, "rested" => true })

    assert_equal %w[alcohol rested], check_in.flag_keys.sort
  end

  test "destroying user destroys check_ins" do
    user = users(:one)
    user.check_ins.create!(day_phase: "night")
    own = user.check_ins.count
    others = CheckIn.where.not(user_id: user.id).count

    assert_difference "CheckIn.count", -own do
      user.destroy!
    end
    assert_equal others, CheckIn.count
  end

  test "game session keeps existing when its check-in is deleted" do
    check_in = users(:one).check_ins.create!(day_phase: "day")
    session = GameSession.create!(game: games(:one), user: users(:one), check_in: check_in)

    check_in.destroy!

    assert GameSession.exists?(session.id)
    assert_nil session.reload.check_in_id
  end

  test "game session check-in is optional" do
    assert GameSession.new(game: games(:one)).valid?
  end

  test "destroying user removes game sessions together with their check-ins" do
    user = users(:one)
    check_in = user.check_ins.create!(day_phase: "day")
    GameSession.create!(game: games(:one), user: user, check_in: check_in)

    assert_difference "GameSession.count", -1 do
      assert_difference "CheckIn.count", -user.check_ins.count do
        user.destroy!
      end
    end
    assert_equal 0, CheckIn.where(user_id: user.id).count
  end
end
