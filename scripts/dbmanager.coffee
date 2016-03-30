mongo = require "mongodb"
    .MongoClient
root = exports ? this
    
url = "mongodb://localhost:27017/mobbot"
root.db = null

root.open_database = ( callback ) ->
    mongo.connect url, ( err, db ) ->
        callback err if err isnt null && callback
        root.db = db
        console.log "database connection opened."
        callback null
        
        
root.close_database = () ->
    root.db.close() if root.db
    root.db = null
    console.log "database connection closed."
    
    
root.insert_items = ( items, colname, callback ) ->
    if !root.db && callback
        console.log "database is not open"
        return callback "database is not open", null
    if !items || !colname
        console.log "items or collection is not valid"
        return callback "items or collection is not valid", null
    
    collection = root.db.collection colname
    cb = ( err, result ) ->
        if err
            callback err if callback
        else
            console.log "inserted #{result.result.n} items into the #{colname} collection"
            callback null, result if callback
        
    if typeof items.length is "undefined"
        collection.insertOne items, cb
    else if items.length == 1
        collection.insertOne items[0], cb
    else if items.length > 1
        collection.insertMany items, cb
    else
        console.log "invalid item entry, database not modified"
        callback "invalid item entry, database not modified", null if callback
        
        
root.delete_items = ( items, collection, callback ) ->
    callback "database is not open", null if !root.db && callback
    callback "items or collection is not valid", null if !items || !collection
    
    collection = root.db.collection collection
    cb = ( err, result ) ->
        callback err if err && callback
        console.log "deleted #{result.result.n} items from the #{collection} collection"
        callback null, result
        
    if typeof items.length is "undefined"
        collection.deleteOne items, cb
    else if items.length == 1
        collection.deleteOne items[0], cb
    else if items.length > 1
        collection.deleteMany doc, cb
    else
        callback "invalid item entry, database not modified", null if callback
    