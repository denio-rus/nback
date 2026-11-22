require "test_helper"

class Games::RegistryTest < ActiveSupport::TestCase
  test "system_names lists strategy files and excludes the base class" do
    names = Games::Registry.system_names

    assert_includes names, "reaction_time"
    assert_includes names, "nback"
    assert_includes names, "stroop_test"
    assert_not_includes names, "base"
  end

  test "system_names is sorted and frozen" do
    names = Games::Registry.system_names

    assert_equal names.sort, names
    assert names.frozen?
  end

  test "strategy_for returns a strategy instance" do
    strategy = Games::Registry.strategy_for("reaction_time")

    assert_kind_of Games::ReactionTimeStrategy, strategy
  end

  test "strategy_for raises ArgumentError for an unknown name" do
    assert_raises(ArgumentError) { Games::Registry.strategy_for("missing_game") }
  end

  test "strategy_for never constantizes hostile input" do
    [ "../../etc", "Kernel", "base", "", nil, "reaction_time; system('x')" ].each do |name|
      assert_raises(ArgumentError, "input: #{name.inspect}") { Games::Registry.strategy_for(name) }
    end
  end
end
