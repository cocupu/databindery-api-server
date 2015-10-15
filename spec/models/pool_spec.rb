require 'rails_helper'

describe Pool do
  let(:pool)  { Pool.new }
  subject     { pool }

  it "belongs to an identity" do
    subject.short_name = 'short_name'
    subject.should_not be_valid
    subject.errors.full_messages.should == ["Owner can't be blank"]
    subject.owner = Identity.create
    expect(subject).to be_valid
  end
  
  it "creates a persistent_id when created" do
    subject.persistent_id.should be_nil
    # Make the pool valid to save...
      subject.short_name = 'short_name'
      subject.owner = FactoryGirl.create(:identity)
    subject.save!
    expect(subject.persistent_id).to_not be_nil
  end
  
  describe "#for_identity" do
    let(:pool)  { FactoryGirl.create(:pool) }
    subject { Pool.for_identity(target_identity) }

    describe "for a pool owner" do
      let(:target_identity) { pool.owner }
      it "returns all the pools" do
        expect(subject).to eq [pool]
      end
    end
    describe "for a non-pool owner" do
      let(:non_owner) { FactoryGirl.create(:identity) }
      let(:target_identity) { non_owner }
      describe "when the user doesn't have read or edit access" do
        it "returns an empty set" do
          expect(subject).to eq []
        end
      end
      describe "when the user has read-access on the pool" do
        before do
          AccessControl.create!(identity: non_owner, pool: pool, access: 'READ')
        end
        it "returns all the pools" do
          expect(subject).to eq [pool]
        end
      end
      describe "when the user has edit-access on the pool" do
        before do
          AccessControl.create!(identity: non_owner, pool: pool, access: 'EDIT')
        end
        it "returns all the pools" do
          expect(subject).to eq [pool]
        end
      end
    end
  end
  
  describe "perspectives" do
    let(:exhibit1) { FactoryGirl.create(:exhibit) }
    let(:exhibit2) { FactoryGirl.create(:exhibit) }
    subject { pool.perspectives }
    before do
      pool.exhibits = [exhibit1, exhibit2]
      pool.save
    end
    it "returns the exhibits" do
      expect(subject).to eq [pool.generated_default_perspective, exhibit1, exhibit2]
    end
    
    describe "default perspective" do
      subject { pool.default_perspective }
      describe "when a default has not been explicitly set" do
        it "returns the generated default perspective for the pool" do
          expect(subject).to eq pool.generated_default_perspective
        end
      end
      describe "when a default has been explicitly set" do
        before do
          pool.chosen_default_perspective = exhibit1
        end
        it "returns the one that has been explicitly set" do
          expect(subject).to eq exhibit1
        end
      end
    end
    describe "generated_default_perspective" do
      subject { pool.generated_default_perspective }
      let(:model1) do
        model1 = FactoryGirl.create(:model, pool: pool)
        model1.fields << Field.create(:code=>'one', :name=>'One', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
        model1.fields << Field.create(:code=>'two', :name=>'Two', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
        model1.association_fields << FactoryGirl.create(:association, name: 'authors', label: "Authors", multivalue:true, references: 39)
        model1.save
        model1
      end
      before do
        pool.models << model1
      end
      it "generates an Exhibit whose facet and index fields are all fields from all Models" do
        expect(subject).to be_kind_of Exhibit
        expect(subject.facets).to eq pool.all_fields
        expect(subject.index_fields).to eq pool.all_fields
      end
      it "does not merge duplicate fields" do
        pool.stub(:all_fields).and_return([{"code"=>"collection_location", "name"=>"Collection Location"}, {"code"=>"date_from", "name"=>"Date from"}, {"name"=>"Date from", "type"=>"date", "uri"=>"", "code"=>"date_from"}, {"code"=>"date_to", "name"=>"Date to"}, {"name"=>"Date to", "type"=>"date", "uri"=>"", "code"=>"date_to"}])
        e = pool.generated_default_perspective
        expect(e.facets).to eq pool.all_fields
        expect(e.index_fields).to eq pool.all_fields
      end
    end
  end
  
  describe "all_associations" do
    let(:a1) {FactoryGirl.create(:association, code: "talk", name: "Talk", references: 38)}
    let(:a2) {FactoryGirl.create(:association, code: "authors", name: "Authors", references: 39)}
    let(:a3) {FactoryGirl.create(:association, code: "tracks", name: "Tracks", references: 40)}
    let(:a4) {FactoryGirl.create(:association, code: "members", name: "Members", references: 41)}
    let(:a5) {FactoryGirl.create(:association, code: "authors", name: "Authors", references: 39)}
    let(:model1) {FactoryGirl.create(:model, association_fields:[a1, a2])}
    let(:model2) {FactoryGirl.create(:model, association_fields:[a3, a4, a5])}

    before do
      pool.models << model1
      pool.models << model2
    end
    subject { pool.all_associations }
    it "returns all Model associations in the pool" do
      expect(subject).to eq [a1, a2, a3, a4, a5]
    end
    it "supports filtering for uniqueness based on association code" do
      expect(pool.all_associations).to eq [a1, a2, a3, a4, a5]
      expect(pool.all_associations(unique: true)).to eq [a1, a2, a3, a4]
    end
  end

  it "has many audience categories" do
    aud = AudienceCategory.new
    pool.audience_categories << aud
    expect(pool.audience_categories).to eq [aud]
  end

  describe "audiences" do
    let(:identity) { FactoryGirl.create :identity }
    let(:subject_field) {FactoryGirl.create(:subject_field)}
    let(:location_field) {FactoryGirl.create(:location_field)}
    let(:cat1) { FactoryGirl.create :audience_category, pool:pool }
    let(:cat2) { FactoryGirl.create :audience_category }
    let(:aud1) { FactoryGirl.create :audience, audience_category:cat1, name:"Audience 1" }
    let(:aud2) { FactoryGirl.create :audience, audience_category:cat1, name:"Audience 2" }
    let(:aud3) { FactoryGirl.create :audience, audience_category:cat2, name:"Audience 3" }

    before do
      aud2.members = []
      aud1.members << identity
      aud3.members << identity
      pool.audience_categories << cat1 << cat2
    end
    describe "audiences_for_identity" do
      subject { pool.audiences_for_identity(identity) }
      it "should return all the applicable audiences for the given identity" do
        expect(subject).to eq [aud1, aud3]
      end
    end
    describe "apply_query_params_for_identity" do
      it "aliases to apply_elasticsearch_params_for_identity" do
        query_builder = Bindery::Persistence::ElasticSearch::Query::QueryBuilder.new
        expect(pool).to receive(:apply_elasticsearch_params_for_identity).with(identity, query_builder, {})
        pool.apply_query_params_for_identity(identity, query_builder, {})
      end
    end
  end
  
  describe "default_bucket_id" do
    it "defaults to the the pool's persistent id" do
      expect(pool).to receive(:persistent_id).and_return("thepid")
      expect(pool.default_bucket_id).to eq "thepid"
    end
  end
  
  describe "bucket" do
    subject { pool.bucket }
    it "returns the pool's bucket from s3 connection" do
      expect(pool.default_file_store).to receive(:bucket).and_return("the bucket")
      expect(subject).to eq "the bucket"
    end
  end
  
  describe "ensure_bucket_initialized" do
    subject { pool.ensure_bucket_initialized }
    it "ensures that the pool's bucket exists on s3 connection" do
      expect(pool.default_file_store).to receive(:ensure_bucket_initialized).and_return("the bucket")
      expect(subject).to eq "the bucket"
    end
  end
  
  describe "short_name" do
    before do
      pool.owner = Identity.create
    end
    it "accepts letters, numbers, underscore and hyphen" do
      pool.short_name="short-name_123"
      expect(pool).to be_valid
    end
    it "does not accept spaces or symbols" do
      pool.short_name="short name_123"
      expect(pool).to_not be_valid
      %w[. & * ) / = # ; : \\ @ \[ ?].each do |sym|
        pool.short_name="short#{sym}name_123"
        expect(pool).to_not be_valid
      end
    end
    it "gets downcased" do
      pool.short_name="Short-Name"
      expect(pool.short_name).to eq 'short-name'
    end
  end

  describe "all_fields" do
    let(:pool) { FactoryGirl.create(:generic_pool) }
    let(:model1) do
      model1 = FactoryGirl.create(:model, pool: pool)
      model1.fields << Field.create(:code=>'one', :name=>'One', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
      model1.fields << Field.create(:code=>'two', :name=>'Two', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
      model1.save
      model1
    end
    let(:model2) do
      model2 = FactoryGirl.create(:model, pool: pool)
      model2.fields << Field.create(:code=>'one', :name=>'One', :type=>'TextField', :uri=>'dc:name', :multivalue=>true)
      model2.fields << Field.create(:code=>'three', :name=>'Three', :type=>'TextField', :uri=>'dc:name', :multivalue=>false)
      model2.save
      model2
    end
    before do
      pool.models << model1
      pool.models << model2
    end
    let(:all_fields) { pool.all_fields }
    let(:codes)   { subject.map {|f| f.code } }
    subject       { all_fields }
    it "returns all fields from all models including FileEntity, removing duplicates" do
      ["model_name","description","one","two","three"].each {|code| expect(codes).to include(code)}
      Model.file_entity.fields.each {|file_entity_field| expect(all_fields).to include(file_entity_field)}
    end
  end

end
