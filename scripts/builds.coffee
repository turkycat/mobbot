module.exports = (robot) ->
    jsdom = require "jsdom"
    branch_root_address = "rs1_onecore_stacksp_mobcon_"
    windowsbuild_root_address = "http://windowsbuild/status/"
    windowsbuild_branch_address = "Builds.aspx?buildquery=#{branch_root_address}"
    windowsbuild_status_address = "Timebuilds.aspx?buildguid="
    
    class BuildQuery
        constructor: (response, branch, count, callback) ->
            @response = response
            @branch = branch
            @count = count
            @callback = callback
            @build_identities
    
    class BuildStatus
        constructor: (flavor, status, restarts) ->
            @flavor = flavor
            @status = status
            @restarts = restarts
            @pattern = {
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
            }
            
    class BuildIdentity
        constructor: (buildid, date, guid, web_address = "") ->
            @buildid = buildid
            @date = date
            @guid = guid
            @web_address = web_address
            @status = []
    
    fetch_builds = (query) ->
        web_address = "#{windowsbuild_root_address}#{windowsbuild_branch_address}#{query.branch}"
        #query.response.send web_address

        robot.http(web_address)
            .get() (err, res, body) ->
                if err || res.statusCode isnt 200
                    query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                    return
                
                branch_pattern = /// <td>(.+)\.#{branch_root_address}#{query.branch}\.(.+)buildguid=(.+)">(.*) ///g
                pattern_matches = body.match branch_pattern
                if pattern_matches
                    #[0..pattern_matches.length - 1].map (i) -> res.send "#{i}: #{pattern_matches[i]}"
                    
                    query.build_identities = []
                    num = if query.count < pattern_matches.length then query.count else pattern_matches.length
                    query.response.send "Found #{pattern_matches.length} results. Retrieving status of " + if num > 1 then "#{num} builds, starting with most recent." else "most recent build."
                    [0..num - 1].map (i) ->
                        #if pattern_matches[i]
                        buildid = pattern_matches[i].match /\d{5}\.\d{4}/
                        date = pattern_matches[i].match /\d{6}\-\d{4}/
                        guid = pattern_matches[i].match /.{8}\-.{4}\-.{4}\-.{4}\-.{12}/
                        build = new BuildIdentity buildid, date, guid
                        query.build_identities.push build
                    
                    query.response.send "Parsed #{query.build_identities.length} results into build identities"
                    fetch_build_status query
                else
                    query.response.send "Unable to retrieve build listing."
                    
                    
    fetch_build_status = (query) ->        
        [0..query.build_identities.length - 1].map (i) ->
            web_address = "#{windowsbuild_root_address}#{windowsbuild_status_address}#{query.build_identities[i].guid}"
            query.build_identities[i].web_address = web_address
            #query.response.send web_address
            
            robot.http(web_address)
                .get() (err, res, body) ->
                    if err or res.statusCode isnt 200
                        query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                        return
                        
                    builds = body.match /<td>(x86fre|woafre|ARM64FRE|amd64fre)(.*)/gi
                    if builds
                        [0..builds.length - 1].map (j) ->
                            if builds[j]                            
                                table_elements = builds[j].split /\<td\>/g      #split at each new <td>, removing the tag in the process
                                
                                [1..table_elements.length - 1].map (j) ->       #remove </td> from each string. start at 1 because the first string will be empty due to split
                                    if table_elements[j]
                                        table_elements[j] = table_elements[j].replace /\<\/td\>/, ""
                                
                                build_status = new BuildStatus table_elements[1], table_elements[3], table_elements[5]
                                build_status.color = "#ffff66" if table_elements[3] == "Started"
                                build_status.color = "#ff3333" if table_elements[3] == "Failed"
                                
                                query.build_identities[i].status.push build_status
                        
                        query.response.send "Parsed #{query.build_identities[i].status.length} build statuses for #{i}'th identity."
                        #process_build_results botres, query TODO callback
                    else
                        query.response.send "Unable to retrieve build status."
    
    
    print_results = (query) ->
        [0..query.build_identities.length - 1].map (i) ->
            message = "#{i}: *date*: #{query.build_identities[i].date}  |  *buildid*: #{query.build_identities[i].buildid}  |  *guid*: #{query.build_identities[i].guid}\n"
            message += "#{query.build_identities[i].web_address}\n"
            
            query.build_identities[i].status.map (status) ->
                #status = query.build_identities[i].status[j]
                message += "#{status.flavor}: #{status.status}   |   *Restarts*: #{status.restarts}\n"
        
            query.response.send message
    
    
    check_for_state_change = (query) ->
        #TODO
        #build_report_content[j].text = table_elements[1]
        #build_report_content[j].fields[0].value = table_elements[3]
        #build_report_content[j].fields[1].value = table_elements[5]
        
        #build_report_content[j].color = "#ffff66" if table_elements[3] == "Started"
        #build_report_content[j].color = "#ff3333" if table_elements[3] == "Failed"
        
        #robot.emit 'slack.attachment',
        #    message: botres.message
        #    content: build_report_content
        #    channel: botres.message.room
    
    
    robot.hear /^builds? ?(.{2}\d) ?(\d*){1}/i, (response) ->
        branch = response.match[1]
        count = if res.match[2] then response.match[2] else "1"
        response.send "Fetching builds for #{branch}"
        fetch_builds new BuildQuery response, branch, count, print_results