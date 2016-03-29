#
# this script will load build identities from winbuilds and determine the current status for each flavor of build.
# the intention of this script is to accept queries from Slack and return the results to Slack. In this mode, the 
#   the script is loaded by Hubot.
#
# this script also has a testing mode in which the web pages are loaded from a text file and should be ran directly
#   in the console by first setting DEBUG_MODE to 'true' and call ../test_files/testbuildscript.cmd
#   you must have a copy of the correct pages saved to paths given by $DEBUG.builds_path and $DEBUG.guid_path
#


#set DEBUG_MODE to true and run this compiled script with node, see top of script for more information.
DEBUG_MODE = true
$DEBUG = null
if DEBUG_MODE
    $DEBUG = require "../test_files/dbgbot"
    $DEBUG.builds_path = "../test_files/builds.txt"
    $DEBUG.guid_path = "../test_files/buildguid.txt"

module.exports = (robot) ->
    
    jsdom = require "jsdom"
    branch_root_address = "rs1_onecore_stacksp_mobcon_"
    windowsbuild_root_address = "http://windowsbuild/status/"
    windowsbuild_branch_address = "Builds.aspx?buildquery=#{branch_root_address}"
    windowsbuild_status_address = "Timebuilds.aspx?buildguid="
    #TODO buildsvc_root_address = "http://buildsvc/BuildDetails.aspx?guid=" #interestingly, the GUIDs are unique to the site
    
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
                color: ""
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
            @fetched = false
            @status = []
    
    fetch_builds = (query) ->
        web_address = "#{windowsbuild_root_address}#{windowsbuild_branch_address}#{query.branch}"
        web_address = $DEBUG.builds_path if DEBUG_MODE
        
        robot.http(web_address)
            .get() (err, res, body) ->
                if err || res.statusCode isnt 200
                    query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                    return
                    
                parse_builds query, body
                    
                
    parse_builds = (query, body) ->
        branch_pattern = /// <td>(.+)\.#{branch_root_address}#{query.branch}\.(.+)buildguid=(.+)">(.*) ///g
        pattern_matches = body.match branch_pattern
        if pattern_matches
        
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
            
            fetch_build_status query
        else
            query.response.send "Unable to retrieve build listing."
                    
                    
    fetch_build_status = (query) ->        
        [0..query.build_identities.length - 1].map (i) ->
            web_address = "#{windowsbuild_root_address}#{windowsbuild_status_address}#{query.build_identities[i].guid}"
            query.build_identities[i].web_address = web_address
            web_address = $DEBUG.guid_path if DEBUG_MODE
            
            robot.http(web_address)
                .get() (err, res, body) ->
                    if err or res.statusCode isnt 200
                        query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)"
                        return
                        
                    parse_build_status query, i, body
                        
                        
    parse_build_status = (query, i, body) ->
        jsdom.env body, (err, window) ->
            if err
                console.error err
                return

            #get the necessary elements using jquery
            $ = require("jquery")(window)
            rows = $(".rgRow, .rgAltRow")
            rows.each (index) ->
                flavor = $(this).children().eq(0).text()
                status = $(this).children().eq(2).text()
                restarts = $(this).children().eq(4).text()
                build_status = new BuildStatus flavor, status, restarts
                switch status
                    when "Started" then build_status.color = "#ffff66"
                    when "Failed" then build_status.color = "#ff3333"
                    else build_status.color = "#36a64f"
                
                query.build_identities[i].status.push build_status
                
            query.build_identities[i].fetched = true
            cb = query.build_identities.reduce (a, b) -> a && b.fetched
            query.callback query if cb
            
    
    print_results = (query) ->
        [0..query.build_identities.length - 1].map (i) ->
            message = "*date*: #{query.build_identities[i].date}  |  *buildid*: #{query.build_identities[i].buildid}  |  *guid*: #{query.build_identities[i].guid}\n"
            message += "#{query.build_identities[i].web_address}\n"
            #message += "#{buildsvc_root_address}#{query.build_identities[i].guid}\n" #this doesn't work, guid is unique to site.
            
            query.build_identities[i].status.map (status) ->
                #status = query.build_identities[i].status[j]
                message += "#{status.flavor}: "
                message += if status.status is "Failed" then "*#{status.status}*" else "#{status.status}"
                message += "  |   *Restarts*: #{status.restarts}\n"
        
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
        
    
    if DEBUG_MODE
        $DEBUG.send "Fetching builds from file"
        fetch_builds new BuildQuery $DEBUG, "dv1", 1, print_results
    else
        robot.hear /^builds? ?(.{2}\d) ?(\d*){1}/i, (response) ->
            branch = response.match[1]
            count = if response.match[2] then response.match[2] else "1"
            response.send "Fetching builds for #{branch}"
            fetch_builds new BuildQuery response, branch, count, print_results

#invoke the function we just set to module.exports with the $DEBUG object as the robot param
if DEBUG_MODE
    module.exports $DEBUG
