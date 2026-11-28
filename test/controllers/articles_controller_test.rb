require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  test "draft returns 404" do
    get article_path(articles(:draft).slug)

    assert_response :not_found
  end

  test "scheduled article returns 404" do
    get article_path(articles(:scheduled).slug)

    assert_response :not_found
  end

  test "unknown slug returns 404" do
    get article_path("no-such-article")

    assert_response :not_found
  end

  test "news and articles are separate lists" do
    get articles_path

    assert_response :success
    assert_select "main", text: /Sleep and reaction time/
    assert_select "main", text: /First news/, count: 0

    get news_path

    assert_response :success
    assert_select "main", text: /First news/
    assert_select "main", text: /Sleep and reaction time/, count: 0
  end

  test "lists hide drafts and scheduled items" do
    get articles_path
    assert_select "main", text: /A draft/, count: 0

    get news_path
    assert_select "main", text: /Scheduled/, count: 0
  end

  test "lists are sorted by published_at desc" do
    get articles_path

    titles = css_select("main a[href*='/articles/']").map { |link| link.text.squish }
    assert_equal [ "Only in English", "Sleep and reaction time" ], titles
  end

  test "index shows titles in the current language" do
    get articles_path(locale: :ru)

    assert_select "main", text: /Сон и время реакции/
    assert_select "main", text: /Only in English/
  end

  test "unknown kind returns 404" do
    get articles_path(kind: "page")

    assert_response :not_found
  end

  test "kind cannot be overridden by a bad value on the news route" do
    get news_path(kind: "page")

    assert_response :success
    assert_select "main", text: /First news/
  end

  test "fallback notice appears for missing ru translation" do
    get article_path(articles(:english_only).slug, locale: :ru)

    assert_response :success
    assert_select "main", text: /#{Regexp.escape(I18n.t("articles.fallback_notice", locale: :ru))}/
    assert_select "main h1", text: "Only in English"
  end

  test "no fallback notice when the translation exists" do
    get article_path(articles(:published).slug, locale: :ru)

    assert_response :success
    assert_select "main h1", text: "Сон и время реакции"
    assert_no_match(/#{Regexp.escape(I18n.t("articles.fallback_notice", locale: :ru))}/, response.body)
  end

  test "body is rendered through markdown" do
    get article_path(articles(:published).slug)

    assert_response :success
    assert_select "main strong", text: "notes"
  end

  test "markdown cannot inject a script" do
    article = articles(:published)
    article.translations.find_by!(locale: "en").update!(body: "Hi <script>alert(1)</script> [x](javascript:alert(1))")

    get article_path(article.slug)

    assert_select "main script", 0
    assert_select "main a[href^='javascript']", 0
  end

  test "pages are open to anonymous visitors and keep the signed in header" do
    get articles_path
    assert_response :success

    sign_in(users(:one))
    get news_path

    assert_response :success
    assert_select "nav", text: /#{users(:one).nickname}/
  end

  test "header links to news and articles" do
    get games_path

    assert_select "nav a[href=?]", news_path
    assert_select "nav a[href=?]", articles_path
  end

  test "unknown language is 404" do
    get "/xx/articles"

    assert_response :not_found
  end
end
