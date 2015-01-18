require 'rails_helper'

describe Bindery::Identifiable do
  class DummyClass
    include Bindery::Identifiable
    attr_accessor :persistent_id
  end
  subject { DummyClass.new }

  
  describe "generate_uuid" do
    it "should set a persistent_id on object" do
      expect(subject.persistent_id).to  be_nil
      new_uuid = subject.generate_uuid
      expect(subject.persistent_id).to_not  be_nil
      expect(subject.persistent_id).to eq new_uuid
    end
    it "should return persistent_id if it is already set" do
      expect(subject.persistent_id).to  be_nil
      new_uuid = subject.generate_uuid
      expect(subject.generate_uuid).to eq new_uuid
    end
  end

end
