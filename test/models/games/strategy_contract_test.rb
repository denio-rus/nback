require "test_helper"

# Runs the shared contract against every strategy found by the registry, so a
# new game is covered without editing this file.
class Games::StrategyContractTest < ActiveSupport::TestCase
  UNITS = %w[ms % count].freeze

  # Games whose primary metric needs the trials format (Task 6.4). Remove the
  # game from this list when it starts sending trials.
  PRIMARY_METRIC_PENDING = %w[stroop_test].freeze

  Games::Registry.system_names.each do |system_name|
    test "#{system_name} declares valid metadata" do
      strategy = Games::Registry.strategy_for(system_name)

      assert_includes Games::CATEGORIES, strategy.category
      assert_match(/\A#{system_name}@\d+\z/, strategy.spec_version)
      assert_includes UNITS, strategy.primary_unit
      assert_equal system_name, strategy.system_name
    end

    test "#{system_name} builds a setup hash that survives jsonb" do
      setup = Games::Registry.strategy_for(system_name).setup_game

      assert_kind_of Hash, setup
      assert_equal JSON.parse(setup.to_json), JSON.parse(JSON.generate(setup))
    end

    test "#{system_name} accepts its sample payload and computes metrics" do
      strategy = Games::Registry.strategy_for(system_name)
      setup = JSON.parse(strategy.setup_game.to_json)
      payload = strategy.sample_payload(setup)

      assert strategy.validate_result(setup, payload), "sample payload must validate"

      result = strategy.handle_result(setup, payload)

      assert_kind_of Numeric, strategy.primary_metric(result) unless PRIMARY_METRIC_PENDING.include?(system_name)
      assert_kind_of Numeric, strategy.secondary_metric(result) if strategy.secondary_unit
      assert_includes UNITS, strategy.secondary_unit if strategy.secondary_unit
    end

    test "#{system_name} drops unknown keys and rejects garbage" do
      strategy = Games::Registry.strategy_for(system_name)
      setup = JSON.parse(strategy.setup_game.to_json)

      assert_not strategy.handle_result(setup, strategy.sample_payload(setup).merge("bogus" => 1)).key?("bogus")
      assert_raises(Games::BaseStrategy::InvalidResult) { strategy.handle_result(setup, { "bogus" => 1 }) }
      assert_raises(Games::BaseStrategy::InvalidResult) { strategy.handle_result(setup, nil) }
    end
  end
end
