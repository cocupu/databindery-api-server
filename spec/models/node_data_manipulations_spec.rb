require 'rails_helper'

describe Node do
  let(:full_name_field) { FactoryGirl.create :full_name_field }
  let(:location_field) { FactoryGirl.create :location_field }
  let(:model) { FactoryGirl.create(:model, fields:[full_name_field,location_field])}
  subject { Node.new(model:model, data:{ full_name_field.to_param => "My Value" })}
  describe "field_value" do
    it "should get field values by field id" do
      expect( subject.field_value(full_name_field.id) ).to eq("My Value")
    end
    it "should get field values by field code" do
      expect( subject.field_value(full_name_field.code, :find_by => :code) ).to eq("My Value")
    end
  end
  describe "set_field_value" do
    it "should set field values by field id and return the new value" do
      expect( subject.set_field_value(full_name_field.id, "NEW VALUE") ).to eq("NEW VALUE")
      expect( subject.field_value(full_name_field.id) ).to eq("NEW VALUE")
    end
    it "should set field values by field code" do
      expect(  subject.set_field_value(full_name_field.code, "NEW VALUE", :find_by => :code) ).to eq("NEW VALUE")
      expect( subject.field_value(full_name_field.id) ).to eq("NEW VALUE")
    end
    it "should raise error if no field id is available" do
      expect{ subject.set_field_value("nonexistent_field", "NEW VALUE", :find_by => :code) }.to raise_error(ArgumentError)
    end
  end

  let(:data_with_field_codes) { {"full_name"=>"Bessie Smith", "location"=>"New Orleans", "passion"=>"Jazz", "profession"=>"Singer"} }
  describe "convert_data_field_codes_to_id_strings" do
    it "should replace field codes with id strings where possible" do
      expect( subject.convert_data_field_codes_to_id_strings(data_with_field_codes) ).to eq( {full_name_field.to_param=>"Bessie Smith", location_field.to_param=>"New Orleans", "passion"=>"Jazz", "profession"=>"Singer"} )
    end
  end
  describe "convert_data_field_codes_to_id_strings!" do
    it "should replace field codes with id strings where possible" do
      subject.data =  data_with_field_codes
      subject.convert_data_field_codes_to_id_strings!
      expect( subject.data ).to eq( {full_name_field.to_param=>"Bessie Smith", location_field.to_param=>"New Orleans", "passion"=>"Jazz", "profession"=>"Singer"} )
    end
  end
end