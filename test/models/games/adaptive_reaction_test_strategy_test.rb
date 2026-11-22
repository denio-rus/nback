require "test_helper"

class Games::AdaptiveReactionTestStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = Games::AdaptiveReactionTestStrategy.new
    @setup = JSON.parse(@strategy.setup_game.to_json)
    @payload = @strategy.sample_payload(@setup)
  end

  test "metadata follows the contract" do
    assert_equal "executive", @strategy.category
    assert_equal "adaptive_reaction_test@1", @strategy.spec_version
    assert_equal "ms", @strategy.primary_unit
  end

  test "setup has three rounds" do
    assert_equal %w[round_1 round_2 round_3], @setup["sequence"].keys
  end

  test "sample payload passes validation" do
    assert @strategy.validate_result(@setup, @payload)
  end

  test "primary metric is the median of answered trials" do
    assert_equal 250.0, @strategy.primary_metric({ "reactions" => [ 200, nil, 300 ] })
  end

  test "secondary metric counts missed trials" do
    assert_equal 1.0, @strategy.secondary_metric({ "reactions" => [ 200, nil, 300 ] })
  end

  test "validation rejects malformed reactions" do
    assert_not @strategy.validate_result(@setup, { "reactions" => "text" })
    assert_not @strategy.validate_result(@setup, { "reactions" => [ -1 ] })
    assert_not @strategy.validate_result(@setup, { "reactions" => Array.new(501, 100) })
  end

  test "handle_result drops unknown keys" do
    result = @strategy.handle_result(@setup, @payload.merge("evil" => 1))

    assert_not result.key?("evil")
  end
end
