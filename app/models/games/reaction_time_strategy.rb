class Games::ReactionTimeStrategy < Games::BaseStrategy
  TRIALS = 10
  MAX_RT_MS = 60_000

  def category = "vigilance"
  def spec_version = "reaction_time@1"
  def primary_unit = "ms"
  def secondary_unit = "count"

  def setup_game
    { intervals: Array.new(TRIALS) { rand(1000...4000) } }
  end

  def permitted_result_keys
    [ :false_starts, :mean_rt, :min_rt, :max_rt, { reactions: [] } ]
  end

  def sample_payload(setup)
    { "reactions" => Array.new(setup["intervals"].size) { |i| 250 + i } }
  end

  # reactions: one entry per trial, a time in ms or nil for a missed trial.
  def validate_result(setup, payload)
    reactions = payload["reactions"]
    return false unless reactions.is_a?(Array) && reactions.size == setup["intervals"].size

    reactions.all? { |value| value.nil? || (value.is_a?(Numeric) && value.between?(0, MAX_RT_MS)) }
  end

  # Counters are recomputed here, the client values are not trusted.
  def score(_setup, payload)
    answered = payload["reactions"].compact
    {
      false_starts: payload["reactions"].size - answered.size,
      mean_rt: answered.empty? ? 0 : (answered.sum.to_f / answered.size).round,
      min_rt: answered.min,
      max_rt: answered.max
    }
  end

  def primary_metric(result) = Games::Stats.median(Array(result["reactions"]))

  def secondary_metric(result)
    reactions = result["reactions"]
    reactions.count(&:nil?).to_f if reactions.is_a?(Array)
  end
end
