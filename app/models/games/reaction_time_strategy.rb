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

  # Only the trials are read from the browser; every counter is recomputed.
  def permitted_result_keys = []

  def sample_payload(setup)
    { "trials" => Array.new(setup["intervals"].size) { |i| { "rt_ms" => 250 + i, "correct" => true, "phase" => nil } } }
  end

  # trials: one entry per interval, rt_ms is a time in ms or nil for a missed trial.
  def validate_result(setup, payload)
    list = payload["trials"]
    return false unless list.is_a?(Array) && list.size == setup["intervals"].size

    list.all? { |trial| trial.is_a?(Hash) && trial.key?("rt_ms") && valid_rt?(trial["rt_ms"]) }
  end

  # A trial is correct exactly when the player reacted. The client flag and
  # phase are overwritten, the client only supplies the times.
  def score(_setup, payload)
    list = payload["trials"].map do |trial|
      { "rt_ms" => trial["rt_ms"], "correct" => !trial["rt_ms"].nil?, "phase" => nil }
    end
    { trials: list, misses: list.count { |trial| !trial["correct"] } }
  end

  def primary_metric(result)
    Games::Stats.median(trials(result).select { |trial| trial["correct"] == true }.map { |trial| trial["rt_ms"] })
  end

  def secondary_metric(result)
    list = trials(result)
    list.count { |trial| trial["correct"] == false }.to_f if list.any?
  end

  private

  def valid_rt?(value)
    value.nil? || (value.is_a?(Numeric) && value.between?(0, MAX_RT_MS))
  end
end
