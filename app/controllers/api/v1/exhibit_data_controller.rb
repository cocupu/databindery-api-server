class Api::V1::ExhibitDataController < Api::V1::DataController
  load_and_authorize_resource :exhibit, prepend:true
  load_and_authorize_resource :pool # This assumes that exhibit access is the same as pool access.  If that changes, remove this line!
end
