# Be sure to restart your server when you modify this file.
Mime::Type.register 'audio/mpeg' , :mp3
Mime::Type.register 'audio/ogg' , :ogg

# http://www.ietf.org/rfc/rfc4627.txt
# http://www.json.org/JSONRequest.html
Mime::Type.register "application/json", :json, %w( text/x-json application/jsonrequest )


# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone
