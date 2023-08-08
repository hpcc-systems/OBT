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

BIN_HOME=$OBT_BIN_DIR
if [ ! -d ${BIN_HOME} ]
then
    # Local dev/test/debug dir
    BIN_HOME=~/Redis
fi

LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
REDIS_CHECK_LOG_FILE=${OBT_LOG_DIR}/checkRedis-${LONG_DATE}.log

PORT1=6379
PORT2=6380
PORT3=6381
APP_SHORT_NAME=redis
APP_NAME=$APP_SHORT_NAME-server

pwd=$( pwd )

WriteLog "Start Redis Server config check..." "${REDIS_CHECK_LOG_FILE}"

cd ${BIN_HOME}

WriteLog "Check if we have  ${BIN_HOME}/${APP_SHORT_NAME}.conf file. " "${REDIS_CHECK_LOG_FILE}"
if [ ! -f ${BIN_HOME}/${APP_SHORT_NAME}.conf ]
then
    if [ -f /etc/${APP_SHORT_NAME}/${APP_SHORT_NAME}.conf ]
    then
        WriteLog "No, we have not. Copy one from /etc/${APP_SHORT_NAME}/${APP_SHORT_NAME}.conf." "${REDIS_CHECK_LOG_FILE}"
        sudo cp /etc/${APP_SHORT_NAME}/${APP_SHORT_NAME}.conf .
    else
        WriteLog "No, we have not. Copy one from /etc/${APP_SHORT_NAME}.conf." "${REDIS_CHECK_LOG_FILE}"
        sudo cp /etc/${APP_SHORT_NAME}.conf . 
    fi
    
    sudo chmod 0755 ${BIN_HOME}/${APP_SHORT_NAME}.conf
    sudo chown ${USER}:users ${BIN_HOME}/${APP_SHORT_NAME}.conf
else
    WriteLog "Yes, we have it." "${REDIS_CHECK_LOG_FILE}"
fi

if [[ ( ! -f ${BIN_HOME}/${APP_SHORT_NAME}1.conf ) || ( $( stat --format="%s" ${BIN_HOME}/${APP_SHORT_NAME}1.conf ) -eq 0) ]]
then
    WriteLog "There is not ${BIN_HOME}/${APP_SHORT_NAME}1.conf file! Derive it from original." "${REDIS_CHECK_LOG_FILE}"
    
    sudo sed -e 's/^# requirepass/requirepass/g' -e 's/daemonize no/daemonize yes/' "${BIN_HOME}/${APP_SHORT_NAME}.conf" > ${BIN_HOME}/${APP_SHORT_NAME}1.conf
fi

if [[ ( ! -f ${BIN_HOME}/${APP_SHORT_NAME}2.conf ) || ( $( stat --format="%s" ${BIN_HOME}/${APP_SHORT_NAME}2.conf ) -eq 0) ]]
then
    WriteLog "There is not ${BIN_HOME}/${APP_SHORT_NAME}2.conf file! Derive it from original." "${REDIS_CHECK_LOG_FILE}"
    
    sed -e 's/^# requirepass foobared/requirepass youarefoobared/' -e 's/^port 6379/port '${PORT2}'/' -e 's/daemonize no/daemonize yes/'  "${BIN_HOME}/${APP_SHORT_NAME}.conf" > ${BIN_HOME}/${APP_SHORT_NAME}2.conf
fi

if [[ ( ! -f ${BIN_HOME}/${APP_SHORT_NAME}3.conf ) || ( $( stat --format="%s" ${BIN_HOME}/${APP_SHORT_NAME}3.conf ) -eq 0) ]]
then
    WriteLog "There is not ${BIN_HOME}/${APP_SHORT_NAME}3.conf file! Derive it from original." "${REDIS_CHECK_LOG_FILE}"
    
    sed -e 's/^# requirepass foobared/requirepass foobared/' -e 's/^port 6379/port '${PORT3}'/' -e 's/daemonize no/daemonize yes/'  "${BIN_HOME}/${APP_SHORT_NAME}.conf" > ${BIN_HOME}/${APP_SHORT_NAME}3.conf    
