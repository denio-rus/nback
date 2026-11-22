# 50 stimuli, 4 colors, 4 words, 2000 ms per stimulus.
# Colors: red, green, blue, yellow.
class Games::StroopTestStrategy < Games::BaseStrategy
  COLORS = %i[red green blue yellow].freeze
  STEPS = 50

  def category = "executive"
  def spec_version = "stroop_test@1"
  def primary_unit = "ms"
  def secondary_unit = "count"

  def setup_game
    { sequence: make_combinations(STEPS), stimulus_duration: 2000 }
  end

  def permitted_result_keys = %i[correct errors total_trials]

  def sample_payload(setup)
    total = setup["sequence"].size
    { "correct" => total - 5, "errors" => 5, "total_trials" => total }
  end

  def validate_result(setup, payload)
    Games::Stats.valid_totals?(payload, setup["sequence"].size)
  end

  # Response times are not recorded yet; they arrive with the trials format.
  def primary_metric(_result) = nil

  def secondary_metric(result) = result["errors"]&.to_f

  private

  def make_combinations(count)
    colors = sequence_generator(count)
    words = sequence_generator(count)

    words.map.with_index { [ _1, colors[_2] ] }
  end

  def sequence_generator(count)
    Array.new(count) { COLORS.sample }
  end
end
