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

  test "primary metric is the median of answered trials" do
    assert_equal 250.0, @strategy.primary_metric({ "reactions" => [ 200, nil, 300, 900, 100 ] })
  end

  test "secondary metric counts missed trials" do
    assert_equal 2.0, @strategy.secondary_metric({ "reactions" => [ 200, nil, nil, 300 ] })
  end

  test "metrics are nil when nothing was answered" do
    assert_nil @strategy.primary_metric({ "reactions" => [ nil, nil ] })
    assert_nil @strategy.primary_metric({})
  end

  test "validation rejects malformed reactions" do
    bad = [
      "text", nil, [ 1, 2, 3 ],
      Array.new(10, -5), Array.new(10, 60_001), Array.new(10, "fast")
    ]
    bad.each do |reactions|
      assert_not @strategy.validate_result(@setup, { "reactions" => reactions }), reactions.inspect
    end
  end

  test "score recomputes counters instead of trusting the client" do
    payload = { "reactions" => [ 100, nil, 300 ], "false_starts" => 0, "min_rt" => 1, "max_rt" => 2 }

    assert_equal({ "false_starts" => 1, "mean_rt" => 200, "min_rt" => 100, "max_rt" => 300 },
                 @strategy.score(@setup, payload).stringify_keys)
  end

  test "score has no min or max when every trial was missed" do
    score = @strategy.score(@setup, { "reactions" => [ nil, nil ] }).stringify_keys

    assert_nil score["min_rt"]
    assert_nil score["max_rt"]
    assert_equal 2, score["false_starts"]
  end

  test "handle_result drops unknown keys and the legacy integer trials" do
    raw = @payload.merge("evil" => 1, "trials" => 10)
    result = @strategy.handle_result(@setup, raw)

    assert_not result.key?("evil")
    assert_not result.key?("trials")
    assert_equal @payload["reactions"], result["reactions"]
  end
end
