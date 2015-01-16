Rails.application.routes.draw do
  mount_devise_token_auth_for 'LoginCredential', at: '/api/auth'
end
