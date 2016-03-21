#
# this script is for experimentation with jquery in a coffeescript
# it will parse reddit front page and extract the topics
#

module.exports = (robot) ->
    $ = require('jQuery')
    
    
    
    
    robot.hear /reddit/i, (msg) ->
        robot.http(https://www.reddit.com/)
            .get() (err, res, body) ->
                if err || res.statusCode isnt 200
                    botres.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                    return
                    
                doc = $('<body />').append body
            