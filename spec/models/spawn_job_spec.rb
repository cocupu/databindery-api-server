require 'rails_helper'

describe SpawnJob do
  describe "spreadsheet" do
    before do
      @version1 = FactoryGirl.create(:node, binding:"bindingXYZ", model: Model.file_entity)
      @version2 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
      @version3 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
      @version4 = FactoryGirl.create(:node, binding:"binding1", persistent_id:@version1.persistent_id, model: Model.file_entity)
    end
    it "should return the node version with current file binding" do
      subject.node = @version4
      ss = subject.spreadsheet
      ss.id.should == @version2.id
      ss.should be_instance_of Bindery::Spreadsheet
    end
  end
  describe "reify_rows" do
    before do
      @pool = FactoryGirl.create :pool
      @node = Bindery::Spreadsheet.create(pool: @pool, model: Model.file_entity)
      @model = FactoryGirl.create(:model, fields_attributes: [{code: 'wheels', name: 'Wheels'}])
      @mapping_template = MappingTemplate.new(owner: FactoryGirl.create(:identity))
      @mapping_template.model_mappings = [{:model_id=>@model.id, :field_mappings=> [{:source=>"B", :label=>"Wheels", :field=>"wheels"}, {:source=>"A", :label=>''}]}]
      @mapping_template.save!
      subject.mapping_template = @mapping_template
      subject.pool = @pool
    end
    after do
      Resque.remove_queue(Bindery::ReifyRowJob.queue)
    end
    it "should spawn from up xls spreadsheets" do
      @file  = File.new(Rails.root + 'spec/fixtures/dechen_rangdrol_archives_database.xls')
      @node.stub(:s3_obj).and_return(@file)
      @node.file_name = 'dechen_rangdrol_archives_database.xls'
      @node.mime_type = 'application/vnd.ms-excel'
      subject.stub(:spreadsheet).and_return(@node)
      original_versions = @node.versions
      parsed_sheet =  @node.parsed_sheet
      subject.reify_rows
      subject.reification_job_ids.count.should == 434
      sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids.last)
      sample_queued_job["options"]["row_content"].should == ["gcod-bouddha-1994-psc-te-9c-9", nil, nil, nil, "1994-03-31", 3514, 70.0, nil, nil, nil, nil, nil, nil]
      1.upto(parsed_sheet.last_row) do |row_idx|
        row_content = parsed_sheet.row(row_idx)
        sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids[row_idx-1])
        sample_queued_job["options"]["row_content"].should == row_content.as_json
        sample_queued_job["options"]["mapping_template"].should == @mapping_template.id
      end
      Node.versions(@node.persistent_id).count.should == original_versions.count
    end
    it "should spawn from xlsx spreadsheets" do
      @file  =File.new(Rails.root + 'spec/fixtures/KTGR Audio Collection Sample.xlsx')
      @node.stub(:s3_obj).and_return(@file)
      @node.file_name = 'KTGR Audio Collection Sample.xlsx'
      @node.mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      subject.stub(:spreadsheet).and_return(@node)
      original_versions = @node.versions
      subject.reify_rows
      subject.reification_job_ids.count.should == 18
      sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids[4])
      sample_queued_job["options"]["row_content"].should == [4.0, "Hanna Severin", "rgyud.bla.ma-wachendorf-1987-rfu-tg-2c", "Cassette Tape", 2.0, "Rosie Fuchs", "Hamburg", "Buddha Nature", "12. theg pa chen po rgyud bla ma'i bstan bcos : thogs med", "12. Buddha Nature", "Kamalashila Institute, Wachendorf, Germany", "24/10/1987", "1987-10-25", "24/10/1987", "1987-10-25", "KTGR", "No", "Rosie Fuchs", "original", "German", nil, "finished at 26.02.2012, the translation into German is not recorded, the end of talk 2, 25.11.87 is missing", nil]
      parsed_sheet =  @node.parsed_sheet
      1.upto(parsed_sheet.last_row) do |row_idx|
        row_content = parsed_sheet.row(row_idx)
        sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids[row_idx-1])
        sample_queued_job["options"]["row_content"].should == row_content.as_json
        sample_queued_job["options"]["mapping_template"].should == @mapping_template.id
      end
      Node.versions(@node.persistent_id).count.should == original_versions.count
    end
    it "should spawn from ODS spreadsheets" do
      @file = File.new(Rails.root + 'spec/fixtures/Stock Check 2.ods')
      # S3Object.read behaves like File.read, so returning a File as stub for the S3 Object
      @node.stub(:s3_obj).and_return(@file)
      @node.file_name = 'Stock Check 2.ods'
      @node.mime_type = 'application/vnd.oasis.opendocument.spreadsheet'
      subject.stub(:spreadsheet).and_return(@node)
      original_versions = @node.versions
      subject.reify_rows
      subject.reification_job_ids.count.should == 39
      sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids[1])
      sample_queued_job["options"]["row_content"].should == [nil, nil, "Reserves", "Production remains static", "Production continues to grow at current rates", "IMPORTANT: recycling rates vary from resource to resource (0-70%). The maths is super-complicated and frankly beyond us", "Column C: Minerals reserves worldwide in metric tonnes; fossil fuel reserves worldwide in barrels for oil, cubic metres for gas, tonnes of oil equivalent for coal.\n\nColumns D & E: Worldwide, rounded to nearest year, based on known reserves currently economic to extract. No provision made for changes in demand caused by new technologies, discoveries of new reserves or market forces (e.g. as they act on reserve sizes).", "NB mineral calculations based on production, fossil fuels on actual consumption"]
      # Skipping full row-by-row check for ODS file because parsing ODS files is really slow.
      #parsed_sheet =  @node.parsed_sheet
      #1.upto(parsed_sheet.last_row) do |row_idx|
      #  row_content = parsed_sheet.row(row_idx)
      #  sample_queued_job = Resque::Plugins::Status::Hash.get(subject.reification_job_ids[row_idx-1])
      #  sample_queued_job["options"]["row_content"].should == row_content.as_json
      #  sample_queued_job["options"]["mapping_template"].should == @mapping_template.id
      #end
      Node.versions(@node.persistent_id).count.should == original_versions.count
    end
    describe "in general" do
      before do
        @file  =File.new(Rails.root + 'spec/fixtures/KTGR Audio Collection Sample.xlsx')
        @node.stub(:s3_obj).and_return(@file)
        @node.file_name = 'KTGR Audio Collection Sample.xlsx'
        @node.mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        subject.stub(:spreadsheet).and_return(@node)
      end
      it "should respect the mapping_template row_start value" do
        @mapping_template.row_start = 11
        @mapping_template.save
        parsed_sheet =  @node.parsed_sheet
        subject.reify_rows
        subject.reification_job_ids.count.should == 9
      end
    end

  end

end
