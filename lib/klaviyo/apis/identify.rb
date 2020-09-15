module Klaviyo
  class Identify < Client
    # Used for identifying customers and managing profile properties
    #
    # @kwarg :id [String] the customer or profile id
    # @kwarg :email [String] the customer or profile email
    # @kwarg :properties [Hash] properties of the profile to add or update
    def self.identify(kwargs = {})
      defaults = {:id => nil, :email => nil, :properties => {}}
      kwargs = defaults.merge(kwargs)

      if kwargs[:email].to_s.empty? and kwargs[:id].to_s.empty?
        raise KlaviyoError.new('You must identify a user by email or ID')
      end

      properties = kwargs[:properties]
      properties[:email] = kwargs[:email] unless kwargs[:email].to_s.empty?
      properties[:id] = kwargs[:id] unless kwargs[:id].to_s.empty?

      params = {
        :token => @api_key,
        :properties => properties
      }

      request('GET', 'identify', params)
    end
  end
end