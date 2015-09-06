class Api::V1::ExhibitDataController < Api::V1::DataController
  load_and_authorize_resource :exhibit, prepend:true
  load_resource :pool
  before_filter :require_query_permission # This assumes that exhibit access is the same as pool access.  If that changes, remove this line!
end
