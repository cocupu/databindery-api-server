require 'rails_helper'

describe Field do
  it "should create" do
    Field.create("name"=>"Description", "type"=>"TextField", "uri"=>"dc:description", "code"=>"description")
  end
end
