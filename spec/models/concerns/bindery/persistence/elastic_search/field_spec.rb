require  'rails_helper'

describe Bindery::Persistence::ElasticSearch::Model do

  describe "elasticsearch_attributes" do
    it "varies by Field class/type" do
      expect(Field.new.elasticsearch_attributes).to eq( {:type=>"string"} )
      expect(TextArea.new.elasticsearch_attributes).to eq( {:type=>"string"} )
      expect(TextField.new.elasticsearch_attributes).to eq( {:type=>"string"} )

      # ElasticSearch can auto-detect arrays.  There is no Array type.
      expect(ArrayField.new.elasticsearch_attributes).to eq( {:type=>"string"} )

      expect(NumberField.new.elasticsearch_attributes).to eq( {:type=>"float"} )
      expect(IntegerField.new.elasticsearch_attributes).to eq( {:type=>"integer"} )

      expect(BooleanField.new.elasticsearch_attributes).to eq( {:type=>"boolean"} )
      expect(DateField.new.elasticsearch_attributes).to eq( {:type=>"date"} )
      expect(AttachmentField.new.elasticsearch_attributes).to eq( {:type=>"attachment"} )
    end
  end

end