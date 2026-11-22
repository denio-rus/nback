require "test_helper"

class Games::ReactionTimeStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = Games::ReactionTimeStrategy.new
    # Sessions store setup_game as jsonb, so it comes back with string keys.
    @setup = JSON.parse(@strategy.setup_game.to_json)
    @payload = @strategy.sample_payload(@setup)
  end

  test "metadata follows the contract" do
    assert_equal "vigilance", @strategy.category
    assert_equal "reaction_time@1", @strategy.spec_version
    assert_equal "ms", @strategy.primary_unit
    assert_equal "count", @strategy.secondary_unit
  end

  test "setup has ten intervals and no embedded texts" do
    assert_equal 10, @setup["intervals"].size
    assert_not @setup.key?("locales")
  end

  test "sample payload passes validation" do
    assert @strategy.validate_result(@setup, @payload)
  end

  def trial(rt_ms, correct: !rt_ms.nil?)
    { "rt_ms" => rt_ms, "correct" => correct, "phase" => nil }
  end

  def result_with(*times)
    { "trials" => times.map { |rt| trial(rt) } }
  end

  test "sample payload sends one trial per interval" do
    assert_equal @setup["intervals"].size, @payload["trials"].size
  end

  test "primary metric is the median of answered trials" do
    assert_equal 250.0, @strategy.primary_metric(result_with(200, nil, 300, 900, 100))
  end

  test "secondary metric counts missed trials" do
    assert_equal 2.0, @strategy.secondary_metric(result_with(200, nil, nil, 300))
  end

  test "metrics are nil when nothing was answered" do
    assert_nil @strategy.primary_metric(result_with(nil, nil))
    assert_nil @strategy.primary_metric({})
    assert_nil @strategy.secondary_metric({})
  end

  test "there are no phases" do
    assert_equal [], @strategy.phases
  end

  test "validation rejects a wrong number of trials" do
    [ 0, 9, 11 ].each do |size|
      payload = { "trials" => Array.new(size) { trial(250) } }

      assert_not @strategy.validate_result(@setup, payload), "size #{size}"
    end
  end

  test "validation rejects malformed trials" do
    bad = [
      "text", nil, 10, {},
      Array.new(10, 5), Array.new(10, nil),
      Array.new(10) { trial(-5) }, Array.new(10) { trial(60_001) },
      Array.new(10) { trial("fast") }, Array.new(10) { { "correct" => true } }
    ]
    bad.each do |trials|
      assert_not @strategy.validate_result(@setup, { "trials" => trials }), trials.inspect
    end
  end

  test "validation accepts missed trials, also after permit keeps the nil" do
    payload = { "trials" => Array.new(10) { trial(nil) } }

    assert @strategy.validate_result(@setup, payload)
    assert @strategy.validate_result(@setup, @strategy.permit(payload))
  end

  test "score recomputes correct from rt_ms instead of trusting the client" do
    payload = { "trials" => [ trial(200, correct: false), trial(nil, correct: true), trial(300) ] }
    score = @strategy.score(@setup, payload).deep_stringify_keys

    assert_equal [ true, false, true ], score["trials"].map { |t| t["correct"] }
    assert_equal 1, score["misses"]
  end

  test "a forged correct flag does not change the stored metrics" do
    forged = @payload.deep_dup
    forged["trials"][0]["correct"] = false
    forged["trials"][1] = trial(nil, correct: true)
    result = @strategy.handle_result(@setup, forged)

    assert_equal 1.0, @strategy.secondary_metric(result)
    assert_equal false, result["trials"][1]["correct"]
    assert_equal true, result["trials"][0]["correct"]
  end

  test "score forces phase to nil" do
    payload = { "trials" => [ trial(200).merge("phase" => 3) ] }

    assert_nil @strategy.score(@setup, payload)[:trials].first["phase"]
  end

  test "handle_result drops unknown keys, unknown trial keys and the legacy reactions" do
    raw = @payload.deep_dup.merge("evil" => 1, "reactions" => [ 1 ])
    raw["trials"][0]["hack"] = 1
    result = @strategy.handle_result(@setup, raw)

    assert_not result.key?("evil")
    assert_not result.key?("reactions")
    assert_not result["trials"][0].key?("hack")
    assert_equal 1, result["format"]
  end
end
