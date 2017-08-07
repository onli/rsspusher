require 'rest_client'
require 'json'


# This formerly offloaded work to Yahoo! Pipes. Now we do the work in this class.
# It might be better to integrate this into proper objects.
class Pipe

    def getFeedURL(url)
        begin
            page = RestClient.get url
            if page[0..50].include?('<html') || page[0..50].include?('<HTML')
            # we got a page link instead of a feed, but we can try to look for a linked feed
                doc = Nokogiri::HTML(page)
                origUrl = URI.parse(URI.escape(url))
                url = doc.css('link[rel="alternate"]').first['href']
                if (! url.include?('http://') && ! url.include?('https://') )
                    url = "#{origUrl.scheme}://#{origUrl.host}/" + url
                end
            end
            return url
        rescue => error
            puts "error getting feedURL-Pipe: #{error}"
        end
    end

    def getEntriesAfter(url, date, format)
        begin
            feedUrl = self.getFeedURL(url)
            feed = RestClient.get url
            feed = FeedParser::Parser.parse(feed)
            newItems = []
            feed.items.each do |item|
                if item.updated > date 
                    newItems.push({:title => item.title, :url => item.url, :content => item.content, :updated => item.updated})
                end
            end
            return JSON.generate(newItems)
        rescue => error
            puts "error getting EntriesAfter-Pipe: #{error}"
        end
    end

    def getLastPageUpdate(url)
        begin
            page = RestClient.get url
            feed = FeedParser::Parser.parse(page)
            return feed.update
        rescue => error
            puts "error getting lastPageUpdate-Pipe: #{error}"
        end
    end
    
    def getLastFeedUpdate(url)
        begin
            page = RestClient.get self.getFeedURL(url)
            feed = FeedParser::Parser.parse(page)
            return feed.updated
        rescue => error
            puts "error getting lastFeedUpdate-Pipe: #{error}"
        end
    end
end