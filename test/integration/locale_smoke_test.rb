require "test_helper"

# Visits the main pages in every language. Pages that need a signed in user or
# data are added to this list by the tasks that create them.
class LocaleSmokeTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "reaction_time")
  end

  def public_paths(locale)
    [
      games_path(locale: locale),
      game_path(@game, locale: locale),
      new_session_path(locale: locale),
      new_registration_path(locale: locale),
      new_password_path(locale: locale),
      check_mail_registrations_path(locale: locale)
    ]
  end

  def finished_session
    trials = Array.new(12) { |i| { "rt_ms" => 250 + i, "correct" => true, "phase" => nil } }
    GameSession.create!(game: @game, user: users(:one), setup_game: @game.game_strategy.setup_game,
                        result: { "format" => 1, "trials" => trials }, played_at: Time.current,
                        metric: 255.5, metric_secondary: 0)
  end

  def signed_in_paths(locale)
    [
      user_path(users(:one), locale: locale),
      edit_user_path(users(:one), locale: locale),
      new_game_game_session_path(@game, locale: locale),
      game_session_path(finished_session, locale: locale),
      insights_path(locale: locale),
      insight_path(@game, locale: locale)
    ]
  end

  I18n.available_locales.each do |locale|
    test "public pages render in #{locale} without missing translations" do
      public_paths(locale).each do |path|
        get path

        assert_response :success, path
        assert_no_match(/translation missing/i, response.body, path)
        assert_select "html[lang=?]", locale.to_s
      end
    end

    test "signed in pages render in #{locale} without missing translations" do
      sign_in_as(users(:one))

      signed_in_paths(locale).each do |path|
        get path

        assert_response :success, path
        assert_no_match(/translation missing/i, response.body, path)
      end
    end

    test "play page renders in #{locale}" do
      post game_game_sessions_path(@game, locale: locale)
      follow_redirect!

      assert_response :success
      assert_no_match(/translation missing/i, response.body)
    end

    test "every internal link on the games page keeps the #{locale} prefix" do
      get games_path(locale: locale)

      hrefs = css_select("a[href^='/']").map { |link| link["href"] }
      assert_not_empty hrefs
      hrefs.each do |href|
        next if href.start_with?("/#{locale}/") || href == "/#{locale}"

        # Only the language switcher may point to another language.
        assert_match(%r{\A/(#{I18n.available_locales.join('|')})/games\z}, href, "link without prefix: #{href}")
      end
    end
  end

  test "app code builds no path by hand" do
    offenders = Dir[Rails.root.join("app/{controllers,views,javascript,helpers,mailers}/**/*.{rb,erb,js}")].select do |file|
      File.read(file).match?(%r{["'`]/(games|users|session|passwords|registrations|admin)\b})
    end

    assert_empty offenders.map { |path| path.sub("#{Rails.root}/", "") }, "Use path helpers or data-*-url-value"
  end
end
