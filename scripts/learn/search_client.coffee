# This sample application that you'll create lets the user enter a search term, searching both Google and Twitter, and then display the combined results.
# The client side of the application gets the data the user entered and sends it to the server for results.
# When the results are returned from the server, the client side creates UI elements for the results and displays them on the screen.
# For now, don't worry about how the server side works.

class SearchResult
    constructor: (data) ->
        @title = data.title
        @link = data.link
        @extras = data
    
    toHtml: -> "<a href='#{@link}'>#{@title}</a>"
    toJson: -> JSON.stringify @extras
    
    
class GoogleSearchResult extends SearchResult
    constructor: (data) ->
        super data
        @content = @extras.content
    toHtml: ->
        "#{super} <div class='snippet'>#{@content}</div>"
    
    
class TwitterSearchResult extends SearchResult
    constructor: (data) ->
        super data
        @source = @extras.from_user
        @link = "http://twitter.com/#{@source}/status/#{@extras.id_str}"
        @title = @extras.text
    toHtml: ->
        "<a href='http://twitter.com/#{@source}'>@#{@source}</a>: #{super}"
        

#
# MOCK GOOGLE DATA FOR TESTING
#

mockGoogleData = [
        GsearchResultClass:"GwebSearch",
        link:"http://jashkenas.github.com/coffee-script/",
        url:"http://jashkenas.github.com/coffee-script/",
        visibleUrl:"jashkenas.github.com",
        cacheUrl:"http://www.google.com/search?q\u003dcache:nuWrlCK4-v4J:jashkenas
.github.com",
        title:"\u003cb\u003eCoffeeScript\u003c/b\u003e",
        titleNoFormatting:"CoffeeScript",
        content:"\u003cb\u003eCoffeeScript\u003c/b\u003e is a little language that 
compiles into JavaScript. Underneath all of   those embarrassing braces and 
semicolons, JavaScript has always had a \u003cb\u003e...\u003c/b\u003e"
    ,
        GsearchResultClass:"GwebSearch",
        link:"http://en.wikipedia.org/wiki/CoffeeScript",
        url:"http://en.wikipedia.org/wiki/CoffeeScript",
        visibleUrl:"en.wikipedia.org",
        cacheUrl:"http://www.google.com/search?q\u003dcache:wshlXQEIrhIJ
:en.wikipedia.org",
        title:"\u003cb\u003eCoffeeScript\u003c/b\u003e - Wikipedia, the free 
encyclopedia",
        titleNoFormatting:"CoffeeScript - Wikipedia, the free encyclopedia",
        content:"\u003cb\u003eCoffeeScript\u003c/b\u003e is a programming language 
that transcompiles to JavaScript. The   language adds syntactic sugar inspired by 
Ruby, Python and Haskell to enhance \u003cb\u003e...\u003c/b\u003e"
    ,
        GsearchResultClass:"GwebSearch",
        link:"http://codelikebozo.com/why-im-switching-to-coffeescript",
        url:"http://codelikebozo.com/why-im-switching-to-coffeescript",
        visibleUrl:"codelikebozo.com",
        cacheUrl:"http://www.google.com/search?q\u003dcache:VDKirttkw30J:
codelikebozo.com",
        title:"Why I\u0026#39;m (Finally) Switching to \u003cb\u003eCoffeeScript
\u003c/b\u003e - Code Like Bozo",
        titleNoFormatting:"Why I\u0026#39;m (Finally) Switching to CoffeeScript - 
Code Like Bozo",
        content:"Sep 5, 2011 \u003cb\u003e...\u003c/b\u003e You may have already heard
about \u003cb\u003eCoffeeScript\u003c/b\u003e and some of the hype surrounding it
but you still have found several reasons to not make the \u003cb\u003e...
\u003c/b\u003e"   
]


#
# MOCK TWITTER DATA FOR TESTING
#

mockTwitterData = [
        created_at:"Wed, 09 Nov 2011 04:18:49 +0000",
        from_user:"jashkenas",
        from_user_id:123323498,
        from_user_id_str:"123323498",
        geo:null,
        id:134122748057370625,
        id_str:"134122748057370625",
        iso_language_code:"en",
        metadata:
            recent_retweets:4,
            result_type:"popular"
        profile_image_url:"http://a3.twimg.com/profile_images/1185870726/gravatar
_normal.jpg",
        source:"<a href="http://itunes.apple.com/us/app/twitter/id409789998?mt
=12&quot; rel="nofollow">Twitter for Mac</a>",
        text:""CoffeeScript [is] the closest I felt to the power I had twenty 
years ago in Smalltalk" - Ward Cunningham (http://t.co/2Wve2V4l) Nice.",
        to_user_id:null,
        to_user_id_str:null
]



#
# MOCK SEARCH ENGINE FOR TESTING
#

class MockSearch
    search: (query, callback) ->
        results = 
            google: (new GoogleSearchResult obj for obj in mockGoogleData)
            twitter: (new TwitterSearchResult obj for obj in mockTwitterData)
        callback results
        
        

@doSearch = ->
    $ = (id) -> document.getElementById(id)
    kw = $("searchQuery").value
    appender = (id, data) ->
        data.forEach (x) -> 
            $(id).innerHTML += "<p>#{x.toHtml()}</p>"
    ms = new MockSearch
    ms.search kw, (results) ->
        appender("gr", results.google)
        appender("tr", results.twitter)