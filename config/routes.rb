Rails.application.routes.draw do
  mount_devise_token_auth_for 'LoginCredential', at: '/api/auth'
  scope :api do
    scope :v1 do
      resources :identities, :only=>[:index, :show]
    end
  end

end
