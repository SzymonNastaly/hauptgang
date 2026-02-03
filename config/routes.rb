Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :session, only: [ :create, :destroy ]
      resources :recipes, only: [ :index, :show, :destroy ] do
        resource :favorite, only: [ :update, :destroy ]
        collection do
          post :import
          post :extract_from_text
        end
      end
    end
  end

  resources :recipes do
    member do
      patch :toggle_favorite
    end
    collection do
      get "new/form", to: "recipes#new_form", as: :new_form
      get "new/import", to: "recipes#new_import", as: :new_import
      post "import", to: "recipes#import", as: :import
    end
  end
  root to: redirect("/recipes")
  resource :session
  resources :passwords, param: :token

  resource :registration, only: [ :new, :create ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
