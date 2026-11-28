Rails.application.routes.draw do
  # Liveness check, outside the language prefix.
  get "up" => "rails/health#show", as: :rails_health_check

  # "/" reads Accept-Language once and redirects to /<language>.
  root to: "root#show"

  # Every page lives under a language prefix; unknown languages are 404.
  scope "/:locale", locale: /#{I18n.available_locales.join('|')}/ do
    get "/", to: redirect { |params, _request| "/#{params[:locale]}/games" }, as: :localized_root

    resource :session
    resources :registrations, only: [ :new, :create ] do
      get :check_mail, on: :collection
    end
    resources :email_confirmations, only: :show, param: :token
    resources :passwords, param: :token

    resources :users, only: [ :show, :edit, :update, :destroy ]

    namespace :admin do
      # No new/create: an account needs an email that only its owner can confirm.
      resources :users, except: [ :new, :create ]
      resources :feedback_messages, only: [ :index, :destroy ]
    end

    # The breakdown page of one finished play-through (owner only).
    resources :game_sessions, only: :show

    # "My trends": the charts of the signed in user, one page per game.
    resources :insights, only: [ :index, :show ]

    # Anonymous feedback: open to everyone, stores no author.
    resources :feedback_messages, only: [ :new, :create ]

    resources :games, only: [ :index, :show ] do
      resources :game_sessions, only: [ :new, :create ] do
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