fi

#
#--------------------------
#
# Check the state of Redis Servers It should be 3 instances
# on on port PORT1, PORT2 and on PORT3
#

WriteLog "Start Redis Server check..." "${REDIS_CHECK_LOG_FILE}"

TRY_COUNT=2

if [[ -f /usr/sbin/redis-server ||  -f /usr/bin/redis-server || -f /usr/local/bin/redis-server ]]
then

    while [[ $TRY_COUNT -ne 0 ]]
    do
    WriteLog "Try count: ${TRY_COUNT}" "${REDIS_CHECK_LOG_FILE}"
        NUM_SERVERS=$( sudo netstat -tulnap | grep -E -c ":($PORT1|$PORT2|$PORT3).*LISTEN.*$APP_NAME" )
        WriteLog "numOfServers: ${NUM_SERVERS}" "${REDIS_CHECK_LOG_FILE}"

        if [[ ${NUM_SERVERS} -ne 3 && ${NUM_SERVERS} -ne 6 ]]
        then
            WriteLog "We expected 3 servers on port ${PORT1}, ${PORT2} and ${PORT3} but there are none" "${REDIS_CHECK_LOG_FILE}"
        
            # If there any Redis server, kill them
            pgrep $APP_NAME | 
            while read pid
            do 
                WriteLog "Kill $APP_NAME (pid:"$pid")" "${REDIS_CHECK_LOG_FILE}"
                sudo kill -9 $pid
            done
        
            #start them
            WriteLog "Start 3 servers on port ${PORT1} ${PORT2} and ${PORT3}." "${REDIS_CHECK_LOG_FILE}"
    
            WriteLog "Start sudo $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}1.conf on port ${PORT1}" "${REDIS_CHECK_LOG_FILE}"

            $SUDO $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}1.conf &
            
            WriteLog "Start sudo $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}2.conf on port ${PORT2}" "${REDIS_CHECK_LOG_FILE}"            

            $SUDO $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}2.conf &
            
            WriteLog "Start sudo $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}3.conf on port ${PORT3}" "${REDIS_CHECK_LOG_FILE}"            

            $SUDO $APP_NAME ${BIN_HOME}/${APP_SHORT_NAME}3.conf &
            
            TRY_COUNT=$(( $TRY_COUNT-1 ))

        NUM_SERVERS=$( sudo netstat -tulnap | grep -E -c ":($PORT1|$PORT2|$PORT3).*LISTEN.*$APP_NAME" )
 
        if [[ ${NUM_SERVERS} -ge 3 || ${NUM_SERVERS} -eq 6 ]]
            then
            sleep 10
                continue
        else
               WriteLog "It is OK!  We have 3 servers on expected ports!" "${REDIS_CHECK_LOG_FILE}"
            break
        fi

        else
           WriteLog "It is OK!  We have 3 servers on expected ports!" "${REDIS_CHECK_LOG_FILE}"
           break
        fi

    done
    if [[ $TRY_COUNT -eq 0 ]]
    then
    WriteLog "Redis won't start! Give up and send Email to Agyi!" "${REDIS_CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Redis won't start!" | mailx -s "Problem with Redis" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
else
    WriteLog "Redis not installed in this sysytem! Send Email to Agyi!" "${REDIS_CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Redis not installed in this sysytem!" | mailx -s "Problem with Redis" -u $USER  ${ADMIN_EMAIL_ADDRESS}
fi

WriteLog "Start monitor for every redis servers." "${REDIS_CHECK_LOG_FILE}"

redis-cli -a foobared monitor > ./redis1-${LONG_DATE}.out 2>&1 &
redis-cli -p 6380 -a youarefoobared monitor > ./redis2-${LONG_DATE}.out 2>&1 &
redis-cli -p 6381 -a foobared monitor > ./redis3-${LONG_DATE}.out 2>&1 &

cd ${pwd}

WriteLog "End of Redis Server check." "${REDIS_CHECK_LOG_FILE}"
