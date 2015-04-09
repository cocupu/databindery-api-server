require 'rails_helper'

describe Api::V1::ModelsController do
  let(:identity) { FactoryGirl.create :identity }
  let(:pool) { FactoryGirl.create :pool, owner:identity }
  let(:first_name_field) { FactoryGirl.create(:first_name_field)}
  let(:last_name_field) { FactoryGirl.create(:last_name_field)}
  let(:subject_field) {FactoryGirl.create(:subject_field)}
  let(:model) { FactoryGirl.create(:model, pool:pool) }
  let(:not_my_model) { FactoryGirl.create(:model) }
  let(:file_model) { Model.file_entity }
  let(:identity2) { FactoryGirl.create(:identity) }
  let(:pool_i_can_edit) do
    p = FactoryGirl.create :pool, :owner=> identity2
    AccessControl.create!(:pool=>p, :identity=>identity, :access=>'EDIT')
    return p
  end
  let(:model_i_can_edit) { FactoryGirl.create(:model, pool: pool_i_can_edit) }

  #before do
  #  identity2 = FactoryGirl.create(:identity)
  #  pool_i_can_edit = FactoryGirl.create :pool, :owner=> identity2
  #  AccessControl.create!(:pool=>pool_i_can_edit, :identity=>identity, :access=>'EDIT')
  #  model_i_can_edit = FactoryGirl.create(:model, pool: pool_i_can_edit)
  #end
  describe "index" do
    describe "when not logged on" do
      subject { get :index }
      it "should show nothing" do
        expect(response).to be_successful
        assigns[:models].should be_nil
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
        file_model
        model
        model_i_can_edit
      end
      it "should be successful" do
        get :index, :identity_id=>identity.short_name, :pool_id=>pool.short_name
        expect(response).to be_successful
        assigns[:models].size.should == 2
        assigns[:models].should include model, file_model
      end
      describe "when visiting a pool I can edit but dont own" do
        it "should show all the models" do
          get :index, :identity_id=>identity2.short_name, :pool_id=>pool_i_can_edit.short_name
          assigns[:models].size.should == 2
          assigns[:models].should include(model_i_can_edit)
        end
      end
      it "should return json" do
        get :index, :identity_id=>identity.short_name, :pool_id=>pool.short_name, :format=>:json
        expect(response).to be_successful
        json = JSON.parse(response.body)
        first_model_field = model.fields.first
        expect(json).to eq  [{"id"=>model.id,
          "url"=>"/api/v1/models/#{model.id}",
          "association_fields"=>[],
          "fields"=>
           [{"id"=>first_model_field.id,
             "name"=>"Description",
             "uri"=>"dc:description",
             "code"=>"description",
             "label"=>nil,
            "multivalue"=>nil,"created_at"=>first_model_field.created_at.as_json,"updated_at"=>first_model_field.updated_at.as_json, "references"=>nil, "type"=>"TextField",}],
          "name"=>model.name,
          "label_field_id"=>"",
          "allow_file_bindings"=>true,
          "pool_id" =>pool.id },
          {"id"=>file_model.id,
          "url"=>"/api/v1/models/#{file_model.id}",
          "association_fields"=>[],
          "fields"=> JSON.parse(Model.file_entity.fields.to_json),
          "name"=>file_model.name,
          "label_field_id"=>file_model.label_field_id.to_s,"allow_file_bindings"=>true}]
      end
    end
  end

  describe "show" do
    describe "when not logged on" do
      subject { get :show, :id=>model }
      it "should show nothing" do
        expect(response).to be_successful
        assigns[:models].should be_nil
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
      end
      describe "requesting a model I don't own" do
        it "should respond with forbidden message" do
          get :show, :id=>not_my_model
          expect(response).to respond_forbidden
        end
      end
      describe "requesting a model in a pool I can edit" do
        it "should be successful when rendering json" do
          expect(model_i_can_edit.owner).to_not eq identity
          get :show, :id=>model_i_can_edit, :format=>:json
          expect(response).to be_successful
          json = JSON.parse(response.body)
          expect(json['association_fields']).to eq []
          expect(json['fields']).to eq [{"id"=>model_i_can_edit.fields.first.id,"name"=>"Description", "references"=>nil, "type"=>"TextField", "uri"=>"dc:description", "code"=>"description", "label"=>nil,"multivalue"=>nil,"created_at"=>model_i_can_edit.fields.first.created_at.as_json,"updated_at"=>model_i_can_edit.fields.first.updated_at.as_json}]
        end
      end
      describe "requesting a model I own" do
        it "should be successful when rendering json" do
          get :show, :id=>model, :format=>:json
          expect(response).to be_successful
          json = JSON.parse(response.body)
          expect(json['id']).to eq model.id
          expect(json['name']).to eq model.name
          expect(json['association_fields']).to eq []
          expect(json['fields']).to eq JSON.parse(model.fields.to_json)
        end
      end
    end
  end

  describe "create" do
    describe "when not logged on" do
      it "should respond with forbidden message" do
        post :create, :pool_id=>pool, identity_id: identity
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
      end
      it "should render the form when validation fails" do
        post :create, :model=>{:foo=>'bar'}, :pool_id=>pool, identity_id: identity
        expect(response).to respond_bad_request(errors:["Name can't be blank"])
      end
      it "should be successful and return the model as json" do
        post :create, :model=>{:name=>'Turkey'}, :pool_id=>pool, identity_id: identity
        expect(response).to be_successful
        assigns[:model].should be_kind_of Model
        assigns[:model].name.should == 'Turkey'
        expect(response.body).to eq(controller.send(:serialize_model, assigns[:model]).to_json)
      end
      it "should be successful with json" do
        reference = FactoryGirl.create(:model)
        in_pool = FactoryGirl.create(:pool, owner: identity)
        post :create, :model=>{:name=>'Turkey', :fields=>[{"name"=>"Name", "type"=>"TextField", "uri"=>"", "code"=>"name"}], :association_fields=>[{'name'=> "workers", 'code'=>'workers', 'references'=>reference.id}]}, :pool_id=>in_pool, :format=>:json, identity_id: identity
        response.should be_successful
        json = JSON.parse response.body
        json["name"].should == 'Turkey'
        json["pool_id"].should == in_pool.id
        # json["identity"].should == identity.id
        json["id"].should_not be_nil
        model = Model.last
        model.fields.count.should == 2
        model.fields.first.name.should == "Name"
        model.fields.first.type.should == "TextField"
        model.fields.first.code.should == "name"
        model.association_fields.count.should == 1
        model.association_fields.first.name.should == 'workers'
        model.association_fields.first.label.should == reference.name
        model.association_fields.first.references.should == reference.id
      end
      it "should not allow you to create models in someone elses pool" do
        in_pool = FactoryGirl.create(:pool)
        post :create, :model=>{:name=>'Turkey'}, :pool_id=>in_pool, :format=>:json, identity_id: identity
        expect(response).to respond_forbidden()
      end
      it "should not allow you to create models with someone elses identity" do
        in_pool = FactoryGirl.create(:pool, owner: identity)
        post :create, :model=>{:name=>'Turkey'}, :pool_id=>in_pool, :format=>:json, identity_id: FactoryGirl.create(:identity)
        expect(response).to respond_forbidden(description:"You can't create for that identity")

      end
    end
  end

  describe "update" do
    describe "when not logged on" do
      it "should respond with forbidden message" do
        put :update, :id=>model, :model=>{:label=>'title'}
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
      end
      it "should forbid updates on a model that's not mine " do
        put :update, :id=>not_my_model, :model=>{:label=>'title'}
        expect(response).to respond_forbidden
      end
      it "should be able to set the label field" do
        model.fields = [last_name_field]
        model.save
        put :update, :id=>model, :model=>{:label_field_id=>last_name_field.id}
        json = JSON.parse(response.body)
        expect(json["label_field_id"]).to eq(last_name_field.id.to_s)
        expect(model.reload.label_field).to eq last_name_field
      end
      it "should be able to set label_field to a new field via the field's code (instead of id)" do
        params = {:model => {name:"Collection", label_field_id:"collection_name", fields:[{"code"=>"submitted_by", "name"=>"Submitted By"}, {"code"=>"collection_name", "name"=>"Collection Name"}, {"code"=>"media_<select>", "name"=>"Media        <select>"}, {"code"=>"#_of_media", "name"=>"# of Media"}, {"code"=>"collection_owner", "name"=>"Collection Owner"}, {"code"=>"collection_location", "name"=>"Collection Location"}, {"code"=>"program_title_english", "name"=>"Program Title English"}, {"code"=>"main_text_title_tibetan_<select>", "name"=>"Main Text Title Tibetan        <select>"}, {"code"=>"main_text_title_english_<select>", "name"=>"Main Text Title English        <select>"}, {"code"=>"program_location_<select>", "name"=>"Program Location        <select>"}, {"code"=>"date_from_", "name"=>"Date from "}, {"code"=>"date_to", "name"=>"Date to"}, {"code"=>"date_from_", "name"=>"Date from "}, {"code"=>"date_to", "name"=>"Date to"}, {"code"=>"teacher", "name"=>"Teacher"}, {"code"=>"restricted?_<select>", "name"=>"Restricted?        <select>"}, {"code"=>"original_recorded_by_<select>", "name"=>"Original Recorded By        <select>"}, {"code"=>"copy_or_original_<select>", "name"=>"Copy or Original        <select>"}, {"code"=>"translation_languages", "name"=>"Translation Languages"}, {"code"=>"notes", "name"=>"Notes"}, {"code"=>"post-digi_notes", "name"=>"Post-Digi Notes"}, {"code"=>"post-production_notes", "name"=>"Post-Production Notes"}], allow_file_bindings: true, association_fields: nil, code:nil, created_at:"2013-06-17T01:43:35Z",  id: 4, identity_id: 1, pool_id: model.pool.id}}
        put :update, :id=>model, model: params[:model]
        assigns[:model].label_field.code.should == "collection_name"
        assigns[:model].label_field.name.should == "Collection Name"
      end
      it "should be able to set label_field to an existing field via the field's code" do
        description_field = model.fields.first
        params = {:model => {name:"Collection", label_field_id:description_field.code}}
        put :update, :id=>model, model: params[:model]
        assigns[:model].label_field.should == description_field
      end
      it "should be successful on a model in a pool I can edit" do
        model_i_can_edit.fields = [first_name_field]
        model_i_can_edit.save
        put :update, :id=>model_i_can_edit, :model=>{:label_field_id=>first_name_field.id}
        expect(response).to be_success
        expect(assigns[:model].label_field).to eq(first_name_field)
      end

      it "should be able to update the model via json" do
        reference = FactoryGirl.create(:model)
        description_field = model.fields.first
        put :update, :id=>model, :model=>{label_field_id:description_field.id, :fields=>[{"id"=>description_field.id,"name"=>"New Name", "code"=>"name"}], :association_fields=>[{'name'=> "workers", 'code'=>'workers', 'references'=>reference.id}]}, :format=>:json
        response.should be_successful
        model.reload
        model.label_field.should == description_field
        model.fields.count.should == 2
        model.fields.first.name.should == "New Name"
        model.fields.first.type.should == "TextField"
        model.fields.first.code.should == "name"
        model.association_fields.count.should == 1
        model.association_fields.first.name.should == 'workers'
        model.association_fields.first.label.should == reference.name
        model.association_fields.first.references.should == reference.id
      end
      it "should accept json without fields wrapped in a :model hash" do
        reference = FactoryGirl.create(:model)
        put :update, :id=>model, :format=>:json, :label_field_id=>model.fields.first.id, :fields=>[{"id"=>model.fields.first.id,"name"=>"Newer Name", "type"=>"TextField", "uri"=>"", "code"=>"name"}], :association_fields_attributes=>[{'name'=> "workers", 'code'=>'workers', 'references'=>reference.id}]
        response.should be_successful
        model.reload
        model.label_field.should == model.fields.first
        model.fields.count.should == 2
        model.fields.first.name.should == "Newer Name"
        model.fields.first.type.should == "TextField"
        model.fields.first.code.should == "name"
        model.association_fields.count.should == 1
        model.association_fields.first.name.should == 'workers'
        model.association_fields.first.label.should == reference.name
        model.association_fields.first.references.should == reference.id
      end
      it "should send errors over json" do
        reference = FactoryGirl.create(:model)
        put :update, :id=>model, :model=>{label_field_id:subject_field.id}, :format=>:json
        expect(response).to respond_bad_request(errors:["Label field must be one of the fields in this model"])
      end
    end
  end
  
  describe "delete" do
    describe "when not logged on" do
      subject { delete }
      it "should respond with unauthorized message" do
        delete :destroy, :id=>model
        expect(response).to respond_unauthorized
      end
    end

    describe "when logged on" do
      before do
        sign_in identity.login_credential
        file_model = Model.file_entity
      end
      it "should respond with forbidden message" do
        delete :destroy, :id=>not_my_model
        expect(response).to respond_forbidden
      end
      
      it "should be able to delete a model" do
        delete :destroy, :id=>model
        expect(response).to respond_deleted(description:"Deleted model #{model.id} (#{model.name}).")
        expect{Model.find(model.id)}.to raise_exception ActiveRecord::RecordNotFound
        #  Double-checking...
        get :index, :identity_id=>identity.short_name, :pool_id=>pool.short_name
        expect(assigns[:models].size).to eq 1
        expect(assigns[:models]).to_not include model
        expect(assigns[:models]).to include file_model
      end
    end
  end

end
