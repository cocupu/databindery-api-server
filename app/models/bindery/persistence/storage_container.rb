# Abstract Class for Storage Containers
# Example: S3 Buckets, Glacier Archives, Hard Drives, Google Drive Accounts, etc.
# Implementation Note:
#   Due to the fact that the essential characteristics of different types of StorageContainers vary widely
#   They are each implemented as their own ActiveRecord model with its own table (as opposed to single-table inheritance)
#
# Required Attributes:
#   #name name of the StorageContainer
#   #description basic description of the StorageContainer
# Required Methods:
#   #contents returns the Nodes representing the files within the StorageContainer
#   #metadata returns the Node(s) containing metadata that describe(s) the StorageContainer itself
class Bindery::Persistence::StorageContainer

end