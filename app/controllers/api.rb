module Api
  module V1

    def self.generate_response_body(response_type,options={})
      self.default_responses[response_type].merge(options)
    end

    def self.default_responses
      {
          success: {
              code: 200,
              message: "Request Succeeded",
              description: I18n.t('success.default')
          },
          deleted: {
              code: 200,
              message: I18n.t('deleted.default')
          },
          accepted: {
              code: 202,
              message: "Accepted",
              description: I18n.t('accepted.default')
          },
          bad_request: {
              code: 400,
              message: "Bad Request",
              description: I18n.t('bad_request.default')
          },
          unauthorized: {
              code: 401,
              message: "Authentication Required",
              description: I18n.t('unauthorized.default')
          },
          forbidden: {
              code: 403,
              message: "Not Authorized",
              description: I18n.t('unauthorized.default')
          },
          not_found: {
              code: 404,
              message: "Resource not found",
              description: I18n.t('not_found.default')
          },
          unprocessable_entity: {
              code: 422,
              message: "Unprocessable Entity",
              description: I18n.t('unprocessable_entity.default'),
              errors: []
          }
      }
    end

  end

end