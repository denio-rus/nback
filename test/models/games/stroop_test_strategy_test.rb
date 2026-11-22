require "test_helper"

class Games::StroopTestStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = Games::StroopTestStrategy.new
    @setup = JSON.parse(@strategy.setup_game.to_json)
    @payload = @strategy.sample_payload(@setup)
  end

  test "metadata follows the contract" do
    assert_equal "executive", @strategy.category
    assert_equal "stroop_test@1", @strategy.spec_version
    assert_equal "ms", @strategy.primary_unit
    assert_equal "count", @strategy.secondary_unit
  end

  test "setup has 50 word and color pairs" do
    assert_equal 50, @setup["sequence"].size
    assert(@setup["sequence"].all? { |pair| pair.size == 2 })
  end

  # Fixed material: the second element of a pair is the ink color, the right answer.
  FIXED_SETUP = { "sequence" => [ %w[red blue], %w[green green], %w[blue yellow], %w[yellow red] ] }.freeze

  def trial(answer, rt_ms = answer && 400)
    { "rt_ms" => rt_ms, "correct" => true, "phase" => nil, "answer" => answer }
  end

  def result_of(*trials) = { "trials" => trials }

  test "sample payload passes validation and sends one trial per stimulus" do
    assert @strategy.validate_result(@setup, @payload)
    assert_equal 50, @payload["trials"].size
  end

  test "score compares the answer with the ink color of the stored pair" do
    answers = [ "blue", "red", "yellow", nil ]
    trials = @strategy.score(FIXED_SETUP, result_of(*answers.map { |a| trial(a) }))[:trials]

    assert_equal [ true, false, true, false ], trials.map { |t| t["correct"] }
  end

  test "the word is not the answer: reading the word is an error" do
    trials = @strategy.score(FIXED_SETUP, result_of(trial("red"), trial("green"), trial("blue"), trial("yellow")))[:trials]

    assert_equal [ false, true, false, false ], trials.map { |t| t["correct"] }
  end

  test "a forged correct flag does not change the stored metrics" do
    forged = result_of(trial("red"), trial("red"), trial("red"), trial(nil))
    forged["trials"].each { |t| t["correct"] = true }
    result = @strategy.handle_result(FIXED_SETUP, forged)

    assert_equal [ false, false, false, false ], result["trials"].map { |t| t["correct"] }
    assert_equal 4.0, @strategy.secondary_metric(result)
    assert_nil @strategy.primary_metric(result)
  end

  test "score keeps rt and answer and sets no phase" do
    stored = @strategy.score(FIXED_SETUP, result_of(trial("blue", 512).merge("phase" => 7)))[:trials].first

    assert_equal({ "rt_ms" => 512, "correct" => true, "phase" => nil, "answer" => "blue" }, stored)
  end

  test "primary metric is the median rt of correct answers only" do
    result = result_of(
      { "rt_ms" => 300, "correct" => true }, { "rt_ms" => 500, "correct" => true },
      { "rt_ms" => 100, "correct" => false }, { "rt_ms" => nil, "correct" => false }
    )

    assert_equal 400.0, @strategy.primary_metric(result)
  end

  test "secondary metric is the number of errors, nil without trials" do
    result = result_of({ "correct" => false }, { "correct" => true }, { "correct" => false })

    assert_equal 2.0, @strategy.secondary_metric(result)
    assert_nil @strategy.secondary_metric({})
    assert_nil @strategy.primary_metric({})
  end

  test "there are no phases" do
    assert_equal [], @strategy.phases
  end

  test "validation rejects a wrong number of trials" do
    [ 0, 3, 5 ].each do |size|
      assert_not @strategy.validate_result(FIXED_SETUP, result_of(*Array.new(size) { trial("red") })), "size #{size}"
    end
  end

  test "validation rejects malformed trials" do
    bad = [
      "text", nil, 4, {},
      Array.new(4, 5), Array.new(4, nil),
      Array.new(4) { trial("purple") }, Array.new(4) { trial(5) },
      Array.new(4) { trial("red", -1) }, Array.new(4) { trial("red", 60_001) },
      Array.new(4) { trial("red", "fast") }, Array.new(4) { trial("red", nil) },
      Array.new(4) { trial(nil, 300) }, Array.new(4) { trial("red").except("answer") }
    ]
    bad.each do |trials|
      assert_not @strategy.validate_result(FIXED_SETUP, { "trials" => trials }), trials.inspect
    end
  end

  test "validation accepts missed stimuli" do
    assert @strategy.validate_result(FIXED_SETUP, result_of(*Array.new(4) { trial(nil) }))
  end

  test "handle_result drops unknown keys, unknown trial keys and the legacy totals" do
    raw = @payload.deep_dup.merge("evil" => 1, "correct" => 50, "errors" => 0, "total_trials" => 50)
    raw["trials"][0]["hack"] = 1
    result = @strategy.handle_result(@setup, raw)

    assert_equal %w[format trials], result.keys.sort
    assert_not result["trials"][0].key?("hack")
  end
end
