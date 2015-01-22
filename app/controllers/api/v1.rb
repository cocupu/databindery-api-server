module API::V1

  def self.default_responses
    {
        unauthorized: {
            code: 401,
            message: "Authentication Required",
            description: "You must be logged in to do that!"
        },
        forbidden: {
            code: 403,
            message: "Not Authorized",
            description: "You are not authorized to access this content."
        },
        not_found: {
            code: 404,
            message: "Resource not found",
            description: "DataBindery could not find a resource that matches your request."
        }
    }
  end
end