class Bindery::Persistence::AWS::Credentials < ActiveRecord::Base
  self.table_name = "aws_credentials"
end