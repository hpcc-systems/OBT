#!/bin/bash

#
#------------------------------
#
# Import settings
#
# Git branch

. ./settings.sh

# WriteLog() function

. ./timestampLogger.sh

#
#------------------------------
#
# Constants
#

BUILD_HOME=$BIN_HOME
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
CHECK_LOG_FILE=${BUILD_HOME}/checkNginx-${LONG_DATE}.log

tryCount=2

#
#------------------------------
#
# Check the state of Nginx Server
#

WriteLog "Start Nginx Server check" "${CHECK_LOG_FILE}"

if [ -f /etc/nginx/nginx.conf ]
then

    # Magic spell
    sudo setenforce Permissive 

    while [[ $tryCount -ne 0 ]]
    do
        WriteLog "Try count: $tryCount" "${CHECK_LOG_FILE}"
        nginxstate=$( ps aux | grep '[n]ginx' )
        if [[ -z $nginxstate  ]]
        then
            WriteLog "Stoped! Start it!" "${CHECK_LOG_FILE}"
            sudo nginx &
            sleep 5
            tryCount=$(( $tryCount-1 ))
            continue
        else
            WriteLog "It is OK!" "${CHECK_LOG_FILE}"
            break
        fi
    done
    if [[ $tryCount -eq 0 ]]
    then
        WriteLog "Nginx won't start! Give up and send Email to Agyi!" "${CHECK_LOG_FILE}"
        # send email to Agyi
        echo "Nginx won't start!" | mailx -s "Problem with Nginx" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
else
    WriteLog "Nginx not installed in this sysytem! Send Email to Agyi!" "${CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Nginx not installed in this sysytem!" | mailx -s "Problem with Nginx" -u $USER  ${ADMIN_EMAIL_ADDRESS}
fi

WriteLog "End." "${CHECK_LOG_FILE}"
