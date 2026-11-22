class Games::AdaptiveReactionTestStrategy < Games::BaseStrategy
  MAX_RT_MS = 60_000

  def category = "executive"
  def spec_version = "adaptive_reaction_test@1"
  def primary_unit = "ms"
  def secondary_unit = "count"

  def setup_game
    { sequence: { round_1: generate_round_sequence(35),
                  round_2: generate_round_sequence(35),
                  round_3: generate_round_sequence(35) },
      stimulus_duration: 1000
    }
  end

  # Draft format: one reaction per trial (ms or nil for a miss). The three-part
  # trials format replaces it when the game is redesigned.
  def permitted_result_keys
    [ :false_starts, :mean_rt, :min_rt, :max_rt, { reactions: [] } ]
  end

  def sample_payload(setup)
    count = setup["sequence"].values.sum(&:size)
    { "reactions" => Array.new(count) { |i| 300 + i } }
  end

  def validate_result(_setup, payload)
    reactions = payload["reactions"]
    return false unless reactions.is_a?(Array) && reactions.size <= MAX_TRIALS

    reactions.all? { |value| value.nil? || (value.is_a?(Numeric) && value.between?(0, MAX_RT_MS)) }
  end

  def primary_metric(result) = Games::Stats.median(Array(result["reactions"]))

  def secondary_metric(result)
    reactions = result["reactions"]
    reactions.count(&:nil?).to_f if reactions.is_a?(Array)
  end

  private
  def generate_round_sequence(length = 30)
    sequence = (1..length).map { [ rand(1000...3000) ] }
    add_color_distibution(sequence, rand(50..60))
  end

  def add_color_distibution(sequence, percentage_of_one_color = 50)
    counter_color_1 = sequence.length * percentage_of_one_color / 100
    colors = []

    counter_color_1.times { colors << :color_1 }
    (sequence.length - counter_color_1).times { colors << :color_2 }
    colors.shuffle!

    sequence.map { _1 << colors.pop }
  end
end
