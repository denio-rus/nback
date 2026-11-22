class Games::NbackStrategy < Games::BaseStrategy
  STEPS = 20

  def category = "memory"
  def spec_version = "nback@1"
  def primary_unit = "%"
  def secondary_unit = "count"

  def setup_game
    { sequence: Array.new(STEPS) { rand(1..9) }, n: 2, stimulus_duration: 1500 }
  end

  # The browser only reports whether the player pressed Match on each stimulus.
  def permitted_result_keys = []

  def extra_trial_keys = [ :pressed ]

  def sample_payload(setup)
    { "trials" => setup["sequence"].each_index.map { |index| client_trial(match?(setup, index)) } }
  end

  # One trial per stimulus, including the ones the player let pass. No times
  # are recorded: the game answers by a single button with a fixed pace.
  def validate_result(setup, payload)
    list = payload["trials"]
    return false unless list.is_a?(Array) && list.size == setup["sequence"].size

    list.all? { |trial| trial.is_a?(Hash) && trial["rt_ms"].nil? && [ true, false ].include?(trial["pressed"]) }
  end

  # The answer is recounted from the stored sequence. Pressing Match is right
  # only when the stimulus repeats the one n steps back.
  def score(setup, payload)
    list = payload["trials"].each_with_index.map do |trial, index|
      { "rt_ms" => nil, "correct" => trial["pressed"] == match?(setup, index), "phase" => nil, "pressed" => trial["pressed"] }
    end
    { trials: list }
  end

  def primary_metric(result)
    list = trials(result)
    (list.count { |trial| trial["correct"] == true }.to_f / list.size * 100).round(1) if list.any?
  end

  def secondary_metric(result)
    list = trials(result)
    list.count { |trial| trial["correct"] == false }.to_f if list.any?
  end

  private

  def match?(setup, index)
    n = setup["n"]
    index >= n && setup["sequence"][index] == setup["sequence"][index - n]
  end

  def client_trial(pressed)
    { "rt_ms" => nil, "correct" => true, "phase" => nil, "pressed" => pressed }
  end
end
