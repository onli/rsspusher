require 'rest_client'
require 'json'


# Class communicating with Yahoo Pipes. Basically only a wrapper to have proper function-names.
# As a convention, these functions here will not give the proper result, but the json/rss-data
# to get the proper result from.
class Pipe

    def getFeedURL(url)
        begin
            return JSON.parse(RestClient.get "http://pipes.yahoo.com/pipes/pipe.run", {:params => { :_id => "0fdbebb1f79888ae54aca294f434329c",
                                                                                                    :_render => "json",
                                                                                                    :url => url}})
        rescue => error
            puts "error getting feedURL-Pipe: #{error}"
        end
    end

    def getEntriesAfter(url, date, format)
        begin
            return JSON.parse(RestClient.get "http://pipes.yahoo.com/pipes/pipe.run", {:params => { :_id => "e87634cfeb5f508bbd5397d68a1b8c31",
                                                                                                :_render => format,
                                                                                                :url => url,
                                                                                                :date => date }})
        rescue => error
            puts "error getting EntriesAfter-Pipe: #{error}"
        end
    end

    def getLastPageUpdate(url)
        begin
            return JSON.parse(RestClient.get "http://pipes.yahoo.com/pipes/pipe.run", {:params => {:_id => "f19a20691088d9512ef67a3bef500e89",
                                                                                        :_render => "json",
                                                                                        :url => url}})
        rescue => error
            puts "error getting lastPageUpdate-Pipe: #{error}"
        end
    end
    
    def getLastFeedUpdate(url)
        begin
            return JSON.parse(RestClient.get "http://pipes.yahoo.com/pipes/pipe.run", {:params => {:_id => "43dfd827c6b34c871ca3a8476433d9a5",
                                                                                        :_render => "json",
                                                                                        :url => url}})
        rescue => error
            puts "error getting lastFeedUpdate-Pipe: #{error}"
        end
    end
end