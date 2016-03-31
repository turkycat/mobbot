module.exports = (robot) ->

    #two examples of attachments
    single_attachment = {
        pretext: "message before attachment"
        text: "Attachment text"
        fallback: "Attachment fallback"
        color: "#36a64f"
        author_name: "this is the owner"
        title: "this is the title"
        title_link: "http://google.com"
    }
    
    
    #content can be a single object or an array of objects
    attachment_array = [
        single_attachment,
        {
            pretext: "message before attachment"
            text: "Attachment text"
            fallback: "Attachment fallback"
            color: "danger"         #"danger", "good", "warning", or a hex value
            
            #this attachment has multiple fields
            fields: [{
                title: "Field title"
                value: "Field value"
            },{
                title: "Field title"
                value: "Field value"
            },]
        }
    ]

    robot.hear /emit/i, (res) ->
        robot.emit 'slack.attachment', {
            message: res.message
            content: single_attachment
            channel: "turkycat"             #specify a user by name
            #channel: "#script-testing"     #specify a channel by name
            #channel: res.channel           #respond wherever the message came from
        }