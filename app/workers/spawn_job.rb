class SpawnJob < ActiveRecord::Base
  belongs_to :mapping_template
  belongs_to :node
  belongs_to :pool

  def spreadsheet
    @spreadsheet ||= Bindery::Spreadsheet.find_by_identifier(node.version_with_current_file_binding.id)
  end

  def reify_rows
    row_start = mapping_template.row_start ? mapping_template.row_start-1 : 1
    row_start.upto(spreadsheet.parsed_sheet.last_row) do |row_idx|
      row_content = spreadsheet.parsed_sheet.row(row_idx)
      reification_job_ids <<  Bindery::ReifyRowJob.create(pool:pool.id, source_node:spreadsheet.id, mapping_template:mapping_template.id, row_index:row_idx, row_content:row_content.as_json)
    end
    return reification_job_ids
  end

  def reification_job_ids
    @reification_job_ids ||= []
  end

  def reification_jobs
    reification_job_ids.map {|job_id| Resque::Plugins::Status::Hash.get(job_id) }
  end
end
