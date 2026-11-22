Rails.application.routes.draw do
  # Liveness check, outside the language prefix.
  get "up" => "rails/health#show", as: :rails_health_check

  # "/" reads Accept-Language once and redirects to /<language>.
  root to: "root#show"

  # Every page lives under a language prefix; unknown languages are 404.
  scope "/:locale", locale: /#{I18n.available_locales.join('|')}/ do
    get "/", to: redirect { |params, _request| "/#{params[:locale]}/games" }, as: :localized_root

    resource :session
    resources :registrations, only: [ :new, :create ]
    resources :passwords, param: :token

    resources :users, only: [ :show, :edit, :update ]

    namespace :admin do
      resources :users
    end

    resources :games, only: [ :index, :show ] do
      resources :game_sessions, only: [ :create ] do
        member do
          get "play"
          post "submit_result"
        end
      end
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
