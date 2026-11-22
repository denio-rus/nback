require "test_helper"

class Games::RegistrySyncTest < ActiveSupport::TestCase
  setup { Game.where(system_name: Games::Registry.system_names).delete_all }

  test "sync! creates a game for every strategy with its category" do
    Games::Registry.sync!

    names = Games::Registry.system_names
    assert_equal names.sort, Game.where(system_name: names).pluck(:system_name).sort
    assert_equal "vigilance", Game.find_by!(system_name: "reaction_time").category
    assert_equal "memory", Game.find_by!(system_name: "nback").category
    assert(Game.where(system_name: names).all?(&:active))
  end

  test "sync! is idempotent" do
    Games::Registry.sync!

    assert_no_difference "Game.count" do
      Games::Registry.sync!
    end
  end

  test "sync! keeps active as set on an existing game" do
    Games::Registry.sync!
    Game.find_by!(system_name: "nback").update!(active: false)

    Games::Registry.sync!

    assert_not Game.find_by!(system_name: "nback").active
  end

  test "sync! refreshes the category of an existing game" do
    Games::Registry.sync!
    Game.find_by!(system_name: "nback").update!(category: "perception")

    Games::Registry.sync!

    assert_equal "memory", Game.find_by!(system_name: "nback").category
  end
end
