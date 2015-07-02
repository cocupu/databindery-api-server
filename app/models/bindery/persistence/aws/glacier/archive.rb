# Class for representing Glacier Archives as StorageContainers
# Attibutes
#   #vault_name
#   #account_id
# Associations
#   #aws_credentials Saved AWS::Credentials for accessing this Archive
#
# {"ArchiveId"=>
#      "5M-xwhuc2fCZ173Qmf60H57Pzsfwi7yyHwIlzo93tp12e18lKfrg_C2FF8UR8-tX8iV2IYu-eXLbn2BBQ1_RFJUfDpDg78eXzMJAj8uJes7Aiwi6gjX9tPkO30H8ISubvKRwg9af9Q",
#  "ArchiveDescription"=>"1991 - 2004 archive [DISK:GMFC7]",
#  "CreationDate"=>"2013-11-30T01:34:00Z",
#  "Size"=>1500301910016,
#  "SHA256TreeHash"=>
#      "1ddafc1d67f81c5f316b80eb4f24e150f63bb8ce7e02af46b60bdc5e6c6df28f"}
class Bindery::Persistence::AWS::S3::Archives < Bindery::Persistence::StorageContainer
  self.table_name = "glacier_archives"
  belongs_to :aws_credentials
end