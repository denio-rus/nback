class Games::NbackStrategy < Games::BaseStrategy
  STEPS = 20

  def category = "memory"
  def spec_version = "nback@1"
  def primary_unit = "%"
  def secondary_unit = "count"

  def setup_game
    { sequence: Array.new(STEPS) { rand(1..9) }, n: 2, stimulus_duration: 1500 }
  end

  def permitted_result_keys = %i[correct errors total_trials]

  def sample_payload(setup)
    total = setup["sequence"].size
    { "correct" => total - 2, "errors" => 2, "total_trials" => total }
  end

  def validate_result(setup, payload)
    Games::Stats.valid_totals?(payload, setup["sequence"].size)
  end

  def primary_metric(result)
    total = result["total_trials"].to_i
    (result["correct"].to_f / total * 100).round(1) if total.positive?
  end

  def secondary_metric(result) = result["errors"]&.to_f
end
