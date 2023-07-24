#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

#set -x

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

BUILD_HOME=~/build/CE/platform/build
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
CASSANDRA_CHECK_LOG_FILE=${OBT_LOG_DIR}/CheckCassandra-${LONG_DATE}.log

tryCount=2

#
#------------------------------
#
# Check the state of Cassandra Server
#

WriteLog "Start Cassandra Server check..." "${CASSANDRA_CHECK_LOG_FILE}"


# Check if Cassandra installed
if type "cqlsh" &> /dev/null
then
    unset -v JAVA_HOME

    while [[ $tryCount -ne 0 ]]
    do
        WriteLog "Try count: ${tryCount}" "${CASSANDRA_CHECK_LOG_FILE}"
        cassandraState=$( cqlsh -e "show version;" -u cassandra -p cassandra 2>/dev/null | grep 'Cassandra')
        if [[ -z $cassandraState ]]
        then
            WriteLog "It doesn't respond to version query. Check if it is already running." "${CASSANDRA_CHECK_LOG_FILE}"
            cassandraPID=$( ps ax  | grep '[c]assandra' | awk '{print $1}' )

            if [[ -n "$cassandraPID" ]]
            then
                WriteLog "It is running (pid: ${cassandraPID}), kill it. " "${CASSANDRA_CHECK_LOG_FILE}"
                sudo kill -9 ${cassandraPID}
                sleep 10
                sudo rm -rf /var/lib/cassandra/*
            fi

            WriteLog "Stoped! Start it!" "${CASSANDRA_CHECK_LOG_FILE}"

            ${SUDO} cassandra > /dev/null 2>&1
            sleep 30
            tryCount=$(( $tryCount-1 ))
            continue
        else
            WriteLog "Cassandra is up!" "${CASSANDRA_CHECK_LOG_FILE}"
            break
        fi
    done
    if [[ $tryCount -eq 0 ]]
    then
        WriteLog "Cassandra doesn't start! Give up and send Email to Agyi!" "${CASSANDRA_CHECK_LOG_FILE}"
        # send email to Agyi
        echo "Cassandra doesn't start in $0 !" | mailx -s "Problem with Cassandra" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
else
    WriteLog "Cassandra  not installed in this sysytem! Give up and send Email to Agyi!" "${CASSANDRA_CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Cassandra  not installed in this sysytem!" | mailx -s "Problem with Cassandra" -u $USER  ${ADMIN_EMAIL_ADDRESS}

fi

WriteLog "End of Cassandra Server check." "${CASSANDRA_CHECK_LOG_FILE}"

set +x