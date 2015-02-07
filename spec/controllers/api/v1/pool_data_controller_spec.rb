require 'rails_helper'

describe Api::V1::PoolDataController do
  let(:identity) { FactoryGirl.create :identity }
  let(:my_pool) { FactoryGirl.create :pool, owner:identity }
  let(:other_pool) { FactoryGirl.create :pool, owner:identity }
  let(:not_my_pool) { FactoryGirl.create :pool, owner:FactoryGirl.create(:identity) }
  let(:my_model) { FactoryGirl.create(:model, pool:my_pool) }
  let(:my_model_different_pool) { FactoryGirl.create(:model, pool: other_pool) }
  #let(:not_my_model) { FactoryGirl.create(:model) }
  let(:subject_field) { FactoryGirl.create(:subject_field) }
  let(:first_name_field) { FactoryGirl.create(:first_name_field) }
  let(:exhibit_with_filters) { FactoryGirl.create(:exhibit, pool: my_pool, index_fields:[subject_field, first_name_field], facets:[subject_field,first_name_field] ,filters_attributes: [field:subject_field, operator:"+", values:["test", "barf"]]) }

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
      end
      describe "requesting a pool I own" do
        it "should be successful" do
          get :index, :pool_id=>my_pool
          response.should be_success
        end
        it "supports querying" do
          get :index, :pool_id=>my_pool, :q=>'bazaar'
          expect(subject.query_builder.as_json["body"]["query"]).to eq({query_string:{query:"bazaar"}}.as_json)
        end
        it "supports string queries together with facet queries" do
          get :index, :pool_id=>my_pool, q:"Grand", f: {"location" => "Istanbul"}
          expect(subject.query_builder.as_json["body"]["query"]).to eq({bool:{must:[{query_string:{query:"Grand"}},{match:{"location"=>"Istanbul"}}]}}.as_json)
        end
        it "applies filters, facets and fields from exhibit" do
          get :index, :pool_id=>my_pool, :perspective=>exhibit_with_filters.id
          expect(controller.exhibit).to eq exhibit_with_filters
          expect(subject.query_builder.as_json["body"]["aggregations"]).to eq({"subject"=>{"terms"=>{"field"=>"subject"}}, "first_name"=>{"terms"=>{"field"=>"first_name"}}})
          expect(subject.query_builder.as_json["body"]["fields"]).to eq(["_id", "_bindery_pool", "_bindery_model", "subject","first_name"])
          expect(subject.query_builder.as_json["body"]["query"]["filtered"]["filter"]).to eq({bool:{should:[{query:{match:{"subject"=>"test"}}},{query:{match:{"subject"=>"barf"}}}]}}.as_json)
        end
      end
    end
    describe "(integration) json query API", sidekiq: :inline, elasticsearch:true do
      before(:all) do
        Sidekiq::Testing.inline! # Ensure that node Indexers are run in this before(:all) block
        @identity = FactoryGirl.create(:identity)
        @automotives_pool = FactoryGirl.create(:pool, owner:@identity)
        AccessControl.create!(:pool=>@automotives_pool, :identity=>@identity, :access=>'READ')
        @name_field = FactoryGirl.create(:field, code:"name", name:"Name")
        @year_field = FactoryGirl.create(:field, code:"year", name:"Year")
        @make_field = FactoryGirl.create(:field, code:"make", name:"Make", uri:"/automotive/model/make")
        @auto_model = FactoryGirl.create(:model, pool: @automotives_pool, name:"/automotive/model", label_field: @name_field, fields: [@name_field, @year_field, @make_field])
        @node1 = Node.create(model:@auto_model, pool: @automotives_pool, data:{"year"=>"2009", "make"=>"/en/ford", "name"=>"Ford Taurus"})
        @node2 = Node.create(model:@auto_model, pool: @automotives_pool, data:{"year"=>"2011", "make"=>"/en/ford", "name"=>"Ford Taurus"})
        @node3 = Node.create(model:@auto_model, pool: @automotives_pool, data:{"year"=>"2013", "make"=>"barf", "name"=>"Puke"})
        @node4 = Node.create(model:@auto_model, pool: @automotives_pool, data:{"year"=>"2012", "make"=>"barf", "name"=>"Upchuck"})
        sleep 1 # Wait for the nodes to be indexed
      end
      let(:identity) {@identity}
      let(:automotives_pool) {@automotives_pool}
      let(:name_field) { @name_field }
      let(:year_field) { @year_field }
      let(:make_field) { @make_field }
      let(:auto_model) { @auto_model }

      before(:each) do
        sign_in @identity.login_credential
      end
      it "should provide the elasticsearch json response by default" do
        get :index, :pool_id=>automotives_pool, :format=>:json
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        # expect(json["responseHeader"]["params"].keys).to include{"facet"}
        # expect(json["responseHeader"]["params"].keys).to include{"rows"}
        expect(json["hits"]["total"]).to eq 4
        puts json["hits"]["hits"].first
        expect(json["hits"]["hits"].first["_index"]).to include(automotives_pool.to_param)
        pids = json["hits"]["hits"].map {|doc| doc["_id"]}  # Note: these are elasticsearch documents, so the id is in "_id", not "id"
        [@node1, @node2, @node3, @node4].each {|n| pids.should include(n.persistent_id)}
      end
      it "supports simple querying" do
        get :index, :pool_id=>automotives_pool, q:"Ford", :format=>:json
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        # expect(subject.query_builder.query.as_json).to eq({multi_match:{query:"Ford", fields:["*"]}}.as_json)
        expect(json["hits"]["total"]).to eq 2
      end
      it "should support nodesOnly json responses" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true"
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
        [@node1, @node2, @node3, @node4].each {|n| pids.should include(n.persistent_id)}
      end
      it "should allow faceted queries" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", "f" => {Node.field_name_for_index("make", type: "facet") => "barf"}
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
        [@node3, @node4].each {|n| pids.should include(n.persistent_id)}
        [@node1, @node2].each {|n| pids.should_not include(n.persistent_id)}
      end
      it "allows faceted queries together with string queries" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", q:"Puke", f: {Node.field_name_for_index("make", type: "facet") => "barf"}
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        expect(json.count).to eq(1)
        pids = json.map {|node| node["id"]}
        [@node3].each {|n| pids.should include(n.persistent_id)}
        [@node1, @node2, @node4].each {|n| pids.should_not include(n.persistent_id)}
      end
      it "should allow faceted queries by field id" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", "facet_fields" => {make_field.id => "barf"}
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
        [@node3, @node4].each {|n| pids.should include(n.persistent_id)}
        [@node1, @node2].each {|n| pids.should_not include(n.persistent_id)}
      end
      it "allows sorting by field code" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", "sort" => [year_field.code => "desc"]
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
        expect(pids).to eq [@node3.persistent_id, @node4.persistent_id, @node2.persistent_id, @node1.persistent_id]
      end
      it "should allow sorting by field id" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", "sort_fields" => [year_field.id => "desc"]
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
        expect(pids).to eq [@node3.persistent_id, @node4.persistent_id, @node2.persistent_id, @node1.persistent_id]
      end
      it "should allow sorting by field id from json array" do
        get :index, :pool_id=>automotives_pool, :format=>:json, "nodesOnly"=>"true", "sort_fields" => "[{\"#{name_field.id}\":\"asc\"},{\"#{year_field.id}\":\"desc\"}]"
        expect(response).to  be_successful
        json = JSON.parse(response.body)
        pids = json.map {|node| node["id"]}
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
  
  # describe "overview" do
  #   describe "when not logged on" do
  #     it "should require authentication" do
  #       get :overview, pool_id: my_pool
  #       expect(response).to respond_unauthorized
  #     end
  #   end
  #   describe "when logged on" do
  #     before do
  #       sign_in identity.login_credential
  #       my_model = FactoryGirl.create(:model, pool:my_pool)
  #       my_model_different_pool = FactoryGirl.create(:model, pool: other_pool)
  #       @not_my_model = FactoryGirl.create(:model)
  #     end
  #     describe "requesting a pool I don't own" do
  #       it "should forbid access" do
  #         get :overview, :pool_id=>not_my_pool
  #         expect(response).to respond_forbidden
  #       end
  #     end
  #     describe "requesting a pool I own" do
  #       it "should be successful" do
  #         get :overview, :pool_id=>my_pool, :format=>:json
  #         expect(response).to be_success
  #       end
  #     end
  #     describe "requesting a pool I can edit" do
  #       before do
  #         @other_identity = FactoryGirl.create(:identity)
  #         AccessControl.create!(:pool=>my_pool, :identity=>@other_identity, :access=>'EDIT')
  #       end
  #       it "should be successful when rendering json" do
  #         get :overview, :pool_id=>my_pool, :format=>:json
  #         expect(response).to  be_successful
  #         json = JSON.parse(response.body)
  #         json['id'].should == my_pool.id
  #         json['models'].should == JSON.parse(my_pool.models.to_json)
  #         json['perspectives'].should == my_pool.exhibits.as_json
  #         json['facets'].should == {"model_name"=>[], "description_ssi"=>[]}
  #         json["numFound"].should == 0
  #       end
  #     end
  #   end
  # end
  
end