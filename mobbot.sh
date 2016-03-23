#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games
export HUBOT_SLACK_TOKEN="xoxb-27292579361-I1avgjsPSMMk1A9V6k8nuHhB"
export HUBOT_SLACK_INCOMING_WEBHOOK="https://hooks.slack.com/services/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"
export HUBOT_SLACK_EXIT_ON_DISCONNECT=1
cd /home/pi/git/mobbot
./bin/hubot --adapter slack >> log.txt
