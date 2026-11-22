require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "valid with a known category" do
    game = Game.new(name: "X", system_name: "x", category: "memory")

    assert game.valid?
  end

  test "invalid with an unknown category" do
    game = Game.new(name: "X", system_name: "x", category: "nonsense")

    assert_not game.valid?
    assert game.errors.key?(:category)
  end

  test "invalid without a category" do
    game = Game.new(name: "X", system_name: "x")

    assert_not game.valid?
  end
end
