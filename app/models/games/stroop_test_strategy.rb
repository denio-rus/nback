# 50 stimuli, 4 colors, 4 words, 2000 ms per stimulus.
# Colors: red, green, blue, yellow.
class Games::StroopTestStrategy < Games::BaseStrategy
  COLORS = %i[red green blue yellow].freeze
  STEPS = 50
  MAX_RT_MS = 60_000

  def category = "executive"
  def spec_version = "stroop_test@1"
  def primary_unit = "ms"
  def secondary_unit = "count"

  def setup_game
    { sequence: make_combinations(STEPS), stimulus_duration: 2000 }
  end

  # The browser reports the pressed color and the time for each stimulus.
  def permitted_result_keys = []

  def extra_trial_keys = [ :answer ]

  def sample_payload(setup)
    { "trials" => setup["sequence"].each_with_index.map { |(_word, ink), index| client_trial(ink, 400 + index) } }
  end

  # One trial per stimulus. answer is a color of COLORS, or nil when the player
  # did not press anything; a missed stimulus has no time.
  def validate_result(setup, payload)
    list = payload["trials"]
    return false unless list.is_a?(Array) && list.size == setup["sequence"].size

    list.all? { |trial| trial.is_a?(Hash) && valid_answer?(trial) }
  end

  # The right answer is the ink color from the stored pair, not the word.
  def score(setup, payload)
    list = payload["trials"].each_with_index.map do |trial, index|
      { "rt_ms" => trial["rt_ms"], "correct" => trial["answer"] == setup["sequence"][index][1],
        "phase" => nil, "answer" => trial["answer"] }
    end
    { trials: list }
  end

  def primary_metric(result)
    Games::Stats.median(trials(result).select { |trial| trial["correct"] == true }.map { |trial| trial["rt_ms"] })
  end

  def secondary_metric(result)
    list = trials(result)
    list.count { |trial| trial["correct"] == false }.to_f if list.any?
  end

  private

  def client_trial(answer, rt_ms)
    { "rt_ms" => rt_ms, "correct" => true, "phase" => nil, "answer" => answer }
  end

  # No answer means no time; an answer needs a time in range.
  def valid_answer?(trial)
    return false unless trial.key?("answer") && trial.key?("rt_ms")
    return trial["rt_ms"].nil? if trial["answer"].nil?

    COLORS.map(&:to_s).include?(trial["answer"]) &&
      trial["rt_ms"].is_a?(Numeric) && trial["rt_ms"].between?(0, MAX_RT_MS)
  end

  def make_combinations(count)
    colors = sequence_generator(count)
    words = sequence_generator(count)

    words.map.with_index { [ _1, colors[_2] ] }
  end

  def sequence_generator(count)
    Array.new(count) { COLORS.sample }
  end
end
