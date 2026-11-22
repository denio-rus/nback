require "test_helper"

# Checks every localized game in every language: the partial hands Rails-built
# values to Stimulus (submit url and messages) and the game code has no texts
# of its own. Games move out of PENDING as their Task 2.6 sub-task is done.
class GameLocalizationTest < ActionDispatch::IntegrationTest
  PENDING = %w[adaptive_reaction_test].freeze

  def localized_games = Games::Registry.system_names - PENDING

  def read(path) = File.read(Rails.root.join(path))

  setup { Games::Registry.sync! }

  (Games::Registry.system_names - PENDING).each do |system_name|
    I18n.available_locales.each do |locale|
      test "#{system_name} play page in #{locale} has the submit url and messages" do
        game = Game.find_by!(system_name: system_name)
        post game_game_sessions_path(game, locale: locale)
        session = GameSession.order(:id).last
        follow_redirect!

        assert_response :success
        assert_no_match(/translation missing/i, response.body)

        dashed = system_name.dasherize
        root = css_select("[data-controller='games--#{dashed}']").first
        assert root, "partial must carry data-controller='games--#{dashed}'"

        assert_equal "/#{locale}/games/#{game.id}/game_sessions/#{session.id}/submit_result",
                     root["data-games--#{dashed}-submit-url-value"]

        messages = JSON.parse(root["data-games--#{dashed}-messages-value"])
        assert_equal I18n.t("games.#{system_name}.ui", locale: locale).deep_stringify_keys, messages
        assert_not_empty messages
      end
    end

    test "#{system_name} in English shows no Cyrillic text" do
      game = Game.find_by!(system_name: system_name)
      post game_game_sessions_path(game, locale: :en)
      follow_redirect!

      assert_no_match(/\p{Cyrillic}/, css_select("main").to_s)
    end

    test "#{system_name} has titles in every language" do
      I18n.available_locales.each do |locale|
        assert I18n.exists?("games.#{system_name}.title", locale), "title #{locale}"
        assert I18n.exists?("games.#{system_name}.description", locale), "description #{locale}"
        assert I18n.exists?("games.#{system_name}.ui", locale), "ui #{locale}"
      end
    end

    test "#{system_name} partial and controller contain no texts or hand-built paths" do
      partial = read("app/views/games/_#{system_name}.html.erb")
      js = read("app/javascript/controllers/games/#{system_name}_controller.js")

      assert_no_match(/\p{Cyrillic}/, partial.gsub(/<%#.*?%>/m, ""), "partial has Cyrillic text")
      assert_no_match(/\p{Cyrillic}/, js.gsub(%r{//.*$}, ""), "controller has Cyrillic text")
      assert_no_match(%r{/games/\$\{}, js, "controller builds the submit path by hand")
      assert_no_match(/fetch\(/, js, "controller should use submitResult from base.js")
      assert_no_match(/setTimeout\(/, js, "controller should use timers from base.js")
      assert_no_match(/gameIdValue|gameSessionIdValue/, js)
    end
  end
end
