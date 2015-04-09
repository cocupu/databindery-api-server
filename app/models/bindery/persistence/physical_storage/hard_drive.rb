class Bindery::Persistence::PhysicalStorage::HardDrive < ActiveRecord::Base
  include Bindery::Persistence::StorageContainer
  self.table_name = "hard_drives"
end