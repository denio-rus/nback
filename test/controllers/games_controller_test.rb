require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Games::Registry.sync!
    Game.where(system_name: %w[MyString MyString1]).update_all(active: false)
  end

  test "should get index" do
    get games_url

    assert_response :success
  end

  test "index lists only active games" do
    Game.find_by!(system_name: "nback").update!(active: false)

    get games_url

    assert_response :success
    assert_select "h3", text: "Simple reaction time"
    assert_select "h3", text: "N-Back", count: 0
  end

  test "show hides an inactive game" do
    game = Game.find_by!(system_name: "nback")
    game.update!(active: false)

    get game_url(game)

    assert_response :not_found
  end

  test "show works for an active game" do
    get game_url(Game.find_by!(system_name: "nback"))

    assert_response :success
  end

  test "shows link for published article" do
    game = Game.find_by!(system_name: "nback")

    with_article_slug(articles(:published).slug) { get game_url(game) }

    assert_response :success
    assert_select "main a[href=?]", article_path(articles(:published).slug), text: I18n.t("articles.read_more", locale: :en)
  end

  test "read more link keeps the language prefix" do
    game = Game.find_by!(system_name: "nback")

    with_article_slug(articles(:published).slug) { get game_url(game, locale: :ru) }

    assert_response :success
    assert_select "main a[href=?]", article_path(articles(:published).slug, locale: :ru), text: I18n.t("articles.read_more", locale: :ru)
  end

  test "hides link for draft" do
    game = Game.find_by!(system_name: "nback")

    with_article_slug(articles(:draft).slug) { get game_url(game) }

    assert_response :success
    assert_select "main a[href*='/articles/']", count: 0
  end

  test "hides link for a slug without an article" do
    game = Game.find_by!(system_name: "nback")

    with_article_slug("no-such-article") { get game_url(game) }

    assert_response :success
    assert_select "main a[href*='/articles/']", count: 0
  end

  test "hides link when slug is nil" do
    game = Game.find_by!(system_name: "nback")
    assert_nil game.game_strategy.article_slug

    get game_url(game)

    assert_response :success
    assert_select "main a[href*='/articles/']", count: 0
  end

  private

  # Minitest 6 has no #stub, so the slug is overridden on a real strategy class
  # for the block only. remove_method restores the inherited nil default.
  def with_article_slug(slug)
    strategy = Games::NbackStrategy
    strategy.define_method(:article_slug) { slug }
    yield
  ensure
    strategy.remove_method(:article_slug)
  end
end
