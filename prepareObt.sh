#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

LOCAL_IP=$( ip -f inet -o addr | grep -E -i 'eth0|ib0' )

LOCAL_IP_STR=$( echo $LOCAL_IP | sed -n "s/^.*inet[[:space:]]\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*$/\1 \2 \3 \4/p" | xargs printf ".%d" )
echo "LOCAL IP String: $LOCAL_IP_STR"

if [ -f "settings$LOCAL_IP_STR" ]
then
    cp "settings$LOCAL_IP_STR" settings.sh 
else
    echo "Can't find machine specific settings$LOCAL_IP_STR file."
    if [ -f settings.sh ]
    then 
        echo "Use the existing settings.sh."
    else
        echo "Create settings.sh from the default one."
        cp settings.default settings.sh 
    fi
    
    echo "Create machine specific settings$LOCAL_IP_STR file from settings.sh."
    cp settings.sh "settings$LOCAL_IP_STR"
fi

chmod +x settings.sh
