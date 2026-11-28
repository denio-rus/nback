require "test_helper"

class Insights::SeriesTest < ActiveSupport::TestCase
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "reaction_time")
    @user = users(:one)
    @day = Time.zone.local(2026, 6, 1, 12)
  end

  def play(metric, game: @game, user: @user, check_in: nil, days: 0, secondary: nil)
    GameSession.create!(game: game, user: user, check_in: check_in, setup_game: {}, result: {},
                        metric: metric, metric_secondary: secondary, played_at: @day + days.days)
  end

  def note(flags: {}, sleep_hours: nil, day_phase: nil, user: @user)
    user.check_ins.create!(flags: flags, sleep_hours: sleep_hours, day_phase: day_phase)
  end

  def series(game: @game, user: @user) = Insights::Series.new(user: user, game: game)

  test "points only for the user and the game" do
    mine = play(300)
    play(310, user: users(:two))
    play(320, game: Game.find_by!(system_name: "nback"))
    play(nil)
    GameSession.create!(game: @game, user: @user, setup_game: {}, metric: 330) # not played yet

    assert_equal [ mine.id ], series.points.map(&:session_id)
  end

  test "points are ordered by played_at and carry the check-in values" do
    later = play(310, days: 2)
    earlier = play(300, days: 1, secondary: 2, check_in: note(flags: { "rested" => true }, sleep_hours: 7.5, day_phase: "night"))
    points = series.points

    assert_equal [ earlier.id, later.id ], points.map(&:session_id)
    first = points.first
    assert_equal Date.new(2026, 6, 2), first.played_on
    assert_equal [ 300.0, 2.0, 7.5, "night", { "rested" => true } ],
                 [ first.metric, first.metric_secondary, first.sleep_hours.to_f, first.day_phase, first.flags ]
    assert_nil points.last.day_phase
    assert_equal({}, points.last.flags)
  end

  test "median for odd and even counts" do
    odd = Insights::Series.group([ 5, 1, 3, 2, 4 ].map { |v| point(v) })
    even = Insights::Series.group([ 10, 40, 20, 30, 50, 60 ].map { |v| point(v) })

    assert_equal 3.0, odd.median
    assert_equal 35.0, even.median
  end

  test "no median below 5 points" do
    group = Insights::Series.group([ 1, 2, 3, 4 ].map { |v| point(v) })

    assert_equal 4, group.count
    assert_equal 4, group.points.size
    assert_nil group.median
    assert_nil group.min
    assert_nil group.max
  end

  test "min and max from 5 points" do
    group = Insights::Series.group([ 7, 3, 9, 5, 4 ].map { |v| point(v) })

    assert_equal 3, group.min
    assert_equal 9, group.max
  end

  test "sessions without check_in excluded from flag groups" do
    play(300)
    play(310, check_in: note(flags: { "rested" => true }))
    play(320, check_in: note(flags: {}))
    groups = series.groups_for_flag("rested")

    assert_equal 3, series.points.size
    assert_equal [ 1, 1 ], [ groups[:with].count, groups[:without].count ]
  end

  test "group by rested flag" do
    with = play(300, check_in: note(flags: { "rested" => true }))
    without = play(500, check_in: note(flags: { "rested" => false, "alcohol" => true }))
    groups = series.groups_for_flag("rested")

    assert_equal [ with.id ], groups[:with].points.map(&:session_id)
    assert_equal [ without.id ], groups[:without].points.map(&:session_id)
  end

  test "a flag group reaches the median at 5 points" do
    5.times { |i| play(300 + i, check_in: note(flags: { "alcohol" => true })) }
    groups = series.groups_for_flag("alcohol")

    assert_equal 302.0, groups[:with].median
    assert_equal 0, groups[:without].count
    assert_nil groups[:without].median
  end

  test "unknown flag key raises" do
    assert_raises(ArgumentError) { series.groups_for_flag("nope") }
  end

  test "groups by day phase only for phases with points" do
    play(300, check_in: note(day_phase: "night"))
    play(310, check_in: note(day_phase: "night"))
    play(320, check_in: note(day_phase: "morning"))
    play(330)
    groups = series.groups_by_day_phase

    assert_equal %w[morning night], groups.keys.sort
    assert_equal [ 1, 2 ], [ groups["morning"].count, groups["night"].count ]
  end

  test "no data returns empty groups" do
    empty = series

    assert_equal [], empty.points
    assert_equal({}, empty.groups_by_day_phase)
    groups = empty.groups_for_flag("rested")
    assert_equal [ 0, 0 ], [ groups[:with].count, groups[:without].count ]
    assert_nil groups[:with].median
  end

  test "query count is constant" do
    8.times { |i| play(300 + i, check_in: note(flags: { "rested" => i.odd? }, day_phase: "day")) }
    s = series

    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      s.points
      s.groups_for_flag("rested")
      s.groups_for_flag("alcohol")
      s.groups_by_day_phase
    end

    assert_operator count, :<=, 2
  end

  private

  def point(metric)
    Insights::Series::Point.new(1, Date.current, metric, nil, nil, {}, nil, false)
  end
end
