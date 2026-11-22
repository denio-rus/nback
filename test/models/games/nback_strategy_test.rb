require "test_helper"

class Games::NbackStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = Games::NbackStrategy.new
    @setup = JSON.parse(@strategy.setup_game.to_json)
    @payload = @strategy.sample_payload(@setup)
  end

  test "metadata follows the contract" do
    assert_equal "memory", @strategy.category
    assert_equal "nback@1", @strategy.spec_version
    assert_equal "%", @strategy.primary_unit
    assert_equal "count", @strategy.secondary_unit
  end

  test "setup has a 20 step sequence of digits and n of 2" do
    assert_equal 20, @setup["sequence"].size
    assert(@setup["sequence"].all? { |digit| (1..9).cover?(digit) })
    assert_equal 2, @setup["n"]
  end

  # Fixed material: with n = 2 the stimuli at indexes 2 and 3 repeat the one two steps back.
  FIXED_SETUP = { "sequence" => [ 1, 2, 1, 2, 3, 3 ], "n" => 2 }.freeze

  def answers(*pressed)
    { "trials" => pressed.map { |flag| { "rt_ms" => nil, "correct" => true, "phase" => nil, "pressed" => flag } } }
  end

  test "sample payload passes validation and sends one trial per stimulus" do
    assert @strategy.validate_result(@setup, @payload)
    assert_equal 20, @payload["trials"].size
  end

  test "score marks a pressed match on a real match as correct" do
    trials = @strategy.score(FIXED_SETUP, answers(false, false, true, true, false, false))[:trials]

    assert(trials.all? { |trial| trial["correct"] })
  end

  test "score marks a missed match and a false alarm as errors" do
    trials = @strategy.score(FIXED_SETUP, answers(true, false, false, true, true, false))[:trials]

    assert_equal [ false, true, false, true, false, true ], trials.map { |trial| trial["correct"] }
  end

  test "the first n stimuli have nothing to match, so a press is an error" do
    trials = @strategy.score(FIXED_SETUP, answers(true, true, true, true, false, false))[:trials]

    assert_equal [ false, false, true, true, true, true ], trials.map { |trial| trial["correct"] }
  end

  test "score stores nil rt and no phase and drops the client flag" do
    trial = @strategy.score(FIXED_SETUP, answers(false, false, true, true, false, false))[:trials].first

    assert_equal({ "rt_ms" => nil, "correct" => true, "phase" => nil, "pressed" => false }, trial)
  end

  test "a forged correct flag and forged totals do not change the result" do
    forged = answers(true, true, true, true, true, true).merge("correct" => 6, "errors" => 0, "total_trials" => 6)
    forged["trials"].each { |trial| trial["correct"] = true }
    result = @strategy.handle_result(FIXED_SETUP, forged)

    assert_equal 2, result["trials"].count { |trial| trial["correct"] }
    assert_in_delta 33.3, @strategy.primary_metric(result), 0.05
    assert_equal 4.0, @strategy.secondary_metric(result)
    assert_not result.key?("errors")
  end

  test "primary metric is the share of correct answers in percent" do
    result = { "trials" => [ { "correct" => true }, { "correct" => true }, { "correct" => true }, { "correct" => false } ] }

    assert_equal 75.0, @strategy.primary_metric(result)
  end

  test "secondary metric is the number of errors" do
    result = { "trials" => [ { "correct" => false }, { "correct" => true }, { "correct" => false } ] }

    assert_equal 2.0, @strategy.secondary_metric(result)
  end

  test "metrics are nil without trials" do
    assert_nil @strategy.primary_metric({})
    assert_nil @strategy.primary_metric({ "trials" => [] })
    assert_nil @strategy.secondary_metric({})
  end

  test "validation rejects a wrong number of trials" do
    [ 0, 5, 7, 21 ].each do |size|
      assert_not @strategy.validate_result(FIXED_SETUP, answers(*Array.new(size, false))), "size #{size}"
    end
  end

  test "validation rejects malformed trials" do
    good = { "rt_ms" => nil, "correct" => true, "phase" => nil, "pressed" => false }
    bad = [
      "text", nil, 6, {},
      Array.new(6, 5), Array.new(6, nil),
      Array.new(6) { good.merge("pressed" => "yes") }, Array.new(6) { good.merge("pressed" => nil) },
      Array.new(6) { good.except("pressed") }, Array.new(6) { good.merge("rt_ms" => 300) }
    ]
    bad.each do |trials|
      assert_not @strategy.validate_result(FIXED_SETUP, { "trials" => trials }), trials.inspect
    end
  end

  test "handle_result drops unknown keys, unknown trial keys and the legacy totals" do
    raw = @payload.deep_dup.merge("evil" => 1, "correct" => 20, "errors" => 0, "total_trials" => 20)
    raw["trials"][0]["hack"] = 1
    result = @strategy.handle_result(@setup, raw)

    assert_equal %w[format trials], result.keys.sort
    assert_not result["trials"][0].key?("hack")
  end
end
