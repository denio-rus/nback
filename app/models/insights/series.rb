# The finished play-throughs of one user in one game, ready for the charts.
# One query (with the check-in joined in) serves every grouping, so the number
# of queries does not grow with the number of play-throughs.
class Insights::Series
  Point = Struct.new(:session_id, :played_on, :metric, :metric_secondary, :sleep_hours, :flags, :day_phase, :noted) do
    # True when the play-through had a check-in, even an almost empty one.
    def noted? = noted == true
  end
  Group = Struct.new(:points, :count, :median, :min, :max)

  def initialize(user:, game:)
    @user = user
    @game = game
  end

  # Play-throughs with a main metric, oldest first. Ones without a check-in
  # are included: their flags are empty and their day phase is nil.
  def points
    @points ||= load_points
  end

  # { with: Group, without: Group } for one key of CheckIn::FLAGS. Only
  # play-throughs that have a check-in take part: without one there is no
  # answer to the question.
  def groups_for_flag(key)
    key = key.to_s
    raise ArgumentError, "unknown flag: #{key}" unless CheckIn::FLAGS.include?(key)

    with, without = points.select(&:noted?).partition { |point| point.flags[key] == true }
    { with: self.class.group(with), without: self.class.group(without) }
  end

  # { "night" => Group, ... } only for phases that have points.
  def groups_by_day_phase
    points.reject { |point| point.day_phase.nil? }
          .group_by(&:day_phase)
          .transform_values { |list| self.class.group(list) }
  end

  # Count always; median, min and max only from Insights::MIN_POINTS points.
  def self.group(list)
    return Group.new(list, list.size, nil, nil, nil) if list.size < Insights::MIN_POINTS

    values = list.map(&:metric)
    Group.new(list, list.size, Games::Stats.median(values), values.min, values.max)
  end

  private

  def load_points
    sessions = @user.game_sessions
                    .where(game_id: @game.id).where.not(played_at: nil).where.not(metric: nil)
                    .includes(:check_in).order(:played_at, :id)
    sessions.map do |session|
      check_in = session.check_in
      Point.new(session.id, session.played_at.in_time_zone.to_date, session.metric, session.metric_secondary,
                check_in&.sleep_hours, check_in&.flags || {}, check_in&.day_phase, !check_in.nil?)
    end
  end
end
