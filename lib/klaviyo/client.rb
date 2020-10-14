require 'open-uri'
require 'base64'
require 'json'
require 'httparty'

module Klaviyo
  class KlaviyoError < StandardError; end
  
  class Client
    include HTTParty
    BASE_URL = 'https://a.klaviyo.com/'
    base_uri BASE_URL

    def initialize(api_key, private_api_key)
      @api_key = api_key
      @private_api_key = private_api_key
      @url = BASE_URL
    end
    
    def track(event, kwargs = {})
      defaults = {:id => nil, :email => nil, :properties => {}, :customer_properties => {}, :time => nil}
      kwargs = defaults.merge(kwargs)
      
      if kwargs[:email].to_s.empty? and kwargs[:id].to_s.empty?
        raise KlaviyoError.new('You must identify a user by email or ID')
      end
      
      customer_properties = kwargs[:customer_properties]
      customer_properties[:email] = kwargs[:email] unless kwargs[:email].to_s.empty?
      customer_properties[:id] = kwargs[:id] unless kwargs[:id].to_s.empty?

      params = {
        :token => @api_key,
        :event => event,
        :properties => kwargs[:properties],
        :customer_properties => customer_properties,
        :ip => ''
      }
      params[:time] = kwargs[:time].to_time.to_i if kwargs[:time]
     
      params = build_params(params)
      request('api/track', params)
    end
    
    def track_once(event, opts = {})
      opts.update('__track_once__' => true)
      track(event, opts)
    end
    
    def identify(kwargs = {})
      defaults = {:id => nil, :email => nil, :properties => {}}
      kwargs = defaults.merge(kwargs)
      
      if kwargs[:email].to_s.empty? and kwargs[:id].to_s.empty?
        raise KlaviyoError.new('You must identify a user by email or ID')
      end
      
      properties = kwargs[:properties]
      properties[:email] = kwargs[:email] unless kwargs[:email].to_s.empty?
      properties[:id] = kwargs[:id] unless kwargs[:id].to_s.empty?

      params = build_params({
        :token => @api_key,
        :properties => properties
      })
      request('api/identify', params)
    end

    def subscribe_to_list(kwargs = {})
      if kwargs[:list_id].to_s.empty? || kwargs[:profiles].empty?
        raise KlaviyoError.new('You must provide a list id and profile(s)')
      end

      process_request_v2(action: 'post', url: "list/#{kwargs[:list_id]}/members", params: {
        profiles: kwargs[:profiles]
      })
    end

    def get_lists()
      process_request_v2(url: 'lists')
    end

    private

    attr_accessor :sleep_delay, :throttled

    def build_params(params)
      "data=#{CGI.escape Base64.encode64(JSON.generate(params)).gsub(/\n/,'')}"
    end
    
    def request(path, params)
      url = "#{@url}#{path}?#{params}"
      open(url).read == '1'
    end

    def process_request_v2(action: 'get', params: {}, url:)
      params[:api_key] = @private_api_key
      headers = {
        'Content-Type' => 'application/json'
      }

      begin
        self.throttled = false
        response = nil

        # post or get from API and process the response
        if action == 'post'
          response = self.class.post("/api/v2/#{url}", headers: headers, body: params.to_json)
        else
          response = self.class.get("/api/v2/#{url}", headers: headers, query: params)
        end

        process_response(response)
      rescue => exception
        # we hit a rate limit error so sleep and retry
        if throttled
          sleep(sleep_delay)
          retry
        else
          return exception
        end
      end
    end

    def process_response(response)
      if response.code == 200
        return JSON.parse(response.body)
      else
        # figure out how long we were throttled and sleep a little past the time given
        if response.code == 429 && response['detail'] =~ /throttled/
          self.throttled = true
          self.sleep_delay = response['detail'].scan(/\d+/).first.to_i + 1
        end

        raise KlaviyoError.new("#{response.message}: #{response['detail']}")
      end
    end
  end
end
