Rails.application.routes.draw do
  mount_devise_token_auth_for 'LoginCredential', at: '/api/auth'
  namespace :api do
    namespace :v1 do
      resources :identities, :only=>[:index, :show]
      resources :pools
    end
  end

end
