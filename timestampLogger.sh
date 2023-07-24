#!/bin/bash

WriteLog()
(
    # If Bash trace is on ('set -x') switch it off till end of this function
    if [ -o xtrace ]
    then
        set +x
        trap 'set -x' RETURN
    fi

#    set -x
    IFS=$'\n'
    text=$1
    logFile=$2

    # Length of the content of text
    if [[ ${#text} -le 32768 ]]
    then
        text="${text//\\n/$'\n'}"
        text="${text//\\t/ $'\t'}"
    else
        #text=$( echo ${text} | sed -e 's/\\\\/\\/g' -e 's/\\t/\t/g' )
        t=''

    fi

    echo "${text}" | while read i
    do
        TIMESTAMP=$( date "+%Y-%m-%d %H:%M:%S")
        printf "%s: %s\n" "${TIMESTAMP}" "$i"
        if [ "$logFile." == "." ]
        then
            echo ${TIMESTAMP}": ERROR: WriteLog() target log file name is empty! ($0)"
        else 
            echo -e "${TIMESTAMP}: $i" >> $logFile
        fi
    done
    unset IFS
    #set +x
)
