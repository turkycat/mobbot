fs = require "fs"

#dbgbot cheats by pretending to fetch from http but actually loads from a file
class FakeServerRequest
    constructor: (path) ->
        @path = path
    
    get: (callback) ->
        try
            @body = exports.readFileSync @path
        catch err
            @err = err
            
        
        #this is some black magic right here. get returns a function that that is invoked with 'this'.
        # the returned function returns a function that invokes a callback.
        (callback) =>
            if callback
                if !err then callback null, new FakeServerResponse, @body else callback err, null, null
            @
            
            
class FakeServerResponse
    statusCode: 200
       
#       
#interesting that this doesn't work. the first creates a function (see: object) then sets the function's prototype.statusCode = 200
#  where this one sets the property on the function itself. clearly prototype is an access modifier.
#  I wonder if the access to variables like the one below are restricted to the module? I know that they aren't restricted to the object itself.
#class FakeServerResponse
#    @statusCode = 200
#
        

exports.http = (path) ->
    new FakeServerRequest path

exports.readFileSync = (path) ->
    fs.readFileSync path
    .toString()

exports.send = (msg) ->
    console.log msg