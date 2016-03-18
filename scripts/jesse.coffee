module.exports = (robot) ->
    fetchJesse = (botres) ->
        robot.http("http://jesse.com")
            .get() (err, res, body) ->
                if err
                    res.send "DOES NOT COMPUTE :( #{err}"
                    return
                
                if res.statusCode isnt 200
                    res.send "Request didn't come back HTTP 200 :("
                    return
                    
                arr = body.split "\n"
                [0..arr.length].map (i) -> botres.send "#{i}: #{arr[i]}"
                
    
    robot.hear /jesse/i, (res) ->
        res.send "Fetching Jesse!"
        fetchJesse res