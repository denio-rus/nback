require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  def build(attributes = {})
    Article.new({
      slug: "new-article", kind: "article",
      translations_attributes: [ { locale: "en", title: "Title", body: "Body" } ]
    }.merge(attributes))
  end

  test "a valid article" do
    assert build.valid?
  end

  test "slug format" do
    %w[a brand-new a1-b2].each { |slug| assert build(slug: slug).valid?, slug }
    [ "", "Upper", "with space", "under_score", "../etc", "a\nb" ].each do |slug|
      assert_not build(slug: slug).valid?, slug.inspect
    end
  end

  test "slug is unique" do
    assert_not build(slug: articles(:published).slug).valid?
  end

  test "kind must be article or news" do
    %w[article news].each { |kind| assert build(kind: kind).valid?, kind }
    assert_not build(kind: "post").valid?
    assert_not build(kind: nil).valid?
  end

  test "requires default locale translation" do
    article = build(translations_attributes: [ { locale: "ru", title: "Заголовок", body: "Текст" } ])

    assert_not article.valid?
    assert_includes article.errors.attribute_names, :translations
  end

  test "blank translation section is not created" do
    article = build(translations_attributes: [
      { locale: "en", title: "Title", body: "Body" },
      { locale: "ru", title: "", body: "" }
    ])

    assert article.save
    assert_equal [ "en" ], article.translations.map(&:locale)
  end

  test "published scope hides drafts and future dates" do
    published = Article.published

    assert_includes published, articles(:published)
    assert_includes published, articles(:news_item)
    assert_not_includes published, articles(:draft)
    assert_not_includes published, articles(:scheduled)
  end

  test "translation_for returns the translation for the language" do
    assert_equal "Сон и время реакции", articles(:published).translation_for(:ru).title
  end

  test "translation_for falls back to en" do
    assert_equal "en", articles(:news_item).translation_for(:ru).locale
    assert_equal "en", articles(:news_item).translation_for("xx").locale
  end

  test "destroying an article removes its translations" do
    article = articles(:published)

    assert_difference -> { ArticleTranslation.count }, -2 do
      article.destroy
    end
  end

  test "translation locale must be an available language" do
    translation = ArticleTranslation.new(article: articles(:draft), locale: "xx", title: "T", body: "B")

    assert_not translation.valid?
    assert translation.tap { |t| t.locale = "ru" }.valid?
  end

  test "translation needs title and body" do
    translation = ArticleTranslation.new(article: articles(:draft), locale: "ru", title: "", body: "")

    assert_not translation.valid?
    assert_includes translation.errors.attribute_names, :title
    assert_includes translation.errors.attribute_names, :body
  end

  test "one translation per language" do
    translation = ArticleTranslation.new(article: articles(:published), locale: "en", title: "T", body: "B")

    assert_not translation.valid?
  end
end
