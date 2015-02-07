module Bindery::Persistence::Solr

  # Add documents to the index
  # Documents is a single solr document or array of solr documents
  def self.add_documents_to_index(documents)
    documents = Array.wrap(documents)
    documents.each do |doc|
      Bindery.solr.add doc
    end
    Bindery.solr.commit
  end
end