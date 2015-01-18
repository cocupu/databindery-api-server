module Bindery::Node::Forking
  extend ActiveSupport::Concern

  # Creates a copy of the node with no data, marks it as a "fork" node so that data will be retrieved from parent node.
  # @param [Hash] attributes_overrides attributes that will be passed to update_attributes after copying this node.  This allows you to set pool, modified_by, log, etc on the child/fork node
  def fork(attributes_overrides={})
    # Always empty out the data in fork nodes.  Data will be read from parent node.
    attributes_overrides[:data] = nil
    child = Node.copy(self,attributes_overrides)
    child.is_fork = true
    child.save
    child
  end

  # Overrides data accessor so Fork nodes will work transparently
  def data
    retrieve_data
  end

  # Retrieves data from parent if this is a fork node.  Returns current data otherwise.
  def retrieve_data
    if is_fork?
      parent.data
    else
      self.read_attribute("data")
    end
  end
end
