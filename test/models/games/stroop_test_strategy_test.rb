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

  test "sample payload passes validation" do
    assert @strategy.validate_result(@setup, @payload)
  end

  test "primary metric is nil until trials are recorded" do
    assert_nil @strategy.primary_metric(@payload)
  end

  test "secondary metric is the number of errors" do
    assert_equal 12.0, @strategy.secondary_metric({ "errors" => 12 })
  end

  test "validation rejects impossible totals" do
    bad = [
      { "correct" => 40, "errors" => 10, "total_trials" => 49 },
      { "correct" => 41, "errors" => 10, "total_trials" => 50 },
      { "correct" => -1, "errors" => 51, "total_trials" => 50 },
      { "correct" => "40", "errors" => 10, "total_trials" => 50 },
      {}
    ]
    bad.each { |payload| assert_not @strategy.validate_result(@setup, payload), payload.inspect }
  end

  test "handle_result drops unknown keys" do
    result = @strategy.handle_result(@setup, @payload.merge("evil" => 1))

    assert_equal @payload.merge("format" => Games::BaseStrategy::FORMAT), result
  end
end
