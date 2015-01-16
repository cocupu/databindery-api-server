class LoginCredential < ActiveRecord::Base
  include DeviseTokenAuth::Concerns::User
end
