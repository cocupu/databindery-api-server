require 'spec_helper'

describe Api::V1::SpreadsheetsController do
  describe "show" do
    describe "when not logged in" do
      it "should require authentication"
    end
    describe "when logged in" do
      it "should render json for requested rows"
      describe "when requesting content I don't own" do
        it "should forbid access"
      end
    end

  end

end
