require 'rails_helper'

describe FileEntity do
  describe '#register' do
    before do
      @identity = FactoryGirl.create :identity
      @pool = FactoryGirl.create :pool, :owner=>@identity
    end
    it "should register remote file as a new FileEntity and return the FileEntity" do
      params = {binding: "https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg",
                data: {
                  storage_location_id: "/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg", file_name: "DSC_0549-3.jpg", file_size: "471990", mime_type: "image/jpeg"
                  }}
      s3_obj_metadata_hash = {}
      stub_s3_obj = double("S3 Object", :metadata=>s3_obj_metadata_hash)
      S3Connection.any_instance.stub(:get).and_return(stub_s3_obj)
      file_entity = FileEntity.register(@pool, params)
      s3_obj_metadata_hash.should == {"filename"=>"DSC_0549-3.jpg", "bindery-pid" => file_entity.persistent_id}
      file_entity.file_entity_type.should == "S3"
      file_entity.binding.should == "https://s3.amazonaws.com/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"
      file_entity.storage_location_id.should == "/f542aab0-66e4-0130-8d40-442c031da886/uploads%2F20130305T1425Z_eaf29caae12b6d4a101297b45c46dc2a%2FDSC_0549-3.jpg"
      file_entity.file_name.should == "DSC_0549-3.jpg"
      file_entity.file_size.should == "471990"
      file_entity.mime_type.should == "image/jpeg"
      file_entity.pool.should == @pool
    end
    it "should pass through metadata, including persistent_id" do
      @pool.default_file_store.should_receive(:get).with(@pool.persistent_id, "myPid_20131205T134412CST").and_return(double("S3 Object", :metadata=>{}))
      params = {"persistent_id"=>"myPid","binding"=>"http://s3.amazon.com/sampleBinding", "data"=>{"file_name"=>"909-Last-Supper-Large.jpg", "mime_type"=>"image/jpeg", "file_size"=>"183237", "storage_location_id"=>"myPid_20131205T134412CST"}}
      file_entity = FileEntity.register(@pool, params)
      file_entity.persistent_id.should == "myPid"
      file_entity.binding.should == "http://s3.amazon.com/sampleBinding"
      file_entity.storage_location_id.should == "myPid_20131205T134412CST"
      file_entity.bucket.should == @pool.persistent_id
      file_entity.file_name.should == "909-Last-Supper-Large.jpg"
      file_entity.content_type.should == "Image"
      file_entity.file_size.should == "183237"
      file_entity.mime_type.should == "image/jpeg"
      file_entity.pool.should == @pool
    end
    it "should generate binding url if only storage_location_id is provided" do
      @pool.default_file_store.should_receive(:get).with(@pool.persistent_id, "myPid_20131205T134412CST").and_return(double("S3 Object", :metadata=>{}))
      params = {"persistent_id"=>"myPid", "data"=>{ "storage_location_id"=>"myPid_20131205T134412CST"}}
      file_entity = FileEntity.register(@pool, params)
      file_entity.binding.should == "https://s3.amazonaws.com/#{file_entity.bucket}/myPid_20131205T134412CST"
    end
  end
  describe '#placeholder_for_upload' do
    before do
      @identity = FactoryGirl.create :identity
      @pool = FactoryGirl.create :pool, :owner=>@identity
    end
    it "should generate an UNSAVED FileEntity with persistent_id and storage_location_id" do
      Bindery::Persistence::S3.should_receive(:generate_storage_location_id).and_return("generated storage id")
      file_entity = FileEntity.placeholder_for_upload(@pool, {})
      file_entity.should be_new_record
      file_entity.persistent_id.should_not be_nil
      file_entity.storage_location_id.should == "generated storage id"
    end
  end

  describe "local file handling" do
    subject {Node.new.extend(FileEntity)}
    describe "local_file_pathname" do
      it "should return a tmp file path that includes the file extension" do
        subject.generate_uuid
        subject.file_name = "My Sample Spreadsheet.xls"
        subject.local_file_pathname.should == File.join('', 'tmp', 'cocupu', Rails.env, subject.persistent_id+".xls")
        subject.file_name = "My Sample Test.doc"
        subject.local_file_pathname.should == File.join('', 'tmp', 'cocupu', Rails.env, subject.persistent_id+".doc")
      end
    end
    describe "generate_tmp_file" do
      it "should download the file from the storage source and write it to the local_file_path" do
        subject.persistent_id = "test-generate_local_file"
        subject.file_name = "dechen_rangdrol_archives_database.xls"
        @file=File.new(Rails.root + 'spec/fixtures/dechen_rangdrol_archives_database.xls') 
        # S3Object.read behaves like File.read, so returning a File as stub for the S3 Object
        subject.stub(:s3_obj).and_return(@file)
        subject.generate_tmp_file
        File.new(subject.local_file_pathname).read.should == File.new(Rails.root + 'spec/fixtures/dechen_rangdrol_archives_database.xls').read
      end
    end
  end
  
  describe "content type inspectors" do
    subject {Node.new(model:Model.file_entity).extend(FileEntity)}
    it "should be included in solr doc" do
      subject.stub(:mime_type).and_return("image/jpeg")
      subject.content_type # this is usually called by #register
      subject.to_solr["content_type_ssi"].should == "Image"
    end
    describe "audio?" do
      it "should test for audio mimetypes" do
        subject.stub(:mime_type).and_return("image/jpeg")
        subject.audio?.should be_falsey
        ["audio/mp3", "audio/mpeg"].each do |mimetype|
          subject.stub(:mime_type).and_return(mimetype)
          subject.audio?.should be_truthy
        end
        subject.stub(:mime_type).and_return("image/jpeg")
        subject.audio?.should be_falsey
      end
    end
    describe "image?" do
      it "should test for image mimetypes" do
        subject.stub(:mime_type).and_return("audio/mpeg")
        subject.image?.should be_falsey
        ["image/png","image/jpeg", 'image/jpg', 'image/bmp', "image/gif"].each do |mimetype|
          subject.stub(:mime_type).and_return(mimetype)
          subject.image?.should be_truthy
        end
        subject.stub(:mime_type).and_return("audio/mp3")
        subject.image?.should be_falsey
      end
    end
    describe "video?" do
      it "should test for video mimetypes" do
        subject.stub(:mime_type).and_return("audio/mpeg")
        subject.video?.should be_falsey
        ["video/mpeg", "video/mp4", "video/x-msvideo", "video/avi", "video/quicktime"].each do |mimetype|
          subject.stub(:mime_type).and_return(mimetype)
          subject.video?.should be_truthy
        end
        subject.stub(:mime_type).and_return("audio/mpeg")
        subject.video?.should be_falsey
      end
    end
    describe "pdf?" do
      it "should test for pdf mimetype" do
        subject.stub(:mime_type).and_return("audio/mpeg")
        subject.pdf?.should be_falsey
        ["application/pdf"].each do |mimetype|
          subject.stub(:mime_type).and_return(mimetype)
          subject.pdf?.should be_truthy
        end
        subject.stub(:mime_type).and_return("video/avi")
        subject.pdf?.should be_falsey
      end
    end
    describe "spreadsheet?" do
      it "should test for spreadsheet mimetypes" do
        subject.stub(:mime_type).and_return("audio/mpeg")
        subject.spreadsheet?.should be_falsey
        ["application/vnd.ms-excel", "application/vnd.oasis.opendocument.spreadsheet", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"].each do |mimetype|
          subject.stub(:mime_type).and_return(mimetype)
          subject.spreadsheet?.should be_truthy
        end
        subject.stub(:mime_type).and_return("video/avi")
        subject.spreadsheet?.should be_falsey
      end
    end
    
  end
end