### Non-namespaced version is used by roo
class Bindery::Spreadsheet < Node
  include FileEntity

  def self.detect_type(node)
    case node.mime_type
    when "application/vnd.ms-excel"
      Roo::Excel
    when "application/vnd.oasis.opendocument.spreadsheet"
      Roo::OpenOffice
    when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      Roo::Excelx
    else
      raise "UnknownType: #{node.mime_type}"
    end
  end

  def parsed_sheet
    @parsed_sheet ||= parse_sheet
  end

  def parse_sheet
    type = Bindery::Spreadsheet.detect_type(self)
    begin
      parsed_sheet = type.new(local_file_pathname)
    rescue IOError
      generate_tmp_file
      parsed_sheet = type.new(local_file_pathname)
    end
    return parsed_sheet
  end

  def as_json(opts={})
    rows_start = opts[:start] ? opts[:start].to_i : 1
    number_of_rows = opts[:rows] ? opts[:rows].to_i : 5
    json = super
    json["request"] = {}
    json["request"]["rowStart"] = rows_start
    json["request"]["numRows"] = number_of_rows
    json["totalRows"] = parsed_sheet.last_row
    json["rows"] = []
    rows_start.upto(rows_start+number_of_rows) do |row_idx|
      json["rows"] << parsed_sheet.row(row_idx)
    end
    json
  end
  # Returns the node (version) where the latest file binding was set
  def self.version_with_latest_file_binding(persistent_id)
    node = self.versions(persistent_id).where(binding: self.latest_version(persistent_id).binding).select("created_at, binding, id, persistent_id, model_id").last
    return  Bindery::Spreadsheet.find_by_identifier(node.id)
  end

  # Returns the node (version) where the current node's file binding was set
  def version_with_current_file_binding
    node = self.versions.where(binding: self.binding).select("created_at, binding, id, persistent_id, model_id").last
    return  Bindery::Spreadsheet.find_by_identifier(node.id)
  end


end
