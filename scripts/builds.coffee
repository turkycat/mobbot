#
# this script will load build identities from winbuilds and determine the current status for each flavor of build.
# the intention of this script is to accept queries from Slack and return the results to Slack. In this mode, the 
#   the script is loaded by Hubot.
#
# this script also has a testing mode in which the web pages are loaded from a text file and should be ran directly
#   in the console by first setting DEBUG_MODE to 'true' and call ../test_files/testbuildscript.cmd
#   you must have a copy of the correct pages saved to paths given by $DEBUG.builds_path and $DEBUG.status_path
#


#set DEBUG_MODE to true and run this compiled script with node, see top of script for more information.
DEBUG_MODE = true
$DEBUG = null
if DEBUG_MODE
    $DEBUG = require "../test_files/dbgbot"
    $DEBUG.builds_path = "../test_files/builds.txt"
    $DEBUG.status_path = "../test_files/buildstatus.txt"

module.exports = (robot) ->
    
    #load modules
    jsdom = require "jsdom"
    $ = require "jquery"
    mongo = require "mongodb"
    .MongoClient
    
    #behave like static variables
    mongourl = "mongodb://localhost:27017/mobbot"
    branch_root_address = "rs1_onecore_stacksp_mobcon_"
    windowsbuild_root_address = "http://windowsbuild/status/"
    windowsbuild_branch_address = "Builds.aspx?buildquery=#{branch_root_address}"
    windowsbuild_status_address = "Timebuilds.aspx?buildguid="
    windowsbuild_official_build_owner = "wincbld"
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
            
    class BuildIdentity
        constructor: (branch, build_id, date, guid, owner, web_address = "") ->
            @branch = branch
            @build_id = build_id
            @date = date
            @guid = guid
            @owner = owner
            @is_official = owner == windowsbuild_official_build_owner
            @web_address = web_address
            @fetched = false
            @status = []
    
    fetch_builds = (query) ->
        web_address = "#{windowsbuild_root_address}#{windowsbuild_branch_address}#{query.branch}"
        web_address = $DEBUG.builds_path if DEBUG_MODE
        
        robot.http(web_address)
            .get() (err, res, body) ->
                if err || res.statusCode isnt 200
                    query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)\n#{err}"
                    return
                    
                parse_builds query, body
                    
                
    parse_builds = (query, body) ->
        jsdom.env body, (err, window) ->
            if err
                console.error err
                return
                
            _$ = $(window)
            rows = _$(".rgRow, .rgAltRow")
            num_to_fetch = if query.count < rows.length then query.count else rows.length
            query.response.send "Found #{rows.length} results. Retrieving status of " + if num_to_fetch > 1 then "#{num_to_fetch} official builds, starting with most recent." else "most recent official build."
            
            query.build_identities = []
            rows.each (i) ->
                elements = _$( this ).find "td"
                full_label = _$( elements[0] ).text()
                timebuild_html = _$( elements[1] ).html()
                label_regex = /(\d{5}\.\d{4})\.(.+)\.(\d{6}\-\d{4})/
                label_matches = label_regex.exec full_label
                
                build_id = label_matches[1]
                branch = label_matches[2]
                date = label_matches[3]
                guid = timebuild_html.match /.{8}\-.{4}\-.{4}\-.{4}\-.{12}/
                owner = _$( elements[3] ).text()
                build = new BuildIdentity branch, build_id, date, guid, owner
                query.build_identities.push build if build.is_official
                query.build_identities.length != num_to_fetch
                
            if query.build_identities.length < 1
                query.response.send "Unable to locate any builds with the specified owner. :("
            else
                fetch_build_status query
                    
                    
    fetch_build_status = (query) ->        
        [0..query.build_identities.length - 1].map (i) ->
            web_address = "#{windowsbuild_root_address}#{windowsbuild_status_address}#{query.build_identities[i].guid}"
            query.build_identities[i].web_address = web_address
            web_address = $DEBUG.status_path if DEBUG_MODE
            
            robot.http(web_address)
                .get() (err, res, body) ->
                    if err or res.statusCode isnt 200
                        query.response.send "DOES NOT COMPUTE :( (an error occurred with the http request)\n#{err}"
                        return
                        
                    parse_build_status query, i, body
                        
                        
    parse_build_status = (query, i, body) ->
        jsdom.env body, (err, window) ->
            if err
                console.error err
                return

            _$ = $(window)
            rows = _$(".rgRow, .rgAltRow")
            rows.each (index) ->
                flavor = _$( this ).children().eq(0).text()
                status = _$( this ).children().eq(2).text()
                restarts = _$( this ).children().eq(4).text()
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
            message = "*date*: #{query.build_identities[i].date}  |  *build id*: #{query.build_identities[i].build_id}  |  *guid*: #{query.build_identities[i].guid}\n"
            message += "#{query.build_identities[i].web_address}\n"
            #message += "#{buildsvc_root_address}#{query.build_identities[i].guid}\n" #this doesn't work, guid is unique to site.
            
            query.build_identities[i].status.map (status) ->
                #status = query.build_identities[i].status[j]
                message += "#{status.flavor}: "
                message += if status.status is "Failed" then "*#{status.status}*" else "#{status.status}"
                message += "  |   *Restarts*: #{status.restarts}\n"
        
            query.response.send message
    
    
    check_for_state_change = (query) ->
    
        #open the database to check and possibly update the stored values for the retrieved builds
        mongo.connect mongourl, ( err, database ) ->
            if err
                console.log err
                return
                
            console.log "database connection opened."
            collection = database.collection if DEBUG_MODE then "test_builds" else "builds"
            
            #go through each build identity retrieved and try to find it in the database by guid
            for identity in query.build_identities
                collection.findOne { "guid": identity.guid }, {}, ( err, doc ) ->
                    if err
                        console.log err.message
                        return
                    
                    #iterate through the statuses on the returned document looking for changes
                    modified = false
                    for doc_status, i in doc.status
                        if doc_status.status != identity.status[i].status
                            modified = true
                            console.log "status for #{identity.build_id}.#{identity.branch}.#{identity.date}:#{doc_status.flavor} changed from #{doc_status.status} to #{identity.status[i].status}"
                            doc_status.status = identity.status[i].status
                    
                    #update the database if necessary
                    if modified
                    
                    else
                        console.log "no statuses have changed"
            
            #collection.insert query.build_identities, null, ( err, result ) ->
            #    if err
            #        console.log err
            #        return
            #        
            #    console.log "inserted #{result.result.n} items into the database collection"
            #database.close()
            #console.log "database connection closed."
        
        #TODO
        #robot.emit 'slack.attachment',
        #    message: botres.message
        #    content: build_report_content
        #    channel: botres.message.room
        
    
    if DEBUG_MODE
        $DEBUG.send "Fetching builds from file"
        fetch_builds new BuildQuery $DEBUG, "dv1", 1, check_for_state_change
    else
        robot.hear /^builds? ?(.{2}\d) ?(\d*){1}/i, (response) ->
            branch = response.match[1]
            count = if response.match[2] then parseInt response.match[2] else 1
            response.send "Fetching official builds for #{branch}"
            fetch_builds new BuildQuery response, branch, count, print_results

#invoke the function we just set to module.exports with the $DEBUG object as the robot param
if DEBUG_MODE
    module.exports $DEBUG
