# Small numeric helpers shared by game strategies.
module Games::Stats
  # Median of the non-nil values, or nil when there are none.
  def self.median(values)
    sorted = values.compact.sort
    return nil if sorted.empty?

    middle = sorted.size / 2
    return sorted[middle].to_f if sorted.size.odd?

    (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  # True when correct, errors and total_trials are non-negative integers,
  # total_trials equals expected_total and every trial is either correct or an error.
  def self.valid_totals?(payload, expected_total)
    correct, errors, total = payload.values_at("correct", "errors", "total_trials")
    return false unless [ correct, errors, total ].all?(Integer)

    total == expected_total && correct >= 0 && errors >= 0 && correct + errors == total
  end
end
