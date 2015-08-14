RSpec.shared_examples "any request" do
  context "CORS requests" do
    it "should set the Access-Control-Allow-Origin header to allow CORS from anywhere" do
      expect(response.headers['Access-Control-Allow-Origin']).to be_in ["*", request.headers["origin"]]
    end

    it "should allow general HTTP methods thru CORS (GET/POST/PUT/DELETE)" do
      allowed_http_methods = response.header['Access-Control-Allow-Methods']
      expect(allowed_http_methods).to_not be_nil
      %w{GET POST PUT DELETE}.each do |method|
        expect(allowed_http_methods).to include(method)
      end
    end

    # etc etc
  end
end