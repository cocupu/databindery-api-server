module Bindery::Persistence::Solr::Node
  extend ActiveSupport::Concern

  included do
    after_save :update_index
    after_destroy :remove_from_index
  end

  module ClassMethods
    def default_mapper
      @default_mapper ||= Solrizer::FieldMapper.new
    end

    # Index-agnostic method for generating the appropriate field name to use in index documents.
    def field_name_for_index(field, args = {})
      solr_name(field, args)
    end

    # @param field [Field or String] Either the field or its field_name
    # @param args [Hash] accepts :type and :multivalue.  These will be read from the field if it's provided, but values provided here have precedence
    def solr_name(field, args = {})
      if field.kind_of? Field
        field_name = field.code
        args[:multivalue] ||= field.multivalue
        args[:type] ||= field.type
      else
        field_name = field
      end
      if ["model_name", "model", "*"].include?(field_name)
        return field_name
      end

      case args[:type]
        when "facet"
          data_type = args[:type] || :string
          indexing_strategy = :facetable
        when "OrderedListAssociation"
          data_type = :string
          indexing_strategy = :facetable
        when "TextArea"
          data_type = :text
        when "TextField"
          data_type = :string
        when "DateField"
          data_type = :date
        when "IntegerField"
          data_type = :integer
        else
          data_type = args[:type] || :string
      end

      if indexing_strategy.nil?
        if args[:multivalue]
          indexing_strategy = :stored_searchable
        else
          indexing_strategy = :stored_sortable
        end
      end

      prefix= args[:prefix] || ''
      normalized_field_name = field_name.downcase.gsub(/\s+/,'_')
      return prefix + default_mapper.solr_name( normalized_field_name, indexing_strategy, type: data_type.to_sym )
    end

  end


  # Module Methods

  def remove_from_index
    Bindery.solr.delete_by_id self.persistent_id
    Bindery.solr.commit
  end

  def update_index
    Bindery.index(self.as_index_document)
    Bindery.solr.commit
  end

  # Index-agnostic method for rendering the node as a document to be indexed.
  def to_solr
    as_index_document
  end

  # Create a solr document for all the attributes as well as all the associations
  def as_index_document()
    doc = {'format'=>'Node', 'title'=> title, 'id' => persistent_id, 'version'=>id, 'model' => model.id, 'model_name' => model.name, 'pool' => pool_id}
    doc.merge!(solr_attributes)
    doc.merge!(solr_associations)
    doc
  end

  # Solrize all the associated models (denormalize) onto this record
  # For example, if this object is a book, you will be able to search by the associated author's name
  def solr_associations
    doc = {}
    # update_file_ids
    model.association_fields.each do |f|
      instances = find_association(f.to_param)
      next unless instances
      doc["bindery__associations_sim"] ||= []
      instances.each do |instance|
        doc["bindery__associations_sim"] << instance.persistent_id
        facet_name_for_association = Node.solr_name(f.code, type: 'facet', multivalue:true)
        doc[facet_name_for_association] ||= []
        doc[facet_name_for_association] << instance.title
        field_name_for_association = Node.solr_name(f.code, multivalue:true)
        doc[field_name_for_association] ||= []
        doc[field_name_for_association] << instance.title
        instance.solr_attributes(f.code + '__', multivalue:true).each do |k, v|
          doc[k] ||= []
          doc[k] << v
        end
      end
    end
    doc
  end

  # Produce the part of the solr document that is just the model attributes
  def solr_attributes(prefix = "", opts={})
    doc = {}
    return doc if data.nil?
    model.fields.each do |f|
      val = f.sanitize(data[f.to_param])
      if opts[:multivalue]
        f['multivalue'] = true
      end
      if val
        doc[Node.solr_name(f, prefix: prefix)] = val
        doc[Node.solr_name(f, type: 'facet', prefix: prefix)] = val
      end
    end
    doc
  end

end
