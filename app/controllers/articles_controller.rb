# Public lists and pages of articles and news. The texts of the interface live
# in config/locales/articles.*.yml, the texts of the articles in the database.
class ArticlesController < ApplicationController
  allow_unauthenticated_access
  # The header shows the signed in user even on a public page.
  before_action :resume_session

  def index
    kind = params[:kind].presence || "article"
    # The kind is compared with a fixed list and never used to build code or SQL.
    raise ActiveRecord::RecordNotFound unless Article::KINDS.include?(kind)

    @kind = Article::KINDS.find { |known| known == kind }
    @articles = Article.published.where(kind: @kind).includes(:translations).order(published_at: :desc)
  end

  def show
    @article = Article.published.find_by!(slug: params[:slug])
    @translation = @article.translation_for(I18n.locale)
    @fallback = @translation.locale != I18n.locale.to_s
  end
end
