require 'rails_helper'

describe MappingTemplate do
  before do
    @template = MappingTemplate.new(:row_start=>3)
  end
  it "should have row_start" do
    @template.row_start.should == 3
  end

  it "should belong to an identity" do
    subject.should_not be_valid
    subject.errors.full_messages.should == ["Owner can't be blank"]
    subject.owner = Identity.create
    subject.should be_valid
  end

  describe "model_mappings" do
    before do
      @template.owner = FactoryGirl.create :identity
      @model = Model.create(:name=>'Truck', :fields_attributes=>[{code:'avail_colors', :name=>"Colors"}])
    end
    it "should serialize and deserialize the mapping" do
      @template.model_mappings = [ 
         {:model_id => @model.id,
          :filter_source => 'F',
          :filter_predicate => 'equal',
          :filter_constant => 'Ford',
          :field_mappings=> {'C' => 'avail_colors' }}]
      @template.save!
      @template.reload
      @template.model_mappings[0][:field_mappings]['C'].should == 'avail_colors'
      @template.model_mappings[0][:model_id].should == @model.id

    end
  end

  describe "attributes=" do
    before do
      #Model.count.should == 0
      @template.pool = FactoryGirl.create :pool
      @template.owner = @template.pool.owner
      @template.attributes = {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{:name=>"Talk", :label=>'C', :field_mappings_attributes=>{'0'=>{:label=>"File Name", :source=>"A"}, '1'=>{:label=>"Title", :source=>"C"},'2'=>{:label=>"", :source=>""}}}}}
    end
    it "should create the model and serialize the mapping" do
      model = Model.last
      model.name.should == 'Talk'
      model.label_field.code.should == 'title'
      model.fields.count.should == 2
      model.fields.where(code:"file_name").first.name.should == "File Name"
      model.fields.where(code:"title").first.name.should == "Title"

      @template.row_start.should == 2

      @template.model_mappings[0][:field_mappings][1][:label].should == 'Title'
      @template.model_mappings[0][:field_mappings][1][:field].should == 'title'
      @template.model_mappings[0][:name].should == 'Talk'
      @template.model_mappings[0][:label].should == 'C'
    end
    it "should parse model mappings and field mappings with indifferent access -- most importantly, setting the label on the model" do
      @template.attributes = {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{"name"=>"Joke", "label"=>2, :field_mappings_attributes=>{'0'=>{"source"=>0, "label"=>"Location"}, '1'=>{"source"=>1, "label"=>"Submitted By"},'2'=>{"source"=>2, "label"=>"Collection Name"}}}}}
      model = Model.last
      model.name.should == 'Joke'
      model.label_field.should == model.fields.where(code:'collection_name').first
    end
    it "should match model label to fields even when label is in a string and field source value is an integer" do
      @template.attributes = {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{"name"=>"Joke", "label"=>"1", :field_mappings_attributes=>{'0'=>{"source"=>0, "label"=>"Location"}, '1'=>{"source"=>1, "label"=>"Submitted By"},'2'=>{"source"=>2, "label"=>"Collection Name"}}}}}
      model = Model.last
      model.label_field.should == model.fields.where(code:'submitted_by').first
    end
    it "should update, not duplicate, model mappings on consecutive calls" do
      @template.model_mappings.count.should == 1
      original_model_id = @template.model_mappings.first[:model_id]
      @template.attributes = {"row_start"=>"2", :model_mappings_attributes=>{'0'=>{"name"=>"Joke", "label"=>2, model_id: original_model_id, :field_mappings_attributes=>{'0'=>{"source"=>0, "label"=>"Location"}, '1'=>{"source"=>1, "label"=>"Submitted By"},'2'=>{"source"=>2, "label"=>"Collection Name"}}}}}
      @template.model_mappings.count.should == 1
      @template.model_mappings.first[:model_id].should == original_model_id
    end
  end

  describe "file_type" do
    it "should have a file_type" do
      subject.file_type= "foo"
      subject.file_type.should == "foo"
    end
  end
end
