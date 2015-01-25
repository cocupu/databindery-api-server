class Api::V1::SpreadsheetsController < ApplicationController
  load_and_authorize_resource :pool, :find_by => :short_name, :through=>:identity
  load_resource class: Bindery::Spreadsheet
  def show
    render json: @spreadsheet.as_json(params.permit(:start, :rows))
  end
end
