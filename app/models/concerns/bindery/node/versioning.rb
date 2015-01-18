module Bindery::Node::Versioning
  extend ActiveSupport::Concern

  module ClassMethods

  # Creates a new (unsaved) Node with the same attributes as the original_node, but new 'created_at', 'updated_at', and 'id'
  # @param [Node] original_node the node to copy
  # @param [Hash] attributes_overrides attributes that will be passed to update_attributes after copying this node.  This allows you to set modified_by, log, etc on the child node
  def copy(original_node, attributes_overrides={})
      original_node.send(:update_file_ids)  # Icky: Makes this module aware of internals of HasFiles module :-(
      n = Node.new
      copied_values = original_node.attributes.select {|k, v| !['created_at', 'updated_at', 'id'].include?(k) }
      copied_values[:parent_id] = original_node.id
      n.assign_attributes(copied_values)
      unless attributes_overrides.has_key?(:modified_by) || attributes_overrides.has_key?(:modified_by_id)
        attributes_overrides[:modified_by_id] = copied_values['modified_by_id']
      end
      n.assign_attributes(attributes_overrides)
      n
    end

    # Returns the node (version) where the latest file binding was set
    def version_with_latest_file_binding(persistent_id)
      self.versions(persistent_id).where(binding: self.latest_version(persistent_id).binding).last
    end
  end

  def versions
    Node.versions(persistent_id)
  end

  def latest_version
    Node.latest_version(persistent_id)
  end

  # Returns the node (version) where the current node's file binding was set
  def version_with_current_file_binding
    self.versions.where(binding: self.binding).last
  end
end