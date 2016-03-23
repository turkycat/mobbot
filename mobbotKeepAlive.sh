#!/bin/bash

# Add to crontab
# */5 * * * * ~/git/mobbot/mobbotKeepAlive.sh /home/pi/git/mobbot mobbot

absolutePath=$1
hubotName=$2

hubotPID=$(ps -aux | grep -w node | grep -w ${hubotName} | grep -v grep | awk '{print $2}')

echo "${hubotName} PID: ${hubotPID}"

if [ -n "${hubotPID// }" ] ; then
    echo "`date`: $hubotName service running, everything is fine"
else
    echo "`date`: $hubotName service NOT running, starting service."
    ${absolutePath}/${hubotName}.sh
fi