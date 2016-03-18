module.exports = (robot) ->

    robot.hear /test/i, (res) ->
        robot.emit 'slack.attachment',
            message: res.message
            content: [{
                    text: "Attachment text"
                    fallback: "Attachment fallback"
                    color: "#36a64f"
                    fields: [{
                        title: "Field title"
                        value: "Field value"
                    },{
                        title: "Field title"
                        value: "Field value"
                    },]
                },{
                    text: "Attachment text"
                    fallback: "Attachment fallback"
                    color: "#36a64f"
                    fields: [{
                        title: "Field title"
                        value: "Field value"
                    },{
                        title: "Field title"
                        value: "Field value"
                    },]
                }]
            #channel: res.message.room