require 'rails_helper'

describe Api::V1::MappingTemplatesController do
  describe "create with a single model" do
    before do
      Model.delete_all
      Model.count.should == 0  #Make sure the db is clean
    end
    describe "when not logged in" do
      it "should not create" do
        pool = FactoryGirl.create(:pool)
        post :create, :mapping_template=>{"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>""}}}}}, :pool_id=>pool
        response.should respond_unauthorized
      end
    end
    describe "when logged in" do
      before do
        @identity = FactoryGirl.create :identity
        @pool = FactoryGirl.create(:pool, owner: @identity)
        sign_in @identity.login_credential
      end
      it "should create" do
        original_model_count = Model.count
        post :create, :identity_id=>@identity.short_name, :mapping_template=>{"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :label=>'C', :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>"D"}}}}}, :pool_id=>@pool
        assigns[:mapping_template].row_start.should == 2
        model = Model.find(assigns[:mapping_template].model_mappings.first[:model_id])
        Model.count.should == original_model_count+1
        model.fields.count.should == 2
        model.fields.where(code:"file_name").first.name.should == "File Name"
        model.fields.where(code:"title").first.name.should == "Title"
        model.name.should == 'Talk'
        model.label_field.should == model.fields.where(code:'title').first
        mapping = assigns[:mapping_template].model_mappings[0]
        mapping[:field_mappings].should == [ {"label"=>"File Name", "source"=>"A", 'field' => 'file_name'},
           {"label"=>"Title", "source"=>"C", 'field' => 'title'},
           {"label"=>"", "source"=>"D"}]
        expect(response).to be_success
        expect(response.body).to eq(assigns[:mapping_template].to_json)
      end
      it "should raise errors if no model name was supplied" do
        original_model_count = Model.count
        post :create, :identity_id=>@identity.short_name, :mapping_template=>{"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"", :label=>'C', :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>"D"}}}}}, :pool_id=>@pool
        assigns[:mapping_template].row_start.should == 2
        Model.count.should == original_model_count
        response.should respond_bad_request(errors:["Name can't be blank"])
      end
      it "should raise not_found errors when identity does not belong to the logged in user" do
        post :create, :identity_id=>FactoryGirl.create(:identity).short_name, :mapping_template=>{"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"", :label=>'C', :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>"D"}}}}}, :pool_id=>@pool
        expect(response).to respond_forbidden(description:"You can't create for that identity")
      end
      it "should support simplified model and field mappings from json" do
        params = {:identity_id=>@identity.short_name, :pool_id=>@pool,
                  mapping_template: {
                    "row_start"=>2,
                    "model_mappings"=>[{
                        "name"=>"KTGR Archive Collection List Sample.xls Row",
                        "label" => 2,
                        "field_mappings"=>[{"source"=>0, "label"=>"Location"}, {"source"=>1, "label"=>"Submitted By"}, {"source"=>2, "label"=>"Collection Name"}]

                    }]
                  }
        }
        post :create, params
        generated_template = assigns[:mapping_template].model_mappings[0]
        generated_template[:field_mappings].should ==
            [{"source"=>"0", "label"=>"Location", "field"=>"location"},
             {"source"=>"1", "label"=>"Submitted By", "field"=>"submitted_by"},
             {"source"=>"2", "label"=>"Collection Name", "field"=>"collection_name"}]
        model = Model.find(assigns[:mapping_template].model_mappings.first[:model_id])
        model.label_field.should == model.fields.where(code:'collection_name').first
      end

    end
  end

  describe "show" do
    before do
      @identity = FactoryGirl.create :identity
      @pool = FactoryGirl.create(:pool, owner: @identity)
      @template = MappingTemplate.new(owner: @pool.owner, pool: @pool)
      @template.attributes = {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>""}}}}} 
      @template.save!
      sign_in @identity.login_credential
    end
    it "should show" do
      get :show, :spreadsheet_id=>7, :id=>@template.id, :pool_id=>@pool, identity_id: @identity.short_name
      response.should be_success
      assigns[:mapping_template].should == @template
    end
  end

end
