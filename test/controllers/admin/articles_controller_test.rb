require "test_helper"

class Admin::ArticlesControllerTest < ActionDispatch::IntegrationTest
  # Params as the form sends them: one numbered section per language.
  def article_params(slug: "new-article", kind: "article", publish: "0", en: { title: "Title", body: "Body" }, ru: { title: "", body: "" })
    { article: { slug: slug, kind: kind, publish: publish,
                 translations_attributes: { "0" => { locale: "en" }.merge(en), "1" => { locale: "ru" }.merge(ru) } } }
  end

  # --- access ---

  test "player cannot access" do
    sign_in(users(:one))

    get admin_articles_url
    assert_redirected_to games_url
    get new_admin_article_url
    assert_redirected_to games_url
    get edit_admin_article_url(articles(:published))
    assert_redirected_to games_url

    assert_no_difference("Article.count") { post admin_articles_url, params: article_params }
    assert_redirected_to games_url

    patch admin_article_url(articles(:published)), params: { article: { slug: "hijacked" } }
    assert_redirected_to games_url
    assert_equal "sleep-and-reaction", articles(:published).reload.slug

    assert_no_difference("Article.count") { delete admin_article_url(articles(:published)) }
    assert_redirected_to games_url
  end

  test "anonymous cannot access" do
    get admin_articles_url
    assert_redirected_to new_session_url
    get new_admin_article_url
    assert_redirected_to new_session_url

    assert_no_difference("Article.count") { post admin_articles_url, params: article_params }
    assert_redirected_to new_session_url

    patch admin_article_url(articles(:published)), params: { article: { slug: "hijacked" } }
    assert_redirected_to new_session_url
    assert_equal "sleep-and-reaction", articles(:published).reload.slug

    assert_no_difference("Article.count") { delete admin_article_url(articles(:published)) }
    assert_redirected_to new_session_url
  end

  # --- index, new, edit ---

  test "index lists slug, kind and status" do
    sign_in_as_admin users(:admin)

    get admin_articles_url

    assert_response :success
    assert_select "[data-article=?]", articles(:published).slug do
      assert_select "[data-status=?]", "published"
      assert_select "a[href=?]", edit_admin_article_path(articles(:published))
    end
    assert_select "[data-article=?] [data-status=?]", articles(:draft).slug, "draft"
    assert_select "[data-article=?] [data-kind=?]", articles(:news_item).slug, "news"
  end

  test "index delete button asks for confirmation" do
    sign_in_as_admin users(:admin)

    get admin_articles_url

    assert_select "form[action=?] button[data-turbo-confirm]", admin_article_path(articles(:draft))
  end

  test "new form has a section for every language" do
    sign_in_as_admin users(:admin)

    get new_admin_article_url

    assert_response :success
    assert_select "input[name=?]", "article[slug]"
    assert_select "select[name=?] option", "article[kind]", count: Article::KINDS.size
    assert_select "input[type=checkbox][name=?]", "article[publish]"
    I18n.available_locales.each_with_index do |locale, index|
      assert_select "input[name=?][value=?]", "article[translations_attributes][#{index}][locale]", locale.to_s
      assert_select "input[name=?]", "article[translations_attributes][#{index}][title]"
      assert_select "textarea[name=?]", "article[translations_attributes][#{index}][body]"
    end
  end

  test "edit form shows existing texts and sections for missing languages" do
    sign_in_as_admin users(:admin)

    get edit_admin_article_url(articles(:english_only))

    assert_response :success
    assert_select "input[name=?][value=?]", "article[translations_attributes][0][title]", "Only in English"
    assert_select "input[name=?]", "article[translations_attributes][0][id]"
    assert_select "input[name=?][value=?]", "article[translations_attributes][1][locale]", "ru"
    assert_select "input[name=?]", "article[translations_attributes][1][id]", count: 0
  end

  test "edit form of a published article has the publish box checked" do
    sign_in_as_admin users(:admin)

    get edit_admin_article_url(articles(:published))
    assert_select "input[type=checkbox][name=?][checked]", "article[publish]"

    get edit_admin_article_url(articles(:draft))
    assert_select "input[type=checkbox][name=?]", "article[publish]"
    assert_select "input[type=checkbox][name=?][checked]", "article[publish]", count: 0
  end

  test "form shows the markdown hint" do
    sign_in_as_admin users(:admin)

    get new_admin_article_url

    assert_select "[data-markdown-hint]"
  end

  I18n.available_locales.each do |locale|
    test "admin article pages render in #{locale} without missing translations" do
      sign_in_as_admin users(:admin)

      [ admin_articles_path(locale: locale), new_admin_article_path(locale: locale),
        edit_admin_article_path(articles(:published), locale: locale) ].each do |path|
        get path

        assert_response :success, path
        assert_no_match(/translation missing/i, response.body, path)
        assert_select "html[lang=?]", locale.to_s
      end
    end
  end

  # --- create ---

  test "admin creates article with en and ru" do
    sign_in_as_admin users(:admin)

    assert_difference("Article.count", +1) do
      assert_difference("ArticleTranslation.count", +2) do
        post admin_articles_url, params: article_params(ru: { title: "Заголовок", body: "Текст" })
      end
    end

    assert_redirected_to admin_articles_url
    assert_equal I18n.t("admin.articles.created"), flash[:notice]
    article = Article.find_by!(slug: "new-article")
    assert_equal %w[en ru], article.translations.map(&:locale).sort
    assert_equal "Заголовок", article.translation_for(:ru).title
    assert_nil article.published_at
  end

  test "empty ru section is not saved" do
    sign_in_as_admin users(:admin)

    assert_difference("Article.count", +1) do
      post admin_articles_url, params: article_params
    end

    assert_equal [ "en" ], Article.find_by!(slug: "new-article").translations.map(&:locale)
  end

  test "missing english text re-renders the form" do
    sign_in_as_admin users(:admin)

    assert_no_difference("Article.count") do
      post admin_articles_url, params: article_params(en: { title: "", body: "" }, ru: { title: "Заголовок", body: "Текст" })
    end

    assert_response :unprocessable_content
    assert_select "#error_explanation"
    # The text typed into the other language stays in the form.
    assert_select "input[name=?][value=?]", "article[translations_attributes][1][title]", "Заголовок"
  end

  test "bad slug re-renders form" do
    sign_in_as_admin users(:admin)

    assert_no_difference([ "Article.count", "ArticleTranslation.count" ]) do
      post admin_articles_url, params: article_params(slug: "Bad Slug!")
    end

    assert_response :unprocessable_content
    assert_select "#error_explanation"
    assert_select "input[name=?][value=?]", "article[slug]", "Bad Slug!"
    assert_select "input[name=?][value=?]", "article[translations_attributes][0][title]", "Title"
  end

  test "taken slug re-renders form" do
    sign_in_as_admin users(:admin)

    assert_no_difference("Article.count") do
      post admin_articles_url, params: article_params(slug: articles(:published).slug)
    end

    assert_response :unprocessable_content
  end

  test "unknown kind is rejected by validation" do
    sign_in_as_admin users(:admin)

    assert_no_difference("Article.count") do
      post admin_articles_url, params: article_params(kind: "Kernel")
    end

    assert_response :unprocessable_content
    assert_select "#error_explanation"
  end

  test "unknown translation locale is rejected by validation" do
    sign_in_as_admin users(:admin)
    params = article_params
    params[:article][:translations_attributes]["1"] = { locale: "xx", title: "T", body: "B" }

    assert_no_difference([ "Article.count", "ArticleTranslation.count" ]) do
      post admin_articles_url, params: params
    end

    assert_response :unprocessable_content
  end

  test "two sections for one language are rejected, not a server error" do
    sign_in_as_admin users(:admin)
    params = article_params
    params[:article][:translations_attributes]["1"] = { locale: "en", title: "Again", body: "Again" }

    assert_no_difference([ "Article.count", "ArticleTranslation.count" ]) do
      post admin_articles_url, params: params
    end

    assert_response :unprocessable_content
  end

  test "unpermitted attributes are ignored" do
    sign_in_as_admin users(:admin)
    params = article_params
    params[:article][:published_at] = 1.day.ago.to_s
    params[:article][:id] = 999_999

    post admin_articles_url, params: params

    article = Article.find_by!(slug: "new-article")
    assert_nil article.published_at
    assert_not_equal 999_999, article.id
  end

  test "publish checkbox sets published_at" do
    sign_in_as_admin users(:admin)

    freeze_time do
      post admin_articles_url, params: article_params(publish: "1")

      assert_equal Time.current, Article.find_by!(slug: "new-article").published_at
    end
  end

  # --- update ---

  test "publishing a draft sets published_at" do
    sign_in_as_admin users(:admin)
    draft = articles(:draft)

    freeze_time do
      patch admin_article_url(draft), params: { article: { publish: "1" } }

      assert_redirected_to admin_articles_url
      assert_equal Time.current, draft.reload.published_at
    end
  end

  test "unpublishing sets published_at to nil" do
    sign_in_as_admin users(:admin)

    patch admin_article_url(articles(:published)), params: { article: { publish: "0" } }

    assert_redirected_to admin_articles_url
    assert_nil articles(:published).reload.published_at
    assert_not_includes Article.published, articles(:published)
  end

  test "editing keeps an existing published_at when publish stays 1" do
    sign_in_as_admin users(:admin)
    before = articles(:published).published_at

    patch admin_article_url(articles(:published)), params: { article: { publish: "1", kind: "news" } }

    assert_equal "news", articles(:published).reload.kind
    assert_in_delta before.to_f, articles(:published).published_at.to_f, 0.001
  end

  test "update changes an existing translation and keeps the others" do
    sign_in_as_admin users(:admin)
    article = articles(:published)
    english = article_translations(:published_en)
    russian = article_translations(:published_ru)

    assert_no_difference("ArticleTranslation.count") do
      patch admin_article_url(article), params: { article: { publish: "1", translations_attributes: {
        "0" => { id: english.id, locale: "en", title: "New title", body: "New body" },
        "1" => { id: russian.id, locale: "ru", title: russian.title, body: russian.body }
      } } }
    end

    assert_redirected_to admin_articles_url
    assert_equal "New title", english.reload.title
    assert_equal russian.title, russian.reload.title
  end

  test "update adds a language and an empty section does not wipe the default one" do
    sign_in_as_admin users(:admin)
    article = articles(:english_only)
    english = article_translations(:english_only_en)

    assert_difference("ArticleTranslation.count", +1) do
      patch admin_article_url(article), params: { article: { translations_attributes: {
        "0" => { id: english.id, locale: "en", title: "", body: "" },
        "1" => { locale: "ru", title: "Только", body: "Текст" }
      } } }
    end

    assert_equal "Only in English", english.reload.title
    assert_equal "Только", article.translation_for(:ru).title
  end

  test "update with an empty ru section creates nothing" do
    sign_in_as_admin users(:admin)
    article = articles(:english_only)

    assert_no_difference("ArticleTranslation.count") do
      patch admin_article_url(article), params: { article: { slug: "only-english", translations_attributes: {
        "0" => { id: article_translations(:english_only_en).id, locale: "en", title: "Only in English", body: "No translation yet." },
        "1" => { locale: "ru", title: "", body: "" }
      } } }
    end

    assert_redirected_to admin_articles_url
  end

  test "bad slug on update re-renders the form and changes nothing" do
    sign_in_as_admin users(:admin)

    patch admin_article_url(articles(:published)), params: { article: { slug: "NOT OK" } }

    assert_response :unprocessable_content
    assert_select "#error_explanation"
    assert_equal "sleep-and-reaction", articles(:published).reload.slug
  end

  test "translation of another article cannot be edited through this article" do
    sign_in_as_admin users(:admin)
    foreign = article_translations(:news_item_en)

    patch admin_article_url(articles(:published)), params: { article: { translations_attributes: {
      "0" => { id: foreign.id, locale: "en", title: "Stolen", body: "Stolen" }
    } } }

    assert_response :not_found
    assert_equal "First news", foreign.reload.title
  end

  test "an existing translation cannot be moved to an unknown language" do
    sign_in_as_admin users(:admin)
    english = article_translations(:english_only_en)

    patch admin_article_url(articles(:english_only)), params: { article: { translations_attributes: {
      "0" => { id: english.id, locale: "xx", title: "Only in English", body: "No translation yet." }
    } } }

    assert_response :unprocessable_content
    assert_equal "en", english.reload.locale
  end

  # --- destroy ---

  test "admin deletes article with translations" do
    sign_in_as_admin users(:admin)
    article = articles(:published)

    assert_difference("Article.count", -1) do
      assert_difference("ArticleTranslation.count", -2) do
        delete admin_article_url(article)
      end
    end

    assert_redirected_to admin_articles_url
    assert_equal I18n.t("admin.articles.destroyed"), flash[:notice]
  end

  # --- safety of the saved text ---

  test "script in the body saved by admin does not appear raw on the public page" do
    sign_in_as_admin users(:admin)
    body = "Hello <script>alert('xss-marker')</script>\n\n[bad](javascript:alert('xss-marker'))\n\n<img src=x onerror=alert('xss-marker')>"

    post admin_articles_url, params: article_params(slug: "evil", publish: "1", en: { title: "Evil", body: body })
    get article_path("evil")

    assert_response :success
    assert_select "article script", 0
    assert_select "article [onerror]", 0
    assert_select "article a[href^=javascript]", 0
    assert_no_match(/<script>alert/, response.body)
  end

  test "script in the title is escaped on the form" do
    sign_in_as_admin users(:admin)
    post admin_articles_url, params: article_params(slug: "tagged", en: { title: "<script>alert(1)</script>", body: "Body" })

    get edit_admin_article_url(Article.find_by!(slug: "tagged"))

    assert_no_match(%r{<script>alert\(1\)</script>}, response.body)
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end
end
