module Bindery
  class SeedDataImporter
    include Singleton

    def seed_login_credential
      if seed_identity.login_credential
        lc = seed_identity.login_credential
      else
        lc = LoginCredential.create(provider:'email',email:'seedcurator@databindery.com',password:'seedcurator', identities:[seed_identity])
        lc.confirm!
        lc
      end
    end

    def seed_identity
      @seed_identity ||= Identity.find_or_create_by(name:"DataBindery Seed Curator", short_name:"bindery_seed_curator")
    end

    def seed_pool
      @seed_pool = Pool.find_or_create_by(name:"Pullahari RDI Shrine Images", short_name:"pullahari_rdi_shrine_images", owner:seed_login_credential.identities.first, description:"Images from the Rigpe Dorje Institute Shrine Hall at Pullahari Monastery in Kathmandu, Nepal.")
    end

    def import_data(basepath_for_json="seeds/pullahari_rdi_images", pool=seed_pool)
      importer = Bindery::PoolImporter.new
      importer.import_from(basepath_for_json, seed_identity, pool:pool)
    end

  end
end
