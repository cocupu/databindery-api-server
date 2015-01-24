Rails.application.routes.draw do
  mount_devise_token_auth_for 'LoginCredential', at: '/api/auth'
  namespace :api do
    namespace :v1 do
      resources :identities, :only=>[:index, :show]
      resources :models
      resources :fields
      resources :pools do
        resources :nodes, :only=>[:create, :update, :show, :index, :destroy] do
          collection do
            get 'search'
            post 'find_or_create'
            post 'import'
          end
          match 'files' => 'nodes#attach_file', :via=>:post
        end
        resources :models
      end
    end
  end

end
