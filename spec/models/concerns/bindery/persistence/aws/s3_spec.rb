require 'rails_helper'

describe Bindery::Persistence::AWS::S3 do
  it "should have default connection" do
    conn = subject.default_connection 
    expect(conn).to be_instance_of Bindery::Persistence::AWS::S3::Connection
    expect(conn.access_key_id).to eq AWS.config.access_key_id
    expect(conn.secret_access_key).to eq AWS.config.secret_access_key
  end
  describe "key_from_filepath" do
    it "should extract the object key from the filepath from response that direct upload returns" do
      filepath = "/f53e6340-66e4-0130-8d3f-442c031da886/uploads%2F20130306T1135Z_7f3c6aa9d5d5a164e047281b6603bed7%2FDSC_0426-7.jpg"
      key = Bindery::Persistence::AWS::S3.key_from_filepath(filepath,bucket:"f53e6340-66e4-0130-8d3f-442c031da886")
      expect(key).to eq "uploads/20130306T1135Z_7f3c6aa9d5d5a164e047281b6603bed7/DSC_0426-7.jpg"
    end
  end
  describe "generate_storage_location_id" do
    before do
      @file_entity = FileEntity.build persistent_id:"samplePid"
      @now = Time.now
      @formatted_now = @now.in_time_zone('UTC').strftime('%Y%m%dT%H%M%S%Z')
    end
    it "should generate the desired S3 key for the given File Entity" do
      Time.stub(:now).and_return(@now)
      expect(Bindery::Persistence::AWS::S3.generate_storage_location_id(@file_entity)).to eq "samplePid_#{@formatted_now}"
    end
    it "should include filename if available" do
      Time.stub(:now).and_return(@now)
      @file_entity.file_name ="my file.jpg"
      expect(Bindery::Persistence::AWS::S3.generate_storage_location_id(@file_entity)).to eq "samplePid_#{@formatted_now}_my file.jpg"
    end
  end
end
