require "test_helper"
require "rails/generators/test_case"
require "generators/game/game_generator"

class GameGeneratorTest < Rails::Generators::TestCase
  tests GameGenerator
  # Tests run in parallel worker processes. The directory is chosen in setup
  # (inside the worker), so every process writes to its own folder.
  setup do
    self.class.destination_root = Rails.root.join("tmp/generator_test_#{Process.pid}").to_s
    prepare_destination
  end
  teardown { FileUtils.rm_rf(destination_root) }

  # Thor prints errors and swallows them unless debug is on; raise them in tests.
  def run_strict(args) = run_generator(args, debug: true)

  test "creates the four game files" do
    run_generator %w[demo_game --category=perception]

    assert_file "app/models/games/demo_game_strategy.rb", /class Games::DemoGameStrategy < Games::BaseStrategy/
    assert_file "app/views/games/_demo_game.html.erb", /data-controller="games--demo-game"/
    assert_file "app/javascript/controllers/games/demo_game_controller.js"
    assert_file "test/models/games/demo_game_strategy_test.rb", /Games::DemoGameStrategy/
  end

  test "strategy skeleton carries the category and spec version" do
    run_generator %w[demo_game --category=memory]

    assert_file "app/models/games/demo_game_strategy.rb" do |content|
      assert_match(/def category = "memory"/, content)
      assert_match(/def spec_version = "demo_game@1"/, content)
      assert_match(/def article_slug = nil/, content)
    end
  end

  test "strategy skeleton rejects every result until the author writes validation" do
    run_generator %w[demo_game --category=memory]

    assert_file "app/models/games/demo_game_strategy.rb", /def validate_result\(_setup, _payload\) = false/
  end

  test "rejects a name that is not snake_case" do
    [ "DemoGame", "demo-game", "1game", "../evil", "demo game" ].each do |name|
      assert_raises(Thor::Error, name) { run_strict [ name, "--category=memory" ] }
    end
  end

  test "rejects an unknown category" do
    assert_raises(Thor::Error) { run_strict %w[demo_game --category=nonsense] }
  end

  test "requires a category" do
    assert_raises(Thor::Error) { run_strict %w[demo_game] }
  end

  test "does not overwrite an existing strategy" do
    path = File.join(destination_root, "app/models/games/demo_game_strategy.rb")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "# keep me\n")

    run_generator %w[demo_game --category=memory --skip]

    assert_equal "# keep me\n", File.read(path)
  end
end
