

# DataBindery API Server

This is the main DataBindery code base.

# Dependencies

* Elasticsearch 1.4.2
* Postgresql
* Redis
* Ruby

# TL;DR

## Download and Run Tests
```
git clone git@github.com/cocupu/databindery-api-server
cd databindery-api-server
bundle install
rake db:create
rake db:migrate
rake elastic_search:testcluster:start
rake spec
rake elastic_search:testcluster:stop
rake swagger:docs
open http://localhost:3000/api-docs
```

## Run the Server
To run the server locally, start elasticsearch (assuming you have elasticsearch installed) and sidekiq
```
elasticsearch --config=./elasticsearch-dev.yml
bundle exec sidekiq
rails s
```

## Import Sample Data
```
rake bindery:seed
```

## Runing Elasticsearch

If you have elasticsearch installed (ie. via `brew install elasticsearch`) you can run a development cluster using the included elasticsearch-dev.yml file
```
elasticsearch --config=./elasticsearch-dev.yml
```

# Generated API Documentation
The API is self-documenting using the [swagger-ui](https://github.com/richhollis/swagger-docs) rails gem.  These docs must be re-built whenever the API changes.

## Building the Swagger JSON Files

If you're building the docs for the production site, pass the RAILS_ENV
`rake swagger:docs RAILS_ENV='production'

Otherwise, for local use in development mode, you can simply call `rake swagger:docs`

This will generate the [swagger](https://github.com/swagger-api/swagger-spec) json files in public/api-docs

## Viewing the Docs

The code base includes a copy of [swagger-ui](https://github.com/swagger-api/swagger-ui) in public/api-docs.  This allows you to view an HTML version of the API documentation at http://localhost:3000/api-docs or (on production site) http://api.databindery.com/api-docs

