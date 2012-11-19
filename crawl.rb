# -*- coding: utf-8 -*-

require 'nokogiri'
require 'open-uri'
require 'logger'
require 'mongo'
require 'time'
require 'yaml'
require 'fileutils'

Syobocal = 'http://cal.syoboi.jp'

Genre = {
  playing: "#{Syobocal}/list?cat=1",
  old: "#{Syobocal}/list?cat=10",
  ova: "#{Syobocal}/list?cat=7",
  movie: "#{Syobocal}/list?cat=8",
  radio: "#{Syobocal}/list?cat=2",
  hero: "#{Syobocal}/list?cat=4"
}

class Crawler
  def initialize(genre)
    current = File.dirname(File.expand_path(__FILE__))
    c = YAML.load_file("#{current}/config.yaml")
    @sleep = c['sleep']

    @genre = genre

    @base_url = Genre[@genre]
    @mongo = Mongo::Connection.new(c['address'], c['port']).db(c['db'])[c['collection']]

    # all key is url
    @anime_casts = Hash.new{ |h, k|h[k] = Array.new}
    @anime_date = { }
    @anime_title = { }
    @last_update = { }
    @anime_genre = { }
    @anime_stuff = Hash.new{|h, k|h[k] = Hash.new}

    FileUtils.mkdir("#{current}/logs") if !Dir.exist?("#{current}/logs")
    @log = Logger.new("#{current}/logs/log_#{@genre}_#{Time.now.strftime('%Y_%m_%d_%H_%M')}")

    # write config.yaml
    c.each_pair do |k, v|
      @log.info("config: #{k} => #{v}")
    end
  end

  def get_titles_and_start_date
    @log.info('get_titles_and_start_date')

    begin
      @page = Nokogiri::HTML(open(@base_url).read)
      (@page/'table#TitleList'/'tbody'/'tr').each do |elem|
        title = (elem/'td')[0].inner_text
        url = Syobocal + (elem/'td'/'a').attribute('href').value
        start_date = (elem/'td')[1].inner_text

        @anime_date[url] = start_date
        @anime_title[url] = title
        @anime_genre[url] = @genre

        update_time = nil
        begin
          update_time = Time.parse((elem/'td')[4].inner_text)
        rescue => e
          log.error(e.message)
        end
        @last_update[url] = update_time
      end
    rescue Exception => e
      @log.error(e.backtrace)
    end
    sleep @sleep
  end

  def get_casts(url, _id = nil)
    @log.info("crawl: #{url}")

    title = @anime_title[url]

    begin
      @page = Nokogiri::HTML(open(url).read)
      # 監督とスタジオ
      (@page/'table.section.staff'/'table.data'/'tr').each do |elem|
        key = (elem/'th').inner_text
        val = (elem/'td').inner_text
        @anime_stuff[url][key] = val
      end

      # 声優
      (@page/'table.section.cast'/'table.data'/'tr').each do |elem|
        pair = [ ]
        pair.push (elem/'th').inner_text
        pair.push (elem/'td').inner_text
        @anime_casts[url].push pair
        @log.info("Get #{title}, #{pair.join(' => ')}")
      end
      update(url, _id)
    rescue Exception => e
      @log.error(e.message)
    end
  end

  def crawl
    @log.info('Start crawling.')

    get_titles_and_start_date
    # ここで last_update はもう取得できている
    @last_update.each_pair do |url, page_last|
      entry = @mongo.find_one({url: url})
      if entry.nil? || page_last > entry['last_update'].getlocal('+09:00')
        _id = entry.nil? ? nil : entry['_id']
        get_casts(url, _id)
        sleep @sleep
      else
        @log.info("Skip. Not updated #{url}.")
      end
    end
  end

  def update(url, _id)
    entry = {
      title: @anime_title[url],
      date: @anime_date[url],
      last_update: @last_update[url],
      url: url,
      casts: @anime_casts[url],
      genre: @anime_genre[url],
      stuff: @anime_stuff[url]
    }

    if _id.nil?
      @mongo.insert(entry)
      @log.info("Insert #{url}.")
    else
      @mongo.update({_id: _id}, entry)
      @log.info("Update #{url}.")
    end
  end
end

if __FILE__ == $0
  if ARGV[0].nil? || !ARGV.all?{|str| (Genre.keys + [:all]).include?(str.to_sym)}
    puts "Usage: ruby crawl.rb [ #{(Genre.keys + [:all]).join(" | ")} ]"
    exit 1
  end

  genre = ARGV.map(&:to_sym)
  if genre == [:all]
    Genre.each_key do |g|
      d = Crawler.new(g)
      d.crawl
    end
  else
    genre.each do |g|
      d = Crawler.new(g)
      d.crawl
    end
  end
end
