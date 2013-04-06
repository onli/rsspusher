require 'rest_client'

class Hub

    def initialize(url)
        @url = url      # the url of the hub itself
        puts "hubURL: #{url}"

        # TODO: Set proper url
        @callback = "http://desolate-cove.eu01.aws.af.cm/pubsubhubbub"   # REQUIRED. The subscriber's callback URL where notifications should be delivered.
        @mode = "subscribe"    # REQUIRED. The literal string "subscribe" or "unsubscribe", depending on the goal of the request.
        @verify = "async"   # REQUIRED. Keyword describing verification modes supported by this subscriber, as described below. This parameter may be repeated to indicate multiple supported modes.
                        # The following keywords are supported for hub.verify:
                            # sync
                        # The subscriber supports synchronous verification, where the verification request must occur before the subscription request's HTTP response is returned.
                            # async
                        # The subscriber supports asynchronous verification, where the verification request may occur at a later point after the subscription request has returned.
        @lease_seconds = ""    # OPTIONAL. Number of seconds for which the subscriber would like to have the subscription active. If not present or an empty value, the subscription will be permanent (or active until automatic refreshing removes the subscription). Hubs MAY choose to respect this value or not, depending on their own policies. This parameter MAY be present for unsubscription requests and MUST be ignored by the hub in that case.
        @secret = ""   # OPTIONAL. A subscriber-provided secret string that will be used to compute an HMAC digest for authorized content distribution.
                      # If not supplied, the HMAC digest will not be present for content distribution requests. This parameter SHOULD only be specified when the request was made over HTTPS [RFC2818]. This parameter MUST be less than 200 bytes in length.
        @verify_token = ""   # OPTIONAL. A subscriber-provided opaque token that will be echoed back in the verification request to assist the subscriber in identifying which
                         # subscription request is being verified. If this is not included, no token will be included in the verification request.
    end
    
    # topic: REQUIRED. The topic URL that the subscriber wishes to subscribe to, the feed(!) URL
    def subscribe(topic)
        puts "making request to #{@url}"
        begin
            response = RestClient.post @url, "hub.callback" => @callback, "hub.mode" => @mode, "hub.verify" => @verify, "hub.topic" => topic
            puts response
            return true
        rescue => error
            puts "Error registering at hub: #{error}"
            puts error.response
            return false
        end
    end
end

