require 'sqlite3'
require 'json'


class Database
    def initialize()
        @db = SQLite3::Database.new "rssnotifier.db"

        begin
            @db.execute "CREATE TABLE IF NOT EXISTS watches(
                            url TEXT,
                            callback TEXT,
                            subscribed INTEGER DEFAULT 0,
                            leaseTill INTEGER DEFAULT NULL,
                            UNIQUE(url, callback)
                            );"

            @db.execute "CREATE TABLE IF NOT EXISTS updates(
                            url TEXT PRIMARY KEY,
                            lastUpdate INTEGER DEFAULT 0
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS feeds(
                            feedURL TEXT PRIMARY KEY,
                            url TEXT
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS register_pending(
                            url TEXT PRIMARY KEY
                            );"
            
        rescue => error
            puts "error creating tables: #{error}"
        end

        @db.execute "PRAGMA foreign_keys = ON;"
        @db.results_as_hash = true
    end


    def savePage(page, subscribed)
        begin
            @db.execute("INSERT INTO watches(url, callback, subscribed) VALUES(?, ?, ?)", page.url, page.callback, subscribed ? 1 : 0)
        rescue => error
            puts "error saving page: #{error}"
        end
    end

    def setLastUpdate(url, lastUpdate)
        begin
            lastUpdate = Time.parse(lastUpdate).to_i    # store time as unixtime
            @db.execute("INSERT OR REPLACE INTO updates(url, lastUpdate) VALUES(?, ?)", url, lastUpdate)
         rescue => error
            puts "error setting lastUpdate: #{error}"
        end
    end

    def getLastUpdate(url)
        begin
            return @db.execute("SELECT lastUpdate FROM updates WHERE url = ?", url)[0]['lastUpdate'].to_i
         rescue => error
            puts "error getting lastUpdate: #{error}"
            puts "return 0"
            return 0
        end
    end

    def getCallbacks(url)
        begin
            callbacks = []
            @db.execute('  SELECT
                                callback
                            FROM
                                watches as w
                                LEFT JOIN
                                    feeds AS f
                                    ON (w.url = f.url)
                            WHERE w.url = ? OR f.feedURL = ?',
                            url, url) do |row|
                            callbacks.push(row["callback"])
            end
            return callbacks
        rescue => error
            puts "error getting callbacks: #{error}"
        end
    end

    def getPages(subscribed)
        begin
            pages = []
            @db.execute('SELECT DISTINCT url FROM watches WHERE subscribed = ?', subscribed ? 1 : 0) do |row|
                pages.push(Page.new(row["url"]))
            end
            return pages
        rescue => error
            puts "error getting pages: #{error}"
        end
    end

    def setFeedURL(feedURL, url)
        begin
            @db.execute("INSERT INTO feeds (feedURL, url) VALUES(?, ?)", feedURL, url)
        rescue => error
            puts "error saving feed: #{error}"
        ensure
            @db.finish
        end
    end

    def toRegister(url)
        begin
            @db.execute("INSERT INTO register_pending(url) VALUES(?)", url)
        rescue => error
            puts "error adding #{url} to register_pending: #{error}"
        end
    end

    def register?(url)  
        begin
            return @db.execute("SELECT COUNT(url) FROM register_pending WHERE url = ?", url)[0]["COUNT(url)"] > 0
        rescue => error
            puts "error checking register_pending for #{url}: #{error}"
            return false
        end
    end

    def finishRegisterRequest(url, leaseSeconds)
        begin
            @db.execute("DELETE FROM register_pending WHERE url = ?", url)
        rescue => error
            puts "error clearing #{url} from register_pending: #{error}"
        end

        if leaseSeconds > 0
            self.setLeaseSeconds(url, leaseSeconds)
        end
        @db.finish
    end

    def setLeaseSeconds(url, leaseSeconds)
        begin
            if leaseSeconds > 0
                @db.execute("UPDATE
                                watches
                            SET
                                leaseTill = strftime('%s', 'now') + ?
                            WHERE
                                url = ?
                            OR
                                ? = (SELECT url FROM feeds WHERE feedURL = ?)", leaseSeconds, url, url, url)
            end
        rescue => error
            puts "error setting leaseSeconds: #{error}"
            return false
        end
    end

    def isWatched?(url)
        begin
            return @db.execute("SELECT
                                COUNT('url')
                            FROM
                                watches as w
                                LEFT JOIN
                                    feeds AS f
                                    ON (w.url = f.url)
                            WHERE w.url = ? OR f.feedURL = ?'", url)[0]["COUNT(url)"] > 0

        rescue => error
            puts "error checking if isWatched? for #{url}: #{error}"
        end
    end

    def getPagesToRenew(window)
        begin
            now = Time.now.to_i
            pages = []
            @db.execute("SELECT url FROM watches WHERE leaseTill < ?", now + window) do |row|
                pages.push(Page.new(row["url"]))
            end
            return pages
        rescue => error
            puts "error getting pages to renew: #{error}"
        end
    end

    def deletePage(page)
        return false if page.callback == nil
        begin
            @db.execute("DELETE FROM watches WHERE url = ? and callback = ?", page.url, page.callback)
        rescue => error
            puts "error deleting page #{url}: #{error}"
        end
    end

end