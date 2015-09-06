Rails.application.routes.draw do
  mount_devise_token_auth_for 'LoginCredential', at: '/api/auth'
  namespace :api do
    namespace :v1 do
      resources :identities, :only=>[:index, :show]
      resources :models, except:[:new,:edit]
      resources :fields, except:[:new,:edit]
      resources :pools, except:[:new,:edit] do
        resources :nodes, :only=>[:create, :update, :show, :index, :destroy] do
          member do
            get 'history'
          end
          collection do
            get 'search'
            post 'find_or_create'
            post 'import'
          end
          match 'files' => 'nodes#attach_file', :via=>:post
        end
        resources :models, except:[:new,:edit]
        resources :fields, except:[:new,:edit]
        resources :audience_categories, except:[:new,:edit] do
          resources :audiences, except:[:new,:edit]
        end
        resources :file_entities, except:[:new,:edit] do
          collection do
            get "s3_upload_info"
          end
        end
        resources :mapping_templates, except:[:new,:edit]
        resources :spawn_jobs, except:[:new,:edit]
        resources :spreadsheets, except:[:new,:edit]

        # Pool Searches (/data)
        resources :data, to: 'pool_data', except:[:new,:edit] do
          collection do
            get 'facet/:id', to: 'pool_data#facet', :as => :pool_data_facet
            get 'overview', to: 'pool_data#overview', :as => :pool_data_overview
          end
        end

        member do
          get '_search', to: 'elastic_search_proxy#index'
          post '_search', to: 'elastic_search_proxy#index'
        end


        get 'exhibits/:exhibit_id' => 'exhibit_data#index', :as => 'exhibit_data'
        get 'exhibits/:exhibit_id/facet/:id' => 'exhibit_data#facet', :as => :exhibit_facet
        resources :exhibits, except:[:show,:new,:edit]

        # resources :exhibits, :only=>[] do
        #   resources :solr_document, :path => '', :controller => 'exhibit_data', :only => [:show, :update]
        # end

      end
    end
  end

end
