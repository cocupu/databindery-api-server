app_config = node[:deploy][:databindery_api_server]
deploy_path = app_config[:deploy_to]
local_templates_path = "#{release_path}/deploy/templates"

# Imitating #npm_install method from https://github.com/aws/opsworks-cookbooks/blob/b0b56ff404adea5ef6969a10d480b37b8fc4d7f5/opsworks_nodejs/libraries/nodejs_configuration.rb
if ::File.exists?("#{release_path}/package.json")
  npm_install_options = node[:opsworks_nodejs][:npm_install_options] ? node[:opsworks_nodejs][:npm_install_options] : 'install'
  Chef::Log.info("package.json detected. Running npm install.")
  Chef::Log.info(%x(sudo su #{app_config[:user]} -c 'cd #{release_path} && npm #{npm_install_options}'))
else
  Chef::Log.info("No package.json detected at #{release_path}/package.json. Skipping npm install.")
end


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