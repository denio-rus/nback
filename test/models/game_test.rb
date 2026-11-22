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

  test "title and description follow the current locale" do
    game = Game.new(system_name: "reaction_time")

    I18n.with_locale(:en) do
      assert_equal "Simple reaction time", game.title
      assert_match(/space bar/, game.description)
    end
    I18n.with_locale(:ru) do
      assert_equal "Простая реакция", game.title
      assert_match(/пробел/, game.description)
    end
  end

  test "title raises for a game without translations" do
    assert_raises(I18n::MissingTranslationData) { Game.new(system_name: "no_such_game").title }
  end
end
