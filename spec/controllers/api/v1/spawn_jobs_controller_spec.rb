require 'rails_helper'

describe Api::V1::SpawnJobsController do
  describe "create with a single model" do
    before do
      Model.delete_all
      Model.count.should == 0  #Make sure the db is clean
      @node = FactoryGirl.create(:spreadsheet)
      @mapping_template = FactoryGirl.create(:mapping_template, {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>""}}}}})
    end
    describe "when not logged in" do
      it "should not create" do
        pool = FactoryGirl.create(:pool)
        SpawnJob.should_receive(:new).never
        post :create, :source_node_id=>@node.id, :mapping_template_id=>@mapping_template.id, :pool_id=>pool
        expect(response).to respond_unauthorized
      end
    end
    describe "when logged in" do
      before do
        @identity = FactoryGirl.create :identity
        @pool = FactoryGirl.create(:pool, owner: @identity)        
        sign_in @identity.login_credential
        @mapping_template = FactoryGirl.create(:mapping_template, {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>""}}}}})
        @file  =File.new(Rails.root + 'spec/fixtures/KTGR Audio Collection Sample.xlsx')
        @node.stub(:s3_obj).and_return(@file)
        @node.file_name = 'KTGR Audio Collection Sample.xlsx'
        @node.mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        Bindery::Spreadsheet.stub(:find_by_identifier).and_return(@node)
      end
      it "should create" do
        Bindery::ReifyRowJob.stub(:create).and_return("jobId")
        post :create, :source_node_id=>@node.id, :identity_id=>@identity.short_name, :mapping_template_id=>@mapping_template.id, :pool_id=>@pool
        assigns[:mapping_template].should == @mapping_template
        assigns[:spawn_job].pool.should == @pool
        assigns[:spawn_job].mapping_template.should == @mapping_template
        assigns[:spawn_job].node.should == @node
        assigns[:spawn_job].reification_job_ids.count.should == 18
        expect(response).to respond_accepted(description:"Spawning #{@node.parsed_sheet.last_row} entities from #{@node.title}.")
        expect(JSON.parse(response.body)["job"].to_json).to eq(assigns[:spawn_job].to_json)
      end
      it "should raise not_found errors when identity does not belong to the logged in user" do
        SpawnJob.should_receive(:new).never
        post :create, :source_node_id=>@node.id, :identity_id=>FactoryGirl.create(:identity).short_name, :mapping_template_id=>@mapping_template.id, :pool_id=>@pool
        expect(response).to respond_forbidden(description:"You can't create for that identity")
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
      pending
      get :show, :spreadsheet_id=>7, :id=>@template.id, :pool_id=>@pool, identity_id: @identity.short_name
      response.should be_success
      assigns[:mapping_template].should == @template
    end
  end

end
