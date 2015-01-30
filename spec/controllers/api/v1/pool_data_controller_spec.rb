require 'rails_helper'

describe Api::V1::PoolDataController do
  let(:identity) { FactoryGirl.create :identity }
  let(:my_pool) { FactoryGirl.create :pool, owner:identity }
  let(:other_pool) { FactoryGirl.create :pool, owner:identity }
  let(:not_my_pool) { FactoryGirl.create :pool, owner:FactoryGirl.create(:identity) }
  let(:my_model) { FactoryGirl.create(:model, pool:my_pool) }
  let(:my_model_different_pool) { FactoryGirl.create(:model, pool: other_pool) }
  #let(:not_my_model) { FactoryGirl.create(:model) }

  describe "index" do
    describe "when not logged on" do
      it "should require authentication" do
        get :index, pool_id: my_pool, identity_id: identity.short_name
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
      end
      describe "requesting a pool I don't have access to" do
        it "should forbid action" do
          get :index, :pool_id=>not_my_pool.short_name
          expect(response).to respond_forbidden
        end
      end
      describe "requesting a pool I have read access for" do
        it "should be successful" do
          AccessControl.create!(:pool=>other_pool, :identity=>identity, :access=>'READ')
          get :index, :pool_id=>other_pool
          response.should be_success
        end
        describe "grid view" do
          it "should filter to one model" do
            my_model_different_pool # Trigger creation of this model before running this test
            get :index, :pool_id=>other_pool, view:"grid"
            subject.solr_search_params[:fq].should include("model:#{my_model_different_pool.id}")
          end
          it "should support choosing model" do
            get :index, :pool_id=>other_pool, model_id: my_model_different_pool.id, view:"grid"
            subject.solr_search_params[:fq].should include("model:#{my_model_different_pool.id}")
          end
        end
      end
      describe "requesting a pool I own" do
        it "should be successful" do
          get :index, :pool_id=>my_pool
          response.should be_success
        end
        it "should apply filters and facets from exhibit" do
          exhibit_with_filters = FactoryGirl.build(:exhibit, pool: my_pool, filters_attributes: [field:FactoryGirl.create(:subject_field), operator:"+", values:["test", "barf"]])
          exhibit_with_filters.save!
          get :index, :pool_id=>my_pool, :perspective=>exhibit_with_filters.id
          subject.exhibit.should == exhibit_with_filters
          subject.solr_search_params[:fq].should include('subject_ssi:"test" OR subject_ssi:"barf"')
        end
      end
    end
    describe "json query API" do
      let(:name_field) { FactoryGirl.create(:field, code:"name", name:"Name") }
      let(:year_field) { FactoryGirl.create(:field, code:"year", name:"Year") }
      let(:make_field) { FactoryGirl.create(:field, code:"make", name:"Make", uri:"/automotive/model/make") }
      let(:auto_model) { FactoryGirl.create(:model, pool: other_pool, name:"/automotive/model", label_field: name_field, fields: [name_field, year_field, make_field]) }
      before do
        sign_in identity.login_credential
        AccessControl.create!(:pool=>other_pool, :identity=>identity, :access=>'READ')
        @node1 = Node.create!(model:auto_model, pool: other_pool, data:auto_model.convert_data_field_codes_to_id_strings("year"=>"2009", "make"=>"/en/ford", "name"=>"Ford Taurus"))
        @node2 = Node.create!(model:auto_model, pool: other_pool, data:auto_model.convert_data_field_codes_to_id_strings("year"=>"2011", "make"=>"/en/ford", "name"=>"Ford Taurus"))
        @node3 = Node.create!(model:auto_model, pool: other_pool, data:auto_model.convert_data_field_codes_to_id_strings("year"=>"2013", "make"=>"barf", "name"=>"Puke"))
        @node4 = Node.create!(model:auto_model, pool: other_pool, data:auto_model.convert_data_field_codes_to_id_strings("year"=>"2012", "make"=>"barf", "name"=>"Upchuck"))
      end
      it "should provide blacklight-ish json response by default" do
        get :index, :pool_id=>other_pool, :format=>:json
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        json["responseHeader"]["params"].keys.should include{"facet"}
        json["responseHeader"]["params"].keys.should include{"rows"}
        json["response"]["numFound"].should == 4
        pids = json["docs"].map {|doc| doc["id"]}
        [@node1, @node2, @node3, @node4].each {|n| pids.should include(n.persistent_id)}
      end
      it "should support nodesOnly json responses" do
        get :index, :pool_id=>other_pool, :format=>:json, "nodesOnly"=>"true"
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|doc| doc["id"]}
        [@node1, @node2, @node3, @node4].each {|n| pids.should include(n.persistent_id)}
      end
      it "should allow faceted queries" do
        get :index, :pool_id=>other_pool, :format=>:json, "nodesOnly"=>"true", "f" => {Node.solr_name("make", type: "facet") => "barf"}
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|doc| doc["id"]}
        [@node3, @node4].each {|n| pids.should include(n.persistent_id)}
        [@node1, @node2].each {|n| pids.should_not include(n.persistent_id)}
      end
      it "should allow faceted queries by field id" do
        get :index, :pool_id=>other_pool, :format=>:json, "nodesOnly"=>"true", "facet_fields" => {make_field.to_param => "barf"}
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|doc| doc["id"]}
        [@node3, @node4].each {|n| pids.should include(n.persistent_id)}
        [@node1, @node2].each {|n| pids.should_not include(n.persistent_id)}
      end
      it "should allow sorting by field id" do
        get :index, :pool_id=>other_pool, :format=>:json, "nodesOnly"=>"true", "sort_fields" => [year_field.to_param => "desc"]
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|doc| doc["id"]}
        expect(pids).to eq [@node3.persistent_id, @node4.persistent_id, @node2.persistent_id, @node1.persistent_id]
      end
      it "should allow sorting by field id from json array" do
        get :index, :pool_id=>other_pool, :format=>:json, "nodesOnly"=>"true", "sort_fields" => "[{\"#{name_field.to_param}\":\"asc\"},{\"#{year_field.to_param}\":\"desc\"}]"
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|doc| doc["id"]}
        expect(pids).to eq [@node2.persistent_id, @node1.persistent_id, @node3.persistent_id, @node4.persistent_id]
      end
    end
  end
  
  describe "show" do
    before do
      @node = FactoryGirl.create(:node, pool: my_pool)
    end
    describe "when signed in" do
      before do
        sign_in identity.login_credential
      end
      it "should be success" do
        get :show, id: @node.persistent_id, :pool_id=>my_pool
        response.should be_successful
      end
    end
    describe "when not signed in" do
      describe "show" do
        it "should not be successful" do
          get :show, id: @node.persistent_id,  :pool_id=>my_pool
          expect(response).to respond_unauthorized
        end
        it "should return 401 to json API" do
          get :show, id: @node.persistent_id,  :pool_id=>my_pool, :format=>:json
          response.code.should == "401"     
        end
      end
    end
  end
  
  describe "overview" do
    describe "when not logged on" do
      it "should require authentication" do
        get :overview, pool_id: my_pool
        expect(response).to respond_unauthorized
      end
    end
    describe "when logged on" do
      before do
        sign_in identity.login_credential
        my_model = FactoryGirl.create(:model, pool:my_pool)
        my_model_different_pool = FactoryGirl.create(:model, pool: other_pool)
        @not_my_model = FactoryGirl.create(:model)
      end
      describe "requesting a pool I don't own" do
        it "should forbid access" do
          get :overview, :pool_id=>not_my_pool
          expect(response).to respond_forbidden
        end
      end
      describe "requesting a pool I own" do
        it "should be successful" do
          get :overview, :pool_id=>my_pool, :format=>:json
          expect(response).to be_success
        end
      end
      describe "requesting a pool I can edit" do
        before do
          @other_identity = FactoryGirl.create(:identity)
          AccessControl.create!(:pool=>my_pool, :identity=>@other_identity, :access=>'EDIT')
        end
        it "should be successful when rendering json" do
          get :overview, :pool_id=>my_pool, :format=>:json
          expect(response).to  be_successful
          json = JSON.parse(response.body)
          json['id'].should == my_pool.id
          json['models'].should == JSON.parse(my_pool.models.to_json)
          json['perspectives'].should == my_pool.exhibits.as_json
          json['facets'].should == {"model_name"=>[], "description_ssi"=>[]}
          json["numFound"].should == 0
        end
      end
    end
  end
  
end