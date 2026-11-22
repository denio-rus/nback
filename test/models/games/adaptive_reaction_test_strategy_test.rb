require "test_helper"

class Games::AdaptiveReactionTestStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = Games::AdaptiveReactionTestStrategy.new
    @setup = JSON.parse(@strategy.setup_game.to_json)
    @payload = @strategy.sample_payload(@setup)
  end

  # Fixed material: two stimuli per part. Rules: parts 1 and 3 red=a, green=b; part 2 swapped.
  FIXED_SETUP = {
    "sequence" => {
      "round_1" => [ [ 1000, "red" ], [ 1000, "green" ] ],
      "round_2" => [ [ 1000, "red" ], [ 1000, "green" ] ],
      "round_3" => [ [ 1000, "red" ], [ 1000, "green" ] ]
    }
  }.freeze

  def trial(phase, shown, pressed, rt_ms = pressed && 400)
    { "rt_ms" => rt_ms, "correct" => true, "phase" => phase, "shown" => shown, "pressed" => pressed }
  end

  def right_answers
    [ trial(1, "red", "a"), trial(1, "green", "b"), trial(2, "red", "b"), trial(2, "green", "a"),
      trial(3, "red", "a"), trial(3, "green", "b") ]
  end

  test "metadata follows the contract" do
    assert_equal "executive", @strategy.category
    assert_equal "adaptive_reaction_test@1", @strategy.spec_version
    assert_equal "ms", @strategy.primary_unit
    assert_equal "count", @strategy.secondary_unit
  end

  test "the switch cost compares part 1 with part 2" do
    assert_equal [ 1, 2 ], @strategy.switch_cost_phases
    assert_nil Games::ReactionTimeStrategy.new.switch_cost_phases
  end

  test "phases are the three parts" do
    assert_equal [ 1, 2, 3 ], @strategy.phases
  end

  test "setup has three parts of 35 trials with a delay and a color" do
    assert_equal %w[round_1 round_2 round_3], @setup["sequence"].keys
    @setup["sequence"].each_value do |part|
      assert_equal 35, part.size
      assert(part.all? { |delay, color| delay.between?(1000, 2999) && %w[red green].include?(color) })
    end
  end

  test "colors are split 18 to 17 in each part" do
    @setup["sequence"].each_value do |part|
      assert_equal [ 17, 18 ], part.map(&:last).tally.values.sort
    end
  end

  test "setup carries the rules: parts 1 and 3 are equal, part 2 is swapped" do
    rules = @setup["rules"]

    assert_equal({ "red" => "a", "green" => "b" }, rules["1"])
    assert_equal({ "red" => "b", "green" => "a" }, rules["2"])
    assert_equal rules["1"], rules["3"]
    assert_equal 1000, @setup["stimulus_duration"]
  end

  test "sample payload has one trial per stimulus and passes validation" do
    assert_equal 105, @payload["trials"].size
    assert @strategy.validate_result(@setup, @payload)
  end

  test "score applies the rule of the part to shown and pressed" do
    trials = @strategy.score(FIXED_SETUP, { "trials" => right_answers })[:trials]

    assert(trials.all? { |t| t["correct"] })
  end

  test "the same press is right in one part and wrong in another" do
    answers = right_answers.map { |t| t.merge("pressed" => "a") }
    trials = @strategy.score(FIXED_SETUP, { "trials" => answers })[:trials]

    assert_equal [ true, false, false, true, true, false ], trials.map { |t| t["correct"] }
  end

  test "a missed stimulus is an error without a time" do
    answers = right_answers.tap { |list| list[0] = trial(1, "red", nil) }
    first = @strategy.score(FIXED_SETUP, { "trials" => answers })[:trials].first

    assert_equal false, first["correct"]
    assert_nil first["rt_ms"]
  end

  test "a forged correct flag does not change the stored metrics" do
    forged = right_answers.map { |t| t.merge("pressed" => "a", "correct" => true) }
    result = @strategy.handle_result(FIXED_SETUP, { "trials" => forged })

    assert_equal [ true, false, false, true, true, false ], result["trials"].map { |t| t["correct"] }
    assert_equal 3.0, @strategy.secondary_metric(result)
  end

  test "score keeps shown, pressed, rt and the part of every trial" do
    stored = @strategy.score(FIXED_SETUP, { "trials" => right_answers })[:trials][2]

    assert_equal({ "rt_ms" => 400, "correct" => true, "phase" => 2, "shown" => "red", "pressed" => "b" }, stored)
  end

  test "primary metric is the median rt of correct answers over all parts" do
    result = { "trials" => [
      { "rt_ms" => 300, "correct" => true, "phase" => 1 }, { "rt_ms" => 500, "correct" => true, "phase" => 2 },
      { "rt_ms" => 900, "correct" => true, "phase" => 3 }, { "rt_ms" => 100, "correct" => false, "phase" => 3 },
      { "rt_ms" => nil, "correct" => false, "phase" => 3 }
    ] }

    assert_equal 500.0, @strategy.primary_metric(result)
  end

  test "secondary metric is the number of errors, nil without trials" do
    result = { "trials" => [ { "correct" => false }, { "correct" => true }, { "correct" => false } ] }

    assert_equal 2.0, @strategy.secondary_metric(result)
    assert_nil @strategy.secondary_metric({})
    assert_nil @strategy.primary_metric({})
  end

  test "validation rejects a wrong number of trials" do
    [ 0, 5, 7, 105 ].each do |size|
      payload = { "trials" => Array.new(size) { trial(1, "red", "a") } }

      assert_not @strategy.validate_result(FIXED_SETUP, payload), "size #{size}"
    end
  end

  test "validation rejects malformed trials" do
    base = right_answers
    bad = [
      "text", nil, 6, {}, Array.new(6, 5), Array.new(6, nil),
      base.map { |t| t.merge("pressed" => "c") },
      base.map { |t| t.merge("pressed" => 1) },
      base.map { |t| t.merge("rt_ms" => -1) },
      base.map { |t| t.merge("rt_ms" => 60_001) },
      base.map { |t| t.merge("rt_ms" => "fast") },
      base.map { |t| t.merge("rt_ms" => nil) },
      base.map { |t| t.merge("pressed" => nil) },
      base.map { |t| t.except("pressed") },
      base.map { |t| t.except("shown") },
      base.map { |t| t.merge("shown" => "blue") },
      base.map { |t| t.merge("phase" => 4) },
      base.map { |t| t.merge("phase" => 1) }
    ]
    bad.each do |trials|
      assert_not @strategy.validate_result(FIXED_SETUP, { "trials" => trials }), trials.inspect
    end
  end

  test "validation rejects a shown color that differs from the stored sequence" do
    swapped = right_answers.map { |t| t.merge("shown" => t["shown"] == "red" ? "green" : "red") }

    assert_not @strategy.validate_result(FIXED_SETUP, { "trials" => swapped })
  end

  test "validation accepts missed stimuli" do
    missed = right_answers.map { |t| t.merge("pressed" => nil, "rt_ms" => nil) }

    assert @strategy.validate_result(FIXED_SETUP, { "trials" => missed })
    assert @strategy.validate_result(FIXED_SETUP, @strategy.permit({ "trials" => missed }))
  end

  test "handle_result drops unknown keys, unknown trial keys and the legacy reactions" do
    raw = @payload.deep_dup.merge("evil" => 1, "reactions" => [ 1 ])
    raw["trials"][0]["hack"] = 1
    result = @strategy.handle_result(@setup, raw)

    assert_equal %w[format trials], result.keys.sort
    assert_not result["trials"][0].key?("hack")
  end
end
