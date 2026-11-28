# Admin CRUD for articles and news. The text of each language is a nested
# ArticleTranslation; an empty language section is dropped by the model.
class Admin::ArticlesController < Admin::ApplicationController
  before_action :set_article, only: %i[ edit update destroy ]

  def index
    @articles = Article.includes(:translations).order(published_at: :desc, id: :desc)
  end

  def new
    @article = Article.new(kind: Article::KINDS.first)
    prepare_form
  end

  def create
    @article = Article.new(article_params)

    if @article.save
      redirect_to admin_articles_path, notice: t("admin.articles.created"), status: :see_other
    else
      prepare_form
      render :new, status: :unprocessable_content
    end
  end

  def edit
    prepare_form
  end

  def update
    if @article.update(article_params)
      redirect_to admin_articles_path, notice: t("admin.articles.updated"), status: :see_other
    else
      prepare_form
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @article.destroy!
    redirect_to admin_articles_path, notice: t("admin.articles.destroyed"), status: :see_other
  end

  private

  def set_article
    @article = Article.find(params.expect(:id))
  end

  # The kind and the locale are checked by the model validations, not here.
  def article_params
    params.expect(article: [ :slug, :kind, :publish, translations_attributes: [ [ :id, :locale, :title, :body ] ] ])
  end

  # The form shows one section per language, in the order of available_locales.
  # Languages without a saved or submitted text get an empty, unsaved section.
  def prepare_form
    by_locale = @article.translations.index_by(&:locale)
    @translations = I18n.available_locales.map do |locale|
      by_locale[locale.to_s] || @article.translations.build(locale: locale.to_s)
    end
  end
end
