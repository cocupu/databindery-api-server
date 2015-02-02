class SearchFilter < ActiveRecord::Base
  # Filterable might be an Exhibit, Audience, etc.  Anything that declares & applies filters.
  belongs_to :filterable, :polymorphic => true
  belongs_to :field
  serialize :values, Array

  include Bindery::Persistence::ElasticSearch::SearchFilter

end
