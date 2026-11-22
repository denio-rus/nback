# Texts for the breakdown page. Every sentence is a translation, numbers are
# only formatted here. Nothing is judged: no norms, no good or bad.
module GameSessionsHelper
  def format_number(value)
    number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
  end

  # "count" is a plain number and has no unit text; the other units are translated.
  def format_with_unit(value, unit)
    return format_number(value) if unit == "count"

    [ format_number(value), t("insights.units.#{unit}") ].join(" ")
  end

  # "312 ms", or "312 ms (errors: 4)" when the game has a second number.
  def primary_with_secondary(game_session, strategy)
    return t("insights.no_metric") if game_session.metric.nil?

    primary = format_with_unit(game_session.metric, strategy.primary_unit)
    return primary if game_session.metric_secondary.nil? || strategy.secondary_unit.nil?

    t("insights.primary_with_secondary",
      primary: primary,
      label: t("games.#{strategy.system_name}.ui.secondary_label"),
      secondary: format_with_unit(game_session.metric_secondary, strategy.secondary_unit))
  end

  # "Block 3: median 340 ms, errors 20%" ("Part 2: ..." for games with parts).
  def block_line(block, strategy)
    scope = strategy.phases.any? ? "part" : "block"
    return t("game_sessions.show.#{scope}_empty", label: block.label) if block.count.zero?

    errors = "#{(block.error_rate * 100).round}%"
    if block.median_rt_ms.nil?
      t("game_sessions.show.#{scope}_no_median", label: block.label, errors: errors)
    else
      t("game_sessions.show.#{scope}", label: block.label, median: format_number(block.median_rt_ms), errors: errors)
    end
  end

  # The difference of two medians, shown only for games that declare the pair.
  def switch_cost_text(strategy, blocks)
    from, to = strategy.switch_cost_phases
    return if from.nil?

    first = blocks.find { |block| block.label == from }&.median_rt_ms
    second = blocks.find { |block| block.label == to }&.median_rt_ms
    return if first.nil? || second.nil?

    t("games.#{strategy.system_name}.ui.switch_cost", from: from, to: to, value: format_number(second - first))
  end

  def check_in_lines(check_in)
    lines = []
    lines << t("game_sessions.show.check_in_sleep", hours: format_number(check_in.sleep_hours)) if check_in.sleep_hours
    lines << t("game_sessions.show.check_in_day_phase", phase: t("check_ins.day_phases.#{check_in.day_phase}")) if check_in.day_phase
    flags = check_in.flag_keys.map { |key| t("check_ins.flags.#{key}") }
    lines << t("game_sessions.show.check_in_flags", flags: flags.join(", ")) if flags.any?
    lines
  end
end
