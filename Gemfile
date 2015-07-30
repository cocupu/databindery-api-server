source 'https://rubygems.org'


gem 'rails', '4.1.8'
gem 'rails-api'
gem 'unicorn'

# Database
# gem 'sqlite3'
gem 'pg'
gem 'foreigner'
gem 'activerecord-import'

# Authentication & Security
gem "devise"
gem "omniauth"
gem 'devise_token_auth'
gem 'rack-cors', :require => 'rack/cors'
gem "cancan"

# Search
gem "rsolr"
gem "solrizer"
gem "blacklight"

gem "elasticsearch"

# API & Documentation
gem "swagger-docs", "~> 0.1.9"

# Asynchronous Workers
gem "sidekiq"
gem "resque", "=1.26.pre.0"
# Need the github version of resque-status to avoid bug where mocha was declared as runtime dependency
gem 'resque-status', github:'quirkey/resque-status', ref: '66f3f35f945859c80a56b4b573325a79b556f243'
gem 'resque-pool'
gem 'carrot'

# External Services
gem "aws-sdk"
gem 'aws-ses', '~> 0.4.4', require: 'aws/ses'

# Data Import and Manipulations
gem 'roo', "~> 1.12.2"

# Misc
gem 'uuid'
gem 'jbuilder'
gem 'jsonify'

# Development & Testing
gem 'spring', :group => :development

group :test, :development do
  gem "rspec-rails"
  gem "factory_girl_rails"
  gem "byebug"
  gem "elasticsearch-extensions"
end



# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano', :group => :development

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'
