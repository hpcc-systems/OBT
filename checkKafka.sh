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

LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
SCRIPT_NAME=${0##*/}
CHECK_LOG_FILE=${OBT_BIN_DIR}/${SCRIPT_NAME//.sh/}-${LONG_DATE}.log

TRY_COUNT=4

# Add "listeners=PLAINTEXT://127.0.0.1:9092" into config/server.proerties
# if there is an exception in java.net.InetAddress.getCanonicalHostName()

KAFKA_DIR=~/kafka_2.12-2.4.0

#
#------------------------------
#
# Check the state of Memcached
#

pwd=$( pwd ) 
WriteLog "Start Kafka Server check" "${CHECK_LOG_FILE}"

WriteLog "Kafka dir: ${KAFKA_DIR}" "${CHECK_LOG_FILE}"

# Check if Kafka installed
if [ -d ${KAFKA_DIR} ]
then
    WriteLog "Kill node_exporter to free port 9092" "${CHECK_LOG_FILE}"
    res=$( [[ -n "$( pgrep -f node_exporter )" ]] && sudo kill -9 $(pgrep -f node_exporter) || echo "Not found" 2>&1)
    WriteLog "Res: ${res}" "${CHECK_LOG_FILE}"
        
    unset -v JAVA_HOME
    WriteLog "JAVA_HOME: '${JAVA_HOME}' " "${CHECK_LOG_FILE}"

    pushd ${KAFKA_DIR}
    cwd=$(pwd)
    WriteLog "cwd: ${cwd}" "${CHECK_LOG_FILE}"

    while [[ $TRY_COUNT -ne 0 ]]
    do
        WriteLog "Try count: ${TRY_COUNT}" "${CHECK_LOG_FILE}"

        ZOOKEEPER_STATE=$( ps ax | grep -E -c '[z]ook' )
        if [[ $ZOOKEEPER_STATE -eq 0 ]]
        then
            WriteLog "Zookeeper stoped! Start it! " "${CHECK_LOG_FILE}"

        rm -fr /tmp/zookeeper /tmp/kafka-logs

            bin/zookeeper-server-start.sh config/zookeeper.properties > /dev/null 2>&1 &
            res=$?
            WriteLog "Result: $res" "${CHECK_LOG_FILE}"

            sleep 40
            
        TRY_COUNT=$(( $TRY_COUNT-1 ))
        continue
        else
            WriteLog "Zookeeper is OK! " "${CHECK_LOG_FILE}"
        fi

        KAFKA_STATE=$( ps ax | grep -E -c '[k]afka.Kafka' )
        WriteLog "Kafka State: ${KAFKA_STATE}." "${CHECK_LOG_FILE}"

        if [[ $KAFKA_STATE -eq 0 ]]
        then
            WriteLog "Kafka stoped! Start it! " "${CHECK_LOG_FILE}"

            TRY_COUNT=$(( $TRY_COUNT-1 ))
         
            WriteLog "Remove kafka-log" "${CHECK_LOG_FILE}"
            rm -rf /tmp/kafka-logs/
            
            echo "Start Kafka"
        bin/kafka-server-start.sh config/server.properties > /dev/null 2>&1 &
        sleep 40
           
        else
            WriteLog "Kafka is OK! " "${CHECK_LOG_FILE}"
            WriteLog "Broker list: $( echo dump | nc localhost 2181 | grep brokers )" "${CHECK_LOG_FILE}"

        break
        fi
        
    done    
    
    if [[ $TRY_COUNT -eq 0 ]]
    then
        WriteLog "Zookeeper or Kafka doesn't start! Give up and send Email to ${ADMIN_EMAIL_ADDRESS}! " "${CHECK_LOG_FILE}"
        # send email to Agyi
        echo "Zookeeper or Kafka doesn't start! " | mailx -s "Problem with Kafka" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi

    popd

else
    WriteLog "Kafka not installed in this sysytem! Give up and send Email to ${ADMIN_EMAIL_ADDRESS}! " "${CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Kafka not installed in this sysytem! " | mailx -s "Problem with Kafka" -u $USER ${ADMIN_EMAIL_ADDRESS}
fi

WriteLog "End of Kafka Server check." "${CHECK_LOG_FILE}"

