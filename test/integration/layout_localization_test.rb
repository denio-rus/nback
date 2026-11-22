require "test_helper"

class LayoutLocalizationTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    @game = Game.find_by!(system_name: "nback")
  end

  test "navigation is in English for /en" do
    get "/en/games"

    assert_select "nav a", text: "Games"
    assert_select "nav a", text: "Sign in"
    assert_select "nav a", text: "Sign up"
  end

  test "navigation is in Russian for /ru" do
    get "/ru/games"

    assert_select "nav a", text: "Игры"
    assert_select "nav a", text: "Войти"
    assert_select "nav a", text: "Регистрация"
  end

  test "signed in navigation shows profile and sign out" do
    sign_in_as(users(:one))

    get "/ru/games"

    assert_select "nav a", text: "Профиль"
    assert_select "nav button", text: "Выйти"
  end

  test "games list has a localized start button and no placeholder level badge" do
    get "/en/games"

    assert_select "a", text: "Start", minimum: 1
    assert_no_match(/Уровень|Level 1/, response.body)
  end

  test "game page has a localized play button" do
    get game_path(@game, locale: :ru)

    assert_select "a", text: "Играть"
  end

  # Game partials (app/views/games/_<name>.html.erb) are localized in Task 2.6,
  # which extends this check to them.
  test "layout and games pages contain no hardcoded Cyrillic text" do
    files = Dir[Rails.root.join("app/views/layouts/**/*.erb")] +
            Dir[Rails.root.join("app/views/games/{index,show}.html.erb")]
    offenders = files.select do |file|
      # Allow Cyrillic only in ERB comments.
      File.read(file).gsub(/<%#.*?%>/m, "").gsub(/<!--.*?-->/m, "").match?(/\p{Cyrillic}/)
    end

    assert_empty offenders.map { |path| path.sub(Rails.root.to_s + "/", "") },
                 "Move these texts to config/locales"
  end
end
