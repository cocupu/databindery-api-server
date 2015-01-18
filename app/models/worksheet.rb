class Worksheet < ActiveRecord::Base
  belongs_to :spreadsheet, class_name: 'Bindery::Spreadsheet'
  has_many :rows, class_name: 'SpreadsheetRow'

  # def reify(mapping_template, pool)
  #   start_col = mapping_template.row_start - 1
  #   work = self.rows[start_col..-1]
  #   ConcurrentJob.create().enqueue_collection(ReifyEachSpreadsheetRowJob, work, {:template_id=>mapping_template.id, :pool_id=>pool.id })
  # end

  def as_json(opts={})
    rows_start = opts[:start] ? opts[:start].to_i : 0
    number_of_rows = opts[:rows] ? opts[:rows].to_i : 10
    json = super
    json["numRows"] = rows.length
    json["rows"] = rows[rows_start..rows_start+number_of_rows].as_json
    json
  end
end
