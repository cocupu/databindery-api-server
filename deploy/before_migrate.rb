deploy_path = node['deploy']['databindery_api_server']['deploy_to']
local_templates_path = "#{release_path}/deploy/templates"

#
# Elasticsearch
# Generate elasticsearch.yml manually Rather than relying on OpsWorks to automatically generate it

template "#{deploy_path}/shared/config/elasticsearch.yml" do
  local  true
  source "#{local_templates_path}/elasticsearch.yml.erb"
  owner  'deploy'
  group  'www-data'
  mode   '644'
  action :create
  variables({
                :url =>      node['deploy']['databindery_api_server']['elasticsearch']['host']
            })
end
# symlink to the shared elasticsearch.yml we just generated
link "#{release_path}/config/elasticsearch.yml" do
  to     "#{deploy_path}/shared/config/elasticsearch.yml"
  owner  'deploy'
  group  'www-data'
  action :create
end

#
# S3
# Generate aws.yml

template "#{deploy_path}/shared/config/aws.yml" do
  local  true
  source "#{local_templates_path}/aws.yml.erb"
  owner  'deploy'
  group  'www-data'
  mode   '644'
  action :create
  variables({
                :access_key_id => node['deploy']['databindery_api_server']['aws']['access_key_id'],
                :secret_access_key => node['deploy']['databindery_api_server']['aws']['secret_access_key']
            })
end
# symlink to the shared aws.yml we just generated
link "#{release_path}/config/aws.yml" do
  to     "#{deploy_path}/shared/config/aws.yml"
  owner  'deploy'
  group  'www-data'
  action :create
end

#
# Swagger Docs
# Generate swagger docs

execute "rake swagger:docs" do
  command       "bundle exec rake swagger:docs"
  cwd           release_path
  user          'deploy'
  group         'www-data'
  # environment(  { 'RAILS_ENV' => node[:deploy]['databindery_api_server'][:rails_env] } )
  environment(  { 'RAILS_ENV' => 'production' } )
end