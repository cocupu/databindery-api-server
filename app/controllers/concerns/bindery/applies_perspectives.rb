module Bindery
  module AppliesPerspectives
    extend ActiveSupport::Concern

    included do
      #load_and_authorize_resource :exhibit
      before_filter :set_perspective, only:[:index]
      query_logic << :apply_filters_from_exhibit
    end

    def exhibit
      if @exhibit.nil?
        set_perspective
      end
      return @exhibit
    end

    # Sets the Exhibit to use for configuration
    def set_perspective
      if params[:perspective]
        if params[:perspective] == "0"
          @exhibit = @pool.generated_default_perspective
        else
          @exhibit = Exhibit.where(pool_id:@pool.id, id:params[:perspective]).first
        end
      end
      if @exhibit.nil?
        @exhibit = @pool.default_perspective
      end
    end

    # Apply search filter logic from current exhibit
    def apply_filters_from_exhibit(query_parameters, user_parameters)
      exhibit.apply_query_params_logic(query_parameters, user_parameters)
    end
  end
end