require 'rest_client'
require 'json'
require 'nokogiri'

require './database.rb'
require './pubsubhubbub.rb'
require './rsscloud.rb'
require './pipe.rb'

class Page
    attr_accessor :url, :callback

    # url: The page, note that this is not the feed
    # callback: The URL to ping if there is a new post
    def initialize(*args)
        self.url = args[0].sub("https", "http") if args[0]
        self.callback = args[1] if args[1]

        if args.length == 2
            ! self.isFeed? and Database.new.setFeedURL(self.getFeedURL, url)
        end
    end

    def subscribe
        pubsubhub, rssCloud = self.getSubscribeOptions
        topic = self.getFeedURL
        if pubsubhub
            Database.new.toRegister(topic)
            success = Hub.new(pubsubhub).subscribe(topic)
            return success if success
        end

        if rssCloud
            Database.new.toRegister(topic)
            success = RssCloud.new(rssCloud).subscribe(topic)
            return success if success
        end
        return false
    end

    def getFeedURL
        if ! @feedURL
            begin
                @feedURL = Pipe.new.getFeedURL(self.url)["value"]["items"][0]["link"].sub("https", "http")
            rescue => error
                puts "error getting feedUrl: #{error}"
                @feedURL = nil
            end
        end
        return @feedURL
    end

    def isFeed?
        if self.getFeedURL
            return false       # if it has a feed-url, it itself can't be a feed 
        end
        begin
            if Pipe.new.getEntriesAfter(self.url, 0, "json")["count"] > 0
                return true     # if yahoo finds entries, this is a valid feed
            end
        rescue => error
            puts error
        end
        return false
    end

    def getSubscribeOptions
        feedURL = self.getFeedURL
        feed = RestClient.get(feedURL)
        rssCloudNode = Nokogiri::XML(feed).xpath('/rss/channel/cloud')
        begin
            pubSubHubNode = Nokogiri::XML(feed).xpath('/rss/channel/atom:link').map do |link|
                if link.attr("rel") == "hub"
                    link
                end
            end.compact[0]
        rescue Nokogiri::XML::XPath::SyntaxError => error
            puts "No PuSH-link found in #{feedURL}: #{error}"
            pubSubHubNode = nil
        end

       
        rssCloud, pubSubHub = nil
        # for now, assume that the method for rss/cloud is http/post like on wordpress.com
        begin
            rssCloud = rssCloudNode.attr("domain").to_s + ":" + rssCloudNode.attr("port").to_s  + rssCloudNode.attr("path").to_s
        rescue NoMethodError => error
            puts error
        end
        begin
            pubSubHub = pubSubHubNode.attr("href").to_s if pubSubHubNode
        rescue NoMethodError => error
            puts error
        end
        
        return pubSubHub, rssCloud
    end

    def hasUpdate?
        begin
            if Time.parse(self.getLastUpdate).to_i > Database.new.getLastUpdate(self.url)
                return true
            end
        rescue => error
            puts "error checking for update: #{error}"
        end
        return false
    end

    def notifySubscribers
        begin
            newEntries = Pipe.new.getEntriesAfter(self.getFeedURL, Time.at(Database.new.getLastUpdate(self.url)).rfc2822, "json")
        rescue => error
            puts "error getting new entries: #{error}"
        end
        Database.new.setLastUpdate(self.url, self.getLastUpdate)
        Database.new.getCallbacks(self.url).each do |callback|
            begin
                RestClient.post callback, {:url => self.url, :newEntries => newEntries}
            rescue => error
                puts "error notifying #{callback} of #{url}: #{error}"
            end
        end
    end

    def getLastUpdate
        begin
            return Pipe.new.getLastPageUpdate(self.url)["value"]["items"][0]["content"]
        rescue => error
            puts "couldn't get page update: #{error}"
            begin
                return Pipe.new.getLastFeedUpdate(self.url)["value"]["items"][0]["content"]
            rescue => error2
                puts "couldn't get feed update2: #{error2}"
            end
        end
    end

    def save(success)
        Database.new.savePage(self, success)
        Database.new.setLastUpdate(self.url, self.getLastUpdate)     # older posts aren't new just because we didnt see them before
    end

    def delete
        Database.new.deletePage(self)
    end
end