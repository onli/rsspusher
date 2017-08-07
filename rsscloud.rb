

class RssCloud
    def initialize(url)
        @url = url      # the url of the hub itself
    end

    def subscribe(topic)
        puts "making request to #{@url}"
        begin
            response = RestClient.post @url, :port  => 80,
                                             :path => "/rssCloud",
                                             :domain => "http://desolate-cove.eu01.aws.af.cm",  # TODO: Proper url
                                             :notifyProcedure => "",
                                             :protocol =>  "http-post",
                                             :url1 => topic 
            puts response
            puts Nokogiri.XML(response).xpath("/notifyResult").attr("success")
            return Nokogiri.XML(response).xpath("/notifyResult").attr("success") == "true"
        rescue => error
            puts "Error registering at rsscloud-hub: #{error}"
            puts error.response
            return false
        end
    end

end