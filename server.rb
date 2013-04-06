require 'sinatra'


require 'sinatra'
require 'json'
require 'nokogiri'
require 'securerandom'
require 'haml'

require './database.rb'
require './page.rb'

set :bind, "0.0.0.0"
set :server, "thin"
set :protection, except: :ip_spoofing
use Rack::Session::Pool

configure do
    pollThread = Thread.new() {
        while true
            puts "poll for updates"
            pages = Database.new.getPages(false)
            pages.each do |page|
                Thread.new() {
                    if page.hasUpdate?
                        page.notifySubscribers
                    end
                }
                sleep 1
            end
            sleep 3600
        end
    }

    leaseThread = Thread.new() {
        while true
            pages = Database.new.getPagesToRenew(3900)
            pages.each do |page|
                Thread.new() {
                    page.subscribe
                }
                sleep 1
            end
            sleep 3600
        end
    }
end

get '/' do
    # TODO: Describe the protocol here (test a different template-language than erb)
    haml :index
end

post '/watches' do
    puts "got watch request"
    data = JSON.parse(request.body.string)
    puts "data parsed"
    data["urls"].each{|url| puts "url: #{url}"}
    puts "callback: #{data["callback"]}"
    begin
        challenge = SecureRandom.hex(16)
        response = RestClient.get data["callback"], {:params => {:challenge => challenge}}
        puts "response: #{response}"
        if response != challenge
            throw(:halt, [401, "Echoed value didn't match challenge"])
        end
    rescue => error
        puts "error confirming subscription: #{error}"
        throw(:halt, [401, "An Error occured while confirming subscription (echo challenge)\n"])
    end
    data["urls"].each do |url|
        puts "Creating page for #{url}"
        Page.new(url, data["callback"])
    end
end

post '/pubsubhubbub' do
    Page.new(Nokogiri.XML(request.body).xpath('/rss/channel/link').text).notifySubscribers
end

get '/pubsubhubbub' do
    puts "got request to confirm PuSH"
    if Database.new.register?(params["hub.topic"]) || Database.new.isWatched?(params["hub.topic"])   # if already saved, this is a renewal
        puts "PuSH request valid"
        Database.new.finishRegisterRequest(params["hub.topic"], params["hub.lease_seconds"].to_i)
        return params["hub.challenge"]
    end
end

post '/rssCloud' do
    Page.new(params["origin"]).notifySubscribers
end

get '/rssCloud' do
    puts params
    if Database.new.register?(params["url"]) || Database.new.isWatched?(params["url"])
        Database.new.finishRegisterRequest(params["url"], 86400)    # rsscloud-subscriptions are always only valid for 24h
        return params["challenge"]
    end
end

get '/test' do
    return params["challenge"]
end