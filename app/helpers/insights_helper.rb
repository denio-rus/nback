# Chart geometry for the "My trends" pages. The SVG is built in ERB, so the
# helper only turns values into positions.
module InsightsHelper
  CHART_WIDTH = 640
  CHART_HEIGHT = 240
  CHART_PADDING = 24

  # Positions of the values along an axis of the given size, in the same order.
  # The smallest value is at 0 (plus padding), the largest at size (minus
  # padding). One value, or equal values, are put in the middle instead of
  # dividing by zero. nil stays nil. invert: true puts larger values at 0, which
  # is what a vertical axis needs because SVG counts y from the top.
  def chart_scale(values, size, padding: 0, invert: false)
    numbers = values.compact
    return values.map { nil } if numbers.empty?

    low, high = numbers.minmax
    span = size - 2.0 * padding
    values.map do |value|
      next if value.nil?

      share = high == low ? 0.5 : (value - low).to_f / (high - low)
      share = 1 - share if invert
      (padding + share * span).round(1)
    end
  end

  # "312 ms" or "312 ms (missed: 4)" for one point of the chart.
  def point_label(point, strategy)
    value = format_with_unit(point.metric, strategy.primary_unit)
    return value if point.metric_secondary.nil? || strategy.secondary_unit.nil?

    t("insights.primary_with_secondary", primary: value, label: t("games.#{strategy.system_name}.ui.secondary_label"),
      secondary: format_with_unit(point.metric_secondary, strategy.secondary_unit))
  end

  # "Play-throughs: 5, median 302 ms, range 300 to 304 ms"; with fewer than
  # Insights::MIN_POINTS points only the count.
  def group_summary(group, strategy)
    return t("insights.summary.count", count: group.count) if group.median.nil?

    t("insights.summary.full", count_text: t("insights.summary.count", count: group.count),
      median: format_with_unit(group.median, strategy.primary_unit),
      min: format_number(group.min), max: format_with_unit(group.max, strategy.primary_unit))
  end
end
