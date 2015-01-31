require 'rails_helper'

describe Bindery::Curator do
  before do

  end
  describe "spawn_from_fields" do
    before do
      @identity = FactoryGirl.create :identity
      @pool = FactoryGirl.create :pool, :owner=>@identity
      @dest_model = FactoryGirl.create(:model, pool: @pool, label: 'full_name',
                                       fields_attributes: [{:code=>'full_name'}])
      @source_model = FactoryGirl.create(:model, pool: @pool, label: 'title',
                                         fields_attributes: [{:code=>'submitted_by'}, {:code=>'location'}, {:code=>'title'}])
      @node1 = FactoryGirl.create(:node, model: @source_model, pool: @pool, :data=>{'submitted_by'=>'Justin Coyne', 'location'=>'Malibu', 'title'=>'My Vacation'})
      @node2 = FactoryGirl.create(:node, model: @source_model, pool: @pool, :data=>{'submitted_by'=>'Matt Zumwalt', 'location'=>'Berlin', 'title'=>'My Holiday'})
      @node3 = FactoryGirl.create(:node, model: @source_model, pool: @pool, :data=>{'submitted_by'=>'Justin Coyne', 'location'=>'Bali', 'title'=>'My other Vacation'})
      @submitted_by_field = @source_model.fields.where(code:'submitted_by').first
      @location_field = @source_model.fields.where(code:'location').first
      @title_field = @source_model.fields.where(code:'title').first
    end
    it "should extract entities from specified fields" do
      # it "should Spawn new :destination_model nodes using the :source_field_name field from :source_model nodes, setting the extracted value as the :destination_field_name field on the resulting spawned nodes." do
      @dest_model.nodes.count.should == 0
      Bindery::Curator.instance.spawn_from_field(@ident, @pool, @source_model.id, "submitted_by", "creator", @dest_model.id, "full_name", :delete_source_value=>true)
      # Can't just use @dest_model.nodes to count the nodes because that returns all versions of each node (so it returns 4 nodes instead of 2 in this case)
      # Instead counting the number of unique persistent_ids in use by @dest_model.nodes
      @dest_model.nodes.head.count.should == 2
      # One "Justin" node should have been spawned from 2 sources
      n1 = @node1.latest_version
      justin_node_id = n1.field_value("creator", :find_by => :code).first
      justin = Node.find_by_persistent_id(justin_node_id)
      justin.model.should == @dest_model
      justin.field_value("full_name", :find_by => :code).should == "Justin Coyne"
      n3 = @node3.latest_version
      n3.field_value("creator", :find_by => :code).first.should == justin_node_id
      n1.field_value("submitted_by", :find_by => :code).should be_nil
      n3.field_value("submitted_by", :find_by => :code).should be_nil
      # One Matt node should have been spawned from 1 source
      n2 = @node2.latest_version
      matt_node_id = n2.field_value("creator", :find_by => :code).first
      matt = Node.find_by_persistent_id(matt_node_id)
      matt.model.should == @dest_model
      matt.field_value("full_name", :find_by => :code).should == "Matt Zumwalt"
      n2.field_value("submitted_by", :find_by => :code).should be_nil
    end
    it "should delete fields from source model and nodes if delete_source_value:true" do
      Bindery::Curator.instance.spawn_from_field(@ident, @pool, @source_model.id, "submitted_by", "creator", @dest_model.id, "full_name", :delete_source_value=>true)
      @node1.latest_version.field_value("submitted_by", :find_by => :code).should be_nil
      @source_model.reload.fields.where(code:"submitted_by").should be_empty
    end
    it "should set up association on source model and fields on destination model if they do not exist yet" do
      audio_cassette_model = FactoryGirl.create(:model, pool: @pool, label: 'program_title_english',
                                                fields_attributes: [{:code=>'program_title_english'}, {code:"teacher"}, {code:"main_text_title_tibetan"},{code:'date_to'},{code:'restricted?'},{code:'translation_languages'},
                                                         {:code=>'program_location', name:"Program Location"},
                                                         {:code=>'main_text_title_english', name:"Main Text (English)"},
                                                         {:code=>'date_from', name:"Start Date", type:"DateField"}, {:code=>'date_tpo', name:"End Date", type:"DateField"}
                                                ])
      seminar_model = FactoryGirl.create(:model, pool: @pool, label: 'location_name',
                                         fields_attributes: [{:code=>'location_name'}])
      audio_cassette1 = FactoryGirl.create(:node, model: audio_cassette_model, pool: @pool, :data=>audio_cassette_model.convert_data_field_codes_to_id_strings({'submitted_by'=>'Justin Coyne', 'program_location'=>'Malibu', 'program_title_english'=>'Joy of Living 1', "teacher"=>"Andy Kauffman", "main_text_title_english"=>"Life and Times of Andy Kauffman", "main_text_title_tibetan"=>"blo rig", "date_from"=>"10-1-2011", "date_to"=>"10-6-2011", "restricted?"=>"No","translation_languages"=>"english"}))
      audio_cassette2 = FactoryGirl.create(:node, model: audio_cassette_model, pool: @pool, :data=>audio_cassette_model.convert_data_field_codes_to_id_strings({'submitted_by'=>'Justin Coyne', 'program_location'=>'Georgetown', 'program_title_english'=>'Aint I a Woman', "teacher"=>"Sojourner Truth", "main_text_title_english"=>"Modern History Sourcebook", "main_text_title_tibetan"=>"rnams bshes", "date_from"=>"12-1-1851", "date_to"=>"12-1-1851", "restricted?"=>"No","translation_languages"=>"english"}))
      audio_cassette3 = FactoryGirl.create(:node, model: audio_cassette_model, pool: @pool, :data=>audio_cassette_model.convert_data_field_codes_to_id_strings({'submitted_by'=>'Sally Ride', 'program_location'=>'Portland, OR', 'program_title_english'=>'Joy of Living 1', "teacher"=>"Mingyur Rinpoche", "main_text_title_english"=>"Joy of Living", "main_text_title_tibetan"=>"tse gyi dewa", "date_from"=>"10-1-2011", "date_to"=>"10-6-2011", "restricted?"=>"Yes","translation_languages"=>"greek, english"}))
      previous_seminars = seminar_model.nodes.head.count

      Bindery::Curator.instance.spawn_from_field(@ident, @pool, audio_cassette_model.id, "program_title_english", "seminar", seminar_model.id, "title_en", also_move: [{"program_location"=>"location_name"}, "teacher", "main_text_title_english", "main_text_title_tibetan"], also_copy:["date_from", "date_to", "restricted?","translation_languages"], delete_source_value:true)

      #Audio Cassettes (sources)
      audio_cassette_model.reload
      constructed_association = audio_cassette_model.fields.where(code:"seminar").first
      constructed_association.references.should == seminar_model.id
      constructed_association.name.should == "Seminars"
      updated_cassette = audio_cassette1.latest_version
      ["program_title_english","program_location","teacher", "main_text_title_english", "main_text_title_tibetan"].each do |field_code|
        updated_cassette.data[field_code].should be_nil
      end

      # Seminars (destinations)
      seminar_model.reload
      # Ensure that all the fields were copied into the destination model
      constructed_field_codes = seminar_model.fields.map {|f| f.code}
      ["location_name","teacher", "main_text_title_english", "main_text_title_tibetan", "date_from", "date_to", "restricted?","translation_languages"].each do |field_code|
        constructed_field_codes.should include(field_code)
      end
      seminar_model.fields.where(code: "main_text_title_english").first.name.should == "Main Text (English)"
      seminar_model.fields.where(code: "date_from").first.type.should == "DateField"

      seminar_model.nodes.head.count.should == previous_seminars+2
      created_seminar = Node.find_by_persistent_id(updated_cassette.field_value("seminar", :find_by => :code).first)
      ["location_name","teacher", "main_text_title_english", "main_text_title_tibetan", "date_from", "date_to", "restricted?","translation_languages"].each do |field_code|
        created_seminar.field_value(field_code, :find_by => :code).should_not be_nil
      end
      created_seminar.field_value('title_en', :find_by => :code).should == "Joy of Living 1"
      # expect(["Malibu","Portland, OR"]).to include created_seminar.field_value('location_name', :find_by => :code)
    end
    it "should create destination model if none specified" do
      prev_model_count = Model.count
      Bindery::Curator.instance.spawn_from_field(@ident, @pool, @source_model.id, "submitted_by", "creator", nil, "full_name", :delete_source_value=>true)
      Model.count.should == prev_model_count+1
      dest_model = Model.last
      dest_model.nodes.head.count.should == 2
      # One "Justin" node should have been spawned from 2 sources
      n1 = @node1.latest_version
      justin_node_id = n1.field_value('creator', :find_by => :code).first
      justin = Node.find_by_persistent_id(justin_node_id)
      justin.model.should == dest_model
      justin.field_value('full_name', :find_by => :code).should == "Justin Coyne"
      n3 = @node3.latest_version
      n3.field_value('creator', :find_by => :code).first.should == justin_node_id
      n1.field_value('submitted_by', :find_by => :code).should be_nil
      n3.field_value('submitted_by', :find_by => :code).should be_nil
      # One Matt node should have been spawned from 1 source
      n2 = @node2.latest_version
      matt_node_id = n2.field_value('creator', :find_by => :code).first
      matt = Node.find_by_persistent_id(matt_node_id)
      matt.model.should == dest_model
      matt.field_value('full_name', :find_by => :code).should == "Matt Zumwalt"
      n2.field_value('submitted_by', :find_by => :code).should be_nil
    end
  end

  describe "find_or_create_node" do
    before do
      @identity = FactoryGirl.create :identity
      @pool = FactoryGirl.create :pool, :owner=>@identity
      @model = FactoryGirl.create(:model, pool: @pool, label: 'first_name',
                                  fields_attributes: [{:code=>'first_name'}, {:code=>'last_name'}, {:code=>'title'}])
      @node1 = FactoryGirl.create(:node, model: @model, pool: @pool, :data=>@model.convert_data_field_codes_to_id_strings({'first_name'=>'Justin', 'last_name'=>'Coyne', 'title'=>'Mr.'}))
      @node2 = FactoryGirl.create(:node, model: @model, pool: @pool, :data=>@model.convert_data_field_codes_to_id_strings({'first_name'=>'Matt', 'last_name'=>'Zumwalt', 'title'=>'Mr.'}))
      @node3 = FactoryGirl.create(:node, model: @model, pool: @pool, :data=>@model.convert_data_field_codes_to_id_strings({'first_name'=>'Justin', 'last_name'=>'Ball', 'title'=>'Mr.'}))
    end
    it "should not be successful using a pool I can't edit" do
      pending
      Bindery::Curator.instance.find_or_create_node(pool:@pool, :model=>@model, :data=>@model.convert_data_field_codes_to_id_strings({"first_name" =>"Justin", "last_name" => "Coyne"}))
      response.code.should == '404'
      assigns[:node].should be_nil
    end

    it "should return existing node  if one already fits the fields & values specified" do
      previous_number_of_nodes = Node.count
      result = Bindery::Curator.instance.find_or_create_node(pool:@pool, :model=>@model, :data=>@model.convert_data_field_codes_to_id_strings({"first_name" =>"Justin", "last_name" => "Coyne"}))
      Node.count.should == previous_number_of_nodes
      result.should == @node1
    end

    it "should create a new node if none fits the fields & values specified" do
      previous_number_of_nodes = Node.count
      result = Bindery::Curator.instance.find_or_create_node(pool:@pool, :model=>@model, :data=>@model.convert_data_field_codes_to_id_strings({"first_name" =>"Randy", "last_name" => "Reckless"}))
      Node.count.should == previous_number_of_nodes + 1
      result.data.should == @model.convert_data_field_codes_to_id_strings({"first_name"=>"Randy", "last_name"=>"Reckless"})
      result.model.should == @model
    end
  end

end