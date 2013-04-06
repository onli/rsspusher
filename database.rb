#require 'sqlite3'
require 'pg'
require 'json'


class Database
    def initialize()
        #begin
            #@db    # create a singleton - if this class-variable is uninitialized, this will fail and can then be initialized
        #rescue
            #@db = SQLite3::Database.new "rssnotifier.db"
            require "pg"
            services = JSON.parse(ENV['VCAP_SERVICES'])
            postgresql_key = services.keys.select { |svc| svc =~ /postgresql/i }.first
            postgresql = services[postgresql_key].first['credentials']
            postgresql_conn = {:host => postgresql['hostname'], :port => postgresql['port'], :user => postgresql['user'], :password => postgresql['password'], :dbname => postgresql['name']}
            @db = PG.connect(postgresql_conn)

            # heroku
            #db = URI.parse(ENV['DATABASE_URL'] || 'postgres://kstfqxrrfxxgxo:Szo6wnDAO5pkC9TowTlraYRdlb@ec2-54-243-235-100.compute-1.amazonaws.com:5432/ddo4jn3fk5j55e')
            #@db = PG::Connection.open(:dbname => db.path[1..-1], :user => db.user, :password => db.password, :port => db.port, :host => db.host, :sslmode => 'require')
            # local
            #@db = PG::Connection.open(:dbname => 'onli', :user => 'onli', :port => 5433)

            begin
                puts "creating Database"
                #@db.execute "CREATE TABLE IF NOT EXISTS watches(
                                #url TEXT,
                                #callback TEXT,
                                #subscribed INTEGER DEFAULT 0,
                                #leaseTill INTEGER DEFAULT NULL,
                                #UNIQUE(url, callback)
                                #);"
                @db.exec "CREATE TABLE IF NOT EXISTS watches(
                                url TEXT,
                                callback TEXT,
                                subscribed INTEGER DEFAULT 0,
                                leaseTill INTEGER DEFAULT NULL,
                                UNIQUE(url, callback)
                                );"
                #@db.execute "CREATE TABLE IF NOT EXISTS updates(
                                #url TEXT PRIMARY KEY,
                                #lastUpdate INTEGER DEFAULT 0
                                #);"
                @db.exec "CREATE TABLE IF NOT EXISTS updates(
                                url TEXT PRIMARY KEY,
                                lastUpdate INTEGER DEFAULT 0
                                );"
                #@db.execute "CREATE TABLE IF NOT EXISTS feeds(
                                #feedURL TEXT PRIMARY KEY,
                                #url TEXT
                                #);"
                @db.exec "CREATE TABLE IF NOT EXISTS feeds(
                                feedURL TEXT PRIMARY KEY,
                                url TEXT
                                );"
                #@db.execute "CREATE TABLE IF NOT EXISTS register_pending(
                                #url TEXT PRIMARY KEY
                                #);"
                @db.exec "CREATE TABLE IF NOT EXISTS register_pending(
                                url TEXT PRIMARY KEY
                                );"
                #@db.execute "PRAGMA foreign_keys = ON;"
                #@db.results_as_hash = true
            rescue => error
                puts "error creating tables: #{error}"
            end
        #end
    end


    def savePage(page, subscribed)
        begin
            #@db.execute("INSERT INTO watches(url, callback, subscribed) VALUES(?, ?, ?)", page.url, page.callback, subscribed ? 1 : 0)
            @db.exec("INSERT INTO watches(url, callback, subscribed) VALUES($1, $2, $3)", [page.url, page.callback, subscribed ? 1 : 0])
        rescue => error
            puts "error saving page: #{error}"
        ensure
            @db.finish
        end
    end

    def setLastUpdate(url, lastUpdate)
        begin
            lastUpdate = Time.parse(lastUpdate).to_i    # store time as unixtime
            #@db.execute("INSERT OR REPLACE INTO updates(url, lastUpdate) VALUES(?, ?)", url, lastUpdate)
            @db.exec("UPDATE updates SET lastUpdate = $1 WHERE url = $2", [lastUpdate, url])
            @db.exec("INSERT INTO updates(url, lastUpdate) VALUES($1, $2)", [url, lastUpdate])
         rescue => error
            puts "error setting lastUpdate: #{error}"
        ensure
            @db.finish
        end
    end

    def getLastUpdate(url)
        begin
            #return Time.at(@db.execute("SELECT lastUpdate FROM updates WHERE url = ?", url)[0]['lastUpdate']).to_i
            return Time.at(@db.exec("SELECT lastUpdate FROM updates WHERE url = $1", [url])[0]['lastUpdate']).to_i
         rescue => error
            puts "error getting lastUpdate: #{error}"
            puts "return 0"
            return 0
        ensure
            @db.finish
        end
    end

    def getCallbacks(url)
        begin
            callbacks = []
            #@db.execute('  SELECT
                                #callback
                            #FROM
                                #watches as w
                                #LEFT JOIN
                                    #feeds AS f
                                    #ON (w.url = f.url)
                            #WHERE w.url = ? OR f.feedURL = ?',
                            #url, url) do |row|
                            #callbacks.push(row["callback"])
            #end
            @db.exec('  SELECT
                                callback
                            FROM
                                watches as w
                                LEFT JOIN
                                    feeds AS f
                                    ON (w.url = f.url)
                            WHERE w.url = $1 OR f.feedURL = $1',
                            [url]) do |results|
                results.each do |row|
                    callbacks.push(row["callback"])
                end
            end
            return callbacks
        rescue => error
            puts "error getting callbacks: #{error}"
        ensure
            @db.finish
        end
    end

    def getPages(subscribed)
        begin
            pages = []
            #@db.execute('SELECT DISTINCT url FROM watches WHERE subscribed = ?', subscribed ? 1 : 0) do |row|
                #pages.push(Page.new(row["url"]))
            #end
            @db.exec('SELECT DISTINCT url FROM watches WHERE subscribed = $1', [subscribed] ? [1] : [0]) do |results|
                results.each do |row|
                    pages.push(Page.new(row["url"]))
                end
            end
            return pages
        rescue => error
            puts "error getting pages: #{error}"
        ensure
            @db.finish
        end
    end

    def setFeedURL(feedURL, url)
        begin
            #@db.execute("INSERT INTO feeds (feedURL, url) VALUES(?, ?)", feedURL, url)
            @db.exec("INSERT INTO feeds (feedURL, url) VALUES($1, $2)", [feedURL, url])
        rescue => error
            puts "error saving feed: #{error}"
        ensure
            @db.finish
        end
    end

    def toRegister(url)
        begin
            #@db.execute("INSERT INTO register_pending(url) VALUES(?)", url)
            @db.exec("INSERT INTO register_pending(url) VALUES($1)", [url])
        rescue => error
            puts "error adding #{url} to register_pending: #{error}"
        ensure
            @db.finish
        end
    end

    def register?(url)  
        begin
            #return @db.execute("SELECT COUNT(url) FROM register_pending WHERE url = ?", url)[0]["COUNT(url)"] > 0
            return @db.exec("SELECT COUNT(url) FROM register_pending WHERE url = $1", [url])[0]["count"].to_i > 0
        rescue => error
            puts "error checking register_pending for #{url}: #{error}"
            return false
        ensure
            @db.finish
        end
    end

    def finishRegisterRequest(url, leaseSeconds)
        puts "finish register"
        begin
            #@db.execute("DELETE FROM register_pending WHERE url = ?", url)
            @db.exec("DELETE FROM register_pending WHERE url = $1", [url])
            puts "deleted from register_pending"
        rescue => error
            puts "error clearing #{url} from register_pending: #{error}"
        end
        puts leaseSeconds
        if leaseSeconds > 0
            puts "leaseSeconds > 0"
            self.setLeaseSeconds(url, leaseSeconds)
        end
        @db.finish
    end

    def setLeaseSeconds(url, leaseSeconds)
        puts "set lease seconds"
        begin
            if leaseSeconds > 0
                #@db.execute("UPDATE
                                #watches
                            #SET
                                #leaseTill = strftime('%s', 'now') + ?
                            #WHERE
                                #url = ?
                            #OR
                                #? = (SELECT url FROM feeds WHERE feedURL = ?)", leaseSeconds, url, url, url)
                now = Time.now.to_i
                leaseTill = now + leaseSeconds;
                puts leaseTill
                @db.exec("UPDATE
                                watches
                            SET
                                leaseTill = $1
                            WHERE
                                url = $2
                            OR
                                $2 = (SELECT url FROM feeds WHERE feedURL = $2)", [leaseTill, url])
                puts "leaseTill updated"
            end
        rescue => error
            puts "error setting leaseSeconds: #{error}"
            return false
        ensure
            @db.finish
        end
    end

    def isWatched?(url)
        begin
            #return @db.execute("SELECT
                                #COUNT('url')
                            #FROM
                                #watches as w
                                #LEFT JOIN
                                    #feeds AS f
                                    #ON (w.url = f.url)
                            #WHERE w.url = ? OR f.feedURL = ?'", url)[0]["COUNT(url)"] > 0
            return @db.exec("SELECT
                                COUNT('url')
                            FROM
                                watches as w
                                LEFT JOIN
                                    feeds AS f
                                    ON (w.url = f.url)
                            WHERE w.url = $1 OR f.feedURL = $1", [url])[0]["count"].to_i > 0
        rescue => error
            puts "error checking if isWatched? for #{url}: #{error}"
        ensure
            @db.finish
        end
    end

    def getPagesToRenew(window)
        begin
            now = Time.now.to_i
            pages = []
            #@db.execute("SELECT url FROM watches WHERE leaseTill < ?", now + window) do |row|
                #pages.push(Page.new(row["url"]))
            #end
            @db.exec("SELECT url FROM watches WHERE leaseTill < $1", [now + window]) do |results|
                results.each do |row|
                    pages.push(Page.new(row["url"]))
                end
            end
            return pages
        rescue => error
            puts "error getting pages to renew: #{error}"
        ensure
            @db.finish
        end
    end


end