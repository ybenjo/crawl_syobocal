# Purpose
Crawl syoboi calendar(cal.syoboi.jp) to collect SEIYU(voice actor/actress)'s information.    
  
## Environments  
+ ruby >= 1.9  
+ gems: nokogiri, mongo  
+ Mongodb  

## Usage  
ruby crawl.rb [playing|old|ova|movie|radio|hero|all]   
'all' : crawling all data  

### config.yaml   
+ address: address of mongodb.   
+ port: port number of mongodb.  
+ db: name of mongodb's db.  
+ collection: name of mongodb's collection.  
+ sleep: crawl interval(sec).  

## Output  
Each mongodb's document contains these values.  
- title: Animation's title.   
- date: Date when this animations start.    
- last\_update: Time when this article(in syobocal) updated.   
- url: URL of this animation's article.   
- casts: Array of pairs that contains [character, seiyu].   
  - Array is sorted by Calender's order(maybe importance).  
- director: Director who made.    
- studio: Animation studio which made.   

