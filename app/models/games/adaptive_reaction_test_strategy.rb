# Three parts of 35 stimuli, two buttons (a and b), the color shown is red or green.
# Part 1 and 3: red is a, green is b. Part 2: the rule is swapped.
class Games::AdaptiveReactionTestStrategy < Games::BaseStrategy
  MAX_RT_MS = 60_000
  PART_SIZE = 35
  ROUNDS = %w[round_1 round_2 round_3].freeze
  COLORS = %w[red green].freeze
  BUTTONS = %w[a b].freeze
  RULES = {
    1 => { "red" => "a", "green" => "b" },
    2 => { "red" => "b", "green" => "a" },
    3 => { "red" => "a", "green" => "b" }
  }.freeze

  def category = "executive"
  def spec_version = "adaptive_reaction_test@1"
  def primary_unit = "ms"
  def secondary_unit = "count"
  def phases = RULES.keys

  # The rule changes between part 1 and part 2.
  def switch_cost_phases = [ 1, 2 ]

  # sequence: per part a list of [delay_ms, color]. rules is sent to the browser
  # for the on-screen hint; the server scores with RULES.
  def setup_game
    {
      sequence: ROUNDS.index_with { generate_round_sequence(PART_SIZE) },
      rules: RULES,
      stimulus_duration: 1000
    }
  end

  # The browser reports what was shown and which button was pressed.
  def permitted_result_keys = []

  def extra_trial_keys = [ :shown, :pressed ]

  def sample_payload(setup)
    { "trials" => expected_stimuli(setup).map { |phase, color| client_trial(phase, color) } }
  end

  # One trial per stimulus in the stored order. pressed is a button or nil for a
  # miss; a miss has no time, an answer needs a time in range.
  def validate_result(setup, payload)
    list = payload["trials"]
    expected = expected_stimuli(setup)
    return false unless list.is_a?(Array) && list.size == expected.size

    list.zip(expected).all? { |trial, (phase, color)| valid_trial?(trial, phase, color) }
  end

  # correct is recomputed from shown, pressed and the rule of the part.
  def score(_setup, payload)
    list = payload["trials"].map do |trial|
      correct = RULES.fetch(trial["phase"])[trial["shown"]] == trial["pressed"]
      trial.slice("rt_ms", "phase", "shown", "pressed").merge("correct" => correct)
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

  # [phase, color] for every stimulus of the stored sequence, in play order.
  def expected_stimuli(setup)
    sequence = setup["sequence"]
    return [] unless sequence.is_a?(Hash)

    ROUNDS.each_with_index.flat_map do |round, index|
      Array(sequence[round]).map { |(_delay, color)| [ index + 1, color ] }
    end
  end

  def client_trial(phase, color)
    pressed = RULES.fetch(phase)[color]
    { "rt_ms" => 350, "correct" => true, "phase" => phase, "shown" => color, "pressed" => pressed }
  end

  def valid_trial?(trial, phase, color)
    return false unless trial.is_a?(Hash) && trial["phase"] == phase && trial["shown"] == color
    return false unless trial.key?("pressed") && trial.key?("rt_ms")
    return trial["rt_ms"].nil? if trial["pressed"].nil?

    BUTTONS.include?(trial["pressed"]) && trial["rt_ms"].is_a?(Numeric) && trial["rt_ms"].between?(0, MAX_RT_MS)
  end

  # A shuffled list of [delay_ms, color]; the colors are split 18 to 17.
  def generate_round_sequence(length)
    first, second = COLORS.shuffle
    colors = Array.new(length) { |i| i < length / 2 ? second : first }.shuffle

    colors.map { |color| [ rand(1000...3000), color ] }
  end
end
