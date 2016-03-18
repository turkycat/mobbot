module.exports = (robot) ->

    debug = true
    branch_root_address = "rs1_onecore_stacksp_mobcon_"
    windowsbuild_root_address = "http://windowsbuild/status/"
    windowsbuild_branch_address = "Builds.aspx?buildquery=#{branch_root_address}"
    windowsbuild_status_address = "Timebuilds.aspx?buildguid="
    
    class BuildResult
        constructor: (buildid, date, guid) ->
            @buildid = buildid
            @date = date
            @guid = guid
    
    fetch_builds = (botres, query, count = 1) ->
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
                    #[0..results.length - 1].map (i) -> res.send "#{i}: #{results[i]}"
                    
                    builds = []
                    num = if count < results.length then count else results.length
                    botres.send "Found #{results.length} results. Retrieving status of " + if num > 1 then "#{num} builds, starting with most recent." else "most recent build."
                    [0..num - 1].map (i) ->
                        if results[i]
                            buildid = results[i].match /\d{5}\.\d{4}/
                            date = results[i].match /\d{6}\-\d{4}/
                            guid = results[i].match /.{8}\-.{4}\-.{4}\-.{4}\-.{12}/
                            build = new BuildResult buildid, date, guid
                            builds.push build
                            
                    fetch_build_status botres, builds
                else
                    botres.send "Unable to retrieve results."
                    
    build_report_content = [{
        text: ""
        #fallback: "Attachment fallback"
        color: "#36a64f"
        fields: [{
            title: "Status"
            value: ""
        },{
            title: "Restarts"
            value: ""
        }]
    },{
        text: ""
        #fallback: "Attachment fallback"
        color: "#36a64f"
        fields: [{
            title: "Status"
            value: ""
        },{
            title: "Restarts"
            value: ""
        }]
    },{
        text: ""
        #fallback: "Attachment fallback"
        color: "#36a64f"
        fields: [{
            title: "Status"
            value: ""
        },{
            title: "Restarts"
            value: ""
        }]
    },{
        text: ""
        #fallback: "Attachment fallback"
        color: "#36a64f"
        fields: [{
            title: "Status"
            value: ""
        },{
            title: "Restarts"
            value: ""
        }]
    }]
                    
                    
    fetch_build_status = (botres, builds) ->        
        [0..builds.length - 1].map (i) ->
            web_address = "#{windowsbuild_root_address}#{windowsbuild_status_address}#{builds[i].guid}"
            message = "*date*: #{builds[i].date}  |  *buildid*: #{builds[i].buildid}  |  *guid*: #{builds[i].guid}\n"
            message += "#{web_address}\n"
            
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
                        
                        j = 0;
                        [0..results.length - 1].map (i) ->
                            if results[i]                            
                                table_elements = results[i].split /\<td\>/g
                                #botres.send "table elements found: #{table_elements.length}"
                                
                                [0..table_elements.length - 1].map (i) ->
                                    if table_elements[i]
                                        table_elements[i] = table_elements[i].replace /\<\/td\>/, ""
                                        
                                build_report_content[j].text = table_elements[1]
                                build_report_content[j].fields[0].value = table_elements[3]
                                build_report_content[j].fields[1].value = table_elements[5]
                                
                                build_report_content[j].color = "#ffff66" if table_elements[3] == "Started"
                                build_report_content[j].color = "#ff3333" if table_elements[3] == "Failed"
                                    
                                
                                ++j
                                message += "#{table_elements[1]}: #{table_elements[3]}   |   *Restarts*: #{table_elements[5]}\n"
                                
                        #robot.emit 'slack.attachment',
                        #    message: botres.message
                        #    content: build_report_content
                        #    channel: "#general"#res.message.room    
                            
                        botres.send message
                    else
                        botres.send "Unable to retrieve results."
                    
    
    robot.hear /^builds? ?(.{2}\d) ?(\d*){1}/i, (res) ->
        query = res.match[1]
        count = res.match[2]
        res.send "Fetching builds for #{query}"
        if count then fetch_builds res, query, count else fetch_builds res, query