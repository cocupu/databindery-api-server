desc 'Reindex all objects into solr'
task :reindex => :environment do
  # Drop all the models in solr
  Bindery.solr.delete_by_query '*:*'

  Model.find(:all).each {|m| m.index}
  Bindery.solr.commit
end

task :index => :environment do
  Model.find(:all).each {|m| m.index}
  Bindery.solr.commit
end

desc "Run ci"
task :ci do 
  puts "Updating Solr config"
  puts %x[rails g cocupu:solr_conf -f]
  
  require 'jettywrapper'
  jetty_params = Jettywrapper.load_config.merge({:jetty_home => File.join(Rails.root , 'jetty'), :startup_wait=>30 })
  
  puts "Starting Jetty"
  error = nil
  error = Jettywrapper.wrap(jetty_params) do
      Rake::Task['spec'].invoke
  end
  raise "test failures: #{error}" if error
end

namespace :bindery do
  desc "Import seed data"
  task :seed  => :environment do
    # Bindery::SeedDataImporter.instance.import_data("seeds.json", Model.file_entity, Bindery::SeedDataImporter.instance.seed_pool)
    pool = Pool.find_or_create_by(short_name:"seeds2", owner: Bindery::SeedDataImporter.instance.seed_identity)
    Bindery::SeedDataImporter.instance.import_data("seeds.json", Model.file_entity, pool)
  end

  desc "Harvest seed data from S3 (slow)"
  task :seed_from_s3 => :environment do
    Bindery::S3BucketImporter.instace.import_bucket("5f496210-5ee3-0132-962e-12313819959a", Bindery::SeedDataImporter.instance.seed_pool)
  end
end

