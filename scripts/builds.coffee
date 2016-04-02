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
DEBUG_MODE = false
$DEBUG = null
if DEBUG_MODE
    $DEBUG = require "/home/pi/git/mobbot/test_files/dbgbot"
    $DEBUG.builds_path = "/home/pi/git/mobbot/test_files/builds.txt"
    $DEBUG.status_path = "/home/pi/git/mobbot/test_files/buildstatus.txt"

module.exports = (robot) ->
    
    #load modules
    jsdom = require "jsdom"
    $ = require "jquery"
    mongo = require "mongodb"
    .MongoClient
    db = null
    
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
            @complete = false
            @status = []
            
    class SlackUser
        constructor: (username) ->
            @username = username
            @subscriptions = []
            
    
    #open the database
    mongo.connect mongourl, ( err, database ) ->
        if err
            console.log err
            return
        
        db = database
        console.log "database connection opened."
        

    response_logger = {
        send: ( message ) ->
            console.log message
    }
    
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
    
        #check and possibly update the stored values for the retrieved builds
        collection = db.collection if DEBUG_MODE then "test_builds" else "builds"
        
        #go through each build identity retrieved and try to find it in the database by guid
        for identity in query.build_identities                
            collection.findOne { "guid": identity.guid }, {}, ( err, doc ) ->
                if err
                    console.log err.message
                    return
                    
                #if the returned doc is null, the database does not have an entry for this identity. Add it!
                if !doc
                    return collection.insert identity, ( err, result ) ->
                        if err
                            console.log err
                            return
                            
                        if result.result.n == 1
                            console.log "inserted a new build into the database collection"
                        else
                            console.log "there was a problem inserting a new build into the database"
                    
                #determine if this build is already complete
                if doc.complete
                    console.log "all builds for this identity have stopped. skipping update check"
                    return
                
                #iterate through the statuses on the returned document looking for changes and completeness
                update_needed = doc.status.length != identity.status.length     #update needed if new builds have started
                complete = !update_needed                                       #default value is usually true, but will be false if new builds have started
                for doc_status, i in doc.status
                    if identity.status[i].status == "Started" || identity.status[i].status == "Failed"
                        complete = false
                        
                    if doc_status.status != identity.status[i].status
                        update_needed = true
                        emit_state_change doc, doc_status, identity.status[i]
                
                #update the database if necessary
                if update_needed
                    identity.complete = complete
                    collection.findOneAndReplace { _id: doc._id }, identity, ( err, result ) ->
                        if err
                            console.log err.message
                            return
                            
                        console.log "updated changed document in database"
                else
                    console.log "No build statuses have changed for #{query.branch}"
            
            
    emit_state_change = ( identity_document, old_status, new_status ) ->
        console.log "status for #{identity_document.build_id}.#{identity_document.branch}.#{identity_document.date}:#{new_status.flavor} changed from #{old_status.status} to #{new_status.status}"
       
        #slice off the last bit of the branch name for cleaner messages
        branch_regex = /.*_(.+)$/i
        branch_matches = branch_regex.exec identity_document.branch
        branch_short_name = branch_matches[1]
        
        pattern = {
            pretext: "Status update for #{branch_short_name}"
            fallback: ""
            text: ""
            color: "good"
            author_name: "Build #{new_status.status}"
            title: "#{identity_document.build_id}.#{identity_document.branch}.#{identity_document.date}",
            text: "#{new_status.flavor}",
            title_link: "#{identity_document.web_address}"
        }

        #customize some of the fields based on what is being sent
        #fallback text is what is displayed on any notifications that go out for this message    
        if new_status.status == "Failed"
            pattern.fallback = "Oh no! There is a problem with one of today's builds."
            pattern.color = "danger"
        else if new_status.status == "Completed"
            pattern.fallback = "#{new_status.flavor} build complete for #{branch_short_name}!"
        else if new_status.status == "Started" && old_status.status == "Failed"
            pattern.fallback = "#{new_status.flavor} build resumed for #{branch_short_name}."
            pattern.author_name = "Build resumed"
            pattern.color = "warning"
        else
            pattern.fallback = "An update to one of today's builds has been posted to Slack."
            pattern.color = "warning"
            
            if new_status.status == "Cancelled"
                pattern.color = "warning"
        
        #emit a message to the appropriate slack channel if the status is failed or complete
        if new_status.status == "Failed" || new_status.status == "Completed"
            console.log "build has changed to failed or completed. Emitting Slack message."
            
            robot.emit 'slack.attachment', {
                message: robot.message
                content: pattern
                channel: "#build-breaks"
            }
            
        collection = db.collection if DEBUG_MODE then "test_subscribers" else "subscribers"
        collection.find( { subscriptions: identity_document.branch } ).toArray ( err, docs ) ->
            if err 
                return console.log err
                
            if docs
                console.log "found subscribers for #{identity_document.branch}, sending direct messages..."
                for doc in docs
                    robot.emit 'slack.attachment', {
                        message: robot.message
                        content: pattern
                        channel: doc.username
                    }
                
            
        
    perform_user_query = ( response ) ->
        branch = response.match[1]
        count = if response.match[2] then parseInt response.match[2] else 1
        response.send "Fetching official builds for #{branch}"
        fetch_builds new BuildQuery response, branch, count, print_results
        
        
    add_remove_subscribers = ( response ) ->
        subscribing = response.match[1] == "subscribe" || response.match[1] == "-s"
        branch = "#{branch_root_address}#{response.match[2]}"
        name = response.envelope.user.name
        
        #get subscriber collection
        collection = db.collection if DEBUG_MODE then "test_subscribers" else "subscribers"
        
        #attempt to retrieve the user document from the collection
        collection.findOne { username: name }, ( err, doc ) ->
            if err
                console.log err
                return response.send "There was an error with that request. #{err}"
                
            #if we did not find a document for the user and they are subscribing to a build, add them to the collection
            if !doc
                if subscribing
                    user = new SlackUser name
                    user.subscriptions.push branch
                    return collection.insertOne user, ( err, result ) ->
                        if err
                            console.log err
                            return response.send "There was an error with that request. #{err}"
                            
                        if result.result.n == 1
                            return response.send "Success! You are now personally subscribed to status changes for #{branch}. I will send you a direct message when build statuses change."
                else
                    #if they are not subscribing and there is no document retrieved, there is nothing to do.
                    return response.send "You are not subscribed to #{branch}."
                        
            #we found the user in the database, let's look for the specified branch in their document
            req_handled = false
            for sub, i in doc.subscriptions
                if sub == branch
                    req_handled = true
                    if subscribing
                        response.send "You are already subscribed to #{branch}!"
                        return false

                    else
                        #we found the subscription to remove, lets remove it
                        doc.subscriptions.splice i, 1
                        response.send "You are no longer subscribed to #{branch}."

                    
            #if the request is not yet handled, it is a subscribe request and was not found in the doc. Add it!
            if !req_handled
                doc.subscriptions.push branch
                response.send "Success! You are now personally subscribed to #{doc.subscriptions.length} branches."
                
            collection.findOneAndReplace { _id: doc._id }, doc, ( err, result ) ->
                if err
                    console.log err.message
                    return
                    
                return console.log "successfully updated user document in the database."
        
    
    if DEBUG_MODE
        $DEBUG.send "Fetching builds from file"
        fetch_builds new BuildQuery $DEBUG, "dv1", 1, check_for_state_change
    else
        #respond to direct queries in channel or DM
        robot.hear /^builds? ?(.{2}\d) ?(\d*){1}/i, perform_user_query
        robot.respond /builds? ?(.{2}\d) ?(\d*){1}/ig, perform_user_query
        
        #add or remove subscribers for a branch
        robot.hear /^builds?\s(unsubscribe|subscribe|-s|-u)\s(.{2}\d)/i, add_remove_subscribers
        robot.respond /builds?\s(unsubscribe|subscribe|-s|-u)\s(.{2}\d)/i, add_remove_subscribers

        #set an interval to periodically check for build updates on all branches
        setInterval () ->
            console.log "Interval elapsed. Checking build statuses for changes."
            fetch_builds new BuildQuery response_logger, "dv1", 1, check_for_state_change
            fetch_builds new BuildQuery response_logger, "dv2", 1, check_for_state_change
            fetch_builds new BuildQuery response_logger, "dv3", 1, check_for_state_change
            fetch_builds new BuildQuery response_logger, "dv4", 1, check_for_state_change
        , 120000

#invoke the function we just set to module.exports with the $DEBUG object as the robot param
if DEBUG_MODE
    module.exports $DEBUG
