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

  test "sample payload passes validation" do
    assert @strategy.validate_result(@setup, @payload)
  end

  test "primary metric is the share of correct answers in percent" do
    assert_equal 75.0, @strategy.primary_metric({ "correct" => 15, "total_trials" => 20 })
  end

  test "secondary metric is the number of errors" do
    assert_equal 5.0, @strategy.secondary_metric({ "errors" => 5 })
  end

  test "metrics are nil without trials" do
    assert_nil @strategy.primary_metric({ "correct" => 0, "total_trials" => 0 })
    assert_nil @strategy.primary_metric({})
    assert_nil @strategy.secondary_metric({})
  end

  test "validation rejects impossible totals" do
    bad = [
      { "correct" => 15, "errors" => 5, "total_trials" => 19 },
      { "correct" => 15, "errors" => 6, "total_trials" => 20 },
      { "correct" => -1, "errors" => 5, "total_trials" => 20 },
      { "correct" => "15", "errors" => 5, "total_trials" => 20 },
      { "correct" => 15, "total_trials" => 20 },
      {}
    ]
    bad.each { |payload| assert_not @strategy.validate_result(@setup, payload), payload.inspect }
  end

  test "handle_result drops unknown keys" do
    result = @strategy.handle_result(@setup, @payload.merge("evil" => 1))

    assert_equal @payload.merge("format" => Games::BaseStrategy::FORMAT), result
  end
end
