# -*- coding: utf-8 -*-

require "nokogiri"
require "open-uri"
require "logger"

Syobocal = "http://cal.syoboi.jp"

Genre = {
  playing: "#{Syobocal}/list?cat=1",
  old: "#{Syobocal}/list?cat=10",
  ova: "#{Syobocal}/list?cat=7",
  movie: "#{Syobocal}/list?cat=8",
  radio: "#{Syobocal}/list?cat=2",
  hero: "#{Syobocal}/list?cat=4"
}

class Cralwer
  def initialize(genre)
    @genre = genre

    @log = Logger.new("../logs/log_#{@genre}_#{Time.now.strftime("%Y_%m_%d_%H_%M")}")
    @base_url = Genre[@genre]
    
    @anime_casts = Hash.new{|h, k|h[k] = Array.new}
    @anime_date = { }
    @url_anime = { }
  end

  def get_titles_and_start_date
    @log.info("get_titles_and_start_date")

    begin
      @page = Nokogiri::HTML(open(@base_url).read)
      (@page/"table#TitleList"/"tbody"/"tr").each do |elem|
        title = (elem/"td")[0].inner_text
        url = Syobocal + (elem/"td"/"a").attribute("href").value
        start_date = (elem/"td")[1].inner_text
        
        @anime_date[title] = start_date
        @url_anime[url] = title
      end
    rescue Exception => e
      @log.error(e.message)
    end
  end
  
  def get_casts(url)
    @log.info("get_casts url: #{url}")
    
    title = @url_anime[url]
    
    begin
      @page = Nokogiri::HTML(open(url).read)
      (@page/"table.section.cast"/"table.data"/"tr").each do |elem|
        pair = [ ]
        pair.push (elem/"th").inner_text
        pair.push (elem/"td").inner_text
        @anime_casts[title].push pair
      end
    rescue Exception => e
      @log.error(e.message)
    end
  end
  
  def crawl
    @log.info("Start crawling.")
    
    get_titles_and_start_date
    @url_anime.each_key do |url|
      get_casts(url)
      sleep 10
    end
  end

  def write
    open("../data/#{@genre}.tsv", "w"){|f|
      @anime_casts.each_pair do |title, casts|
        f.puts title + "¥t" + casts.map{|e|e.join(":")}.join("¥t")
      end
    }
  end
end

if __FILE__ == $0
  d = Cralwer.new(ARGV[0].to_sym)
  d.crawl
  d.write
end
