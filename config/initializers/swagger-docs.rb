class Swagger::Docs::Config
    def self.base_api_controller; ActionController::API end
    def self.transform_path(path, api_version)
        # Make a distinction between the APIs and API documentation paths.
        "api-docs/#{path}"
    end
end
if Rails.env == 'development'
    base_path_for_env = 'http://localhost:3000/'
elsif Rails.env == 'production'
    base_path_for_env = 'http://bindery.cocupu.com/'
else
    base_path_for_env = "localhost"
end
Swagger::Docs::Config.register_apis({
    "v1" => {
        # the extension used for the API
        :api_extension_type => :json,
        # the output location where your .json files are written to
        :api_file_path => "public/api-docs/",
        # the URL base path to your API
        :base_path => base_path_for_env,
        # if you want to delete all .json files at each generation
        :clean_directory => false,
        :controller_base_path => "",
        # add custom attributes to api-docs
        :attributes => {
            :info => {
                "title" => "Explore the DataBindery API",
                "description" => "DataBindery is an API platform for curating data and files.  These docs give you a live connection to the API.  Enter the email and password for your DataBindery account and submit requests from the interactive documentation.",
                "termsOfServiceUrl" => "http://databindery.com/terms",
                "contact" => "apiteam@databindery.com",
                "license" => "Apache 2.0",
                "licenseUrl" => "http://www.apache.org/licenses/LICENSE-2.0.html"
            }
        }
    }
})