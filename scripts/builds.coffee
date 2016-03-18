module.exports = (robot) ->

    debug = true
    branch_root_address = "rs1_onecore_stacksp_mobcon_"
    windowsbuild_root_address = "http://windowsbuild/status/"
    windowsbuild_branch_address = "Builds.aspx?buildquery=#{branch_root_address}"
    windowsbuild_status_address = "Timebuilds.aspx?buildguid="
    
    fetch_builds = (botres, query) ->
        branch = query
        web_address = "#{windowsbuild_root_address}#{windowsbuild_branch_address}#{branch}"
        #botres.send web_address

        robot.http(web_address)
            .get() (err, res, body) ->
                if err
                    botres.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                    return
                
                if res.statusCode isnt 200
                    botres.send "DOES NOT COMPUTE :( (request response code not 200)"
                    return
                
                branch_pattern = /// <td>(.+)\.#{branch_root_address}#{branch}\.(.+)buildguid=(.+)">(.*) ///g
                #results = body.match /<td>(.+)\.#{branch_root_address}#{branch}\.(.+)buildguid=(.+)">(.*)/g
                results = body.match branch_pattern
                if results
                    #[0..results.length].map (i) -> res.send "#{i}: #{results[i]}"
                    #res .send results[0]
                    
                    buildid = results[0].match /\d{5}\.\d{4}/
                    date = results[0].match /\d{6}\-\d{4}/
                    guid = results[0].match /.{8}\-.{4}\-.{4}\-.{4}\-.{12}/
                    botres.send "Found #{results.length} results. Defaulting to most recent build: "
                    botres.send "date: #{date}  |  buildid: #{buildid}  |  guid: #{guid}"
                    fetch_build_status botres, guid
                    
                    
    fetch_build_status = (botres, guid) ->
        web_address = "#{windowsbuild_root_address}#{windowsbuild_status_address}#{guid}"
        botres.send web_address if debug
        
        robot.http(web_address)
            .get() (err, res, body) ->
                if err
                    botres.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                    return
                
                if res.statusCode isnt 200
                    botres.send "DOES NOT COMPUTE :( (request response code not 200)"
                    return
                    
                
                results = body.match /<td>(x86fre|woafre|ARM64FRE|amd64fre)(.*)/gi
                if results
                    message = ""
                    
                    [0..results.length].map (i) ->
                        if results[i]                            
                            table_elements = results[i].split /\<td\>/g
                            #botres.send "table elements found: #{table_elements.length}"
                            
                            [0..table_elements.length].map (i) ->
                                if table_elements[i]
                                    table_elements[i] = table_elements[i].replace /\<\/td\>/, ""
                                    
                            message += "#{table_elements[1]}: #{table_elements[3]}   |   Restarts: #{table_elements[5]}\n"
                            
                    botres.send message
                else
                    botres.send "Unable to retrieve results."
                    
    
    robot.hear /^builds? ?(.*)/i, (res) ->
        query = res.match[1]
        res.send "Fetching builds for #{query}"
        fetch_builds res, query