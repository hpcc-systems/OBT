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

BUILD_HOME=~/build/CE/platform/build
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
COUCHBASE_CHECK_LOG_FILE=${OBT_LOG_DIR}/CheckCouchbase-${LONG_DATE}.log

tryCount=2

CheckPorts()
{
    COUCHBASE_CHECK_LOG_FILE=$1
    #Check its (beam) port usage@
    inet_dist_listen_min=$( sed -n 's/-kernel inet_dist_listen_min \([0-9]*\) inet_dist_listen_max \([0-9]*\)/\1/p' /opt/couchbase/bin/couchbase-server | tr -d '\\' )
    #inet_dist_listen_max=$( sed -n 's/-kernel inet_dist_listen_min \([0-9]*\) inet_dist_listen_max \([0-9]*\)/\2/p' /opt/couchbase/bin/couchbase-server | tr -d '\\' )
    
    # if they are wrong
    if [[ $inet_dist_listen_min -eq 21100 ]]
    then
        WriteLog "Couchbase has a default port configuration (inet_dist_listen_min: $inet_dist_listen_min) and it is clashing with our first Thor Slave. Stop Couchbase." "${COUCHBASE_CHECK_LOG_FILE}"
        stopCmd='sudo /opt/couchbase/bin/couchbase-server -k'
        WriteLog "CMD: '${stopCmd}'" "${COUCHBASE_CHECK_LOG_FILE}"

        res=$( ${stopCmd} 1>/dev/null 2>&/dev/stdout )
        WriteLog "Res: ${res}" "${COUCHBASE_CHECK_LOG_FILE}"
        sleep 30
        
        inet_dist_listen_min=37100
        inet_dist_listen_max=37299
        sudo cp /opt/couchbase/bin/couchbase-server  /opt/couchbase/bin/couchbase-server.orig
        sudo sed -e "s/inet_dist_listen_min \([0-9]*\) inet_dist_listen_max \([0-9]*\)/inet_dist_listen_min $inet_dist_listen_min inet_dist_listen_max $inet_dist_listen_max/g" /opt/couchbase/bin/couchbase-server > temp.xml && sudo mv -f temp.xml "/opt/couchbase/bin/couchbase-server"
        sudo chmod 0755  /opt/couchbase/bin/couchbase-server
    fi
}

#
#------------------------------
#
# Check the state of Couchbase Server
#

WriteLog "Start Couchbase Server check..." "${COUCHBASE_CHECK_LOG_FILE}"

WriteLog "Couchbase Server IP: ${COUCHBASE_SERVER}, local IP: ${LOCAL_IP_STR}." "${COUCHBASE_CHECK_LOG_FILE}"

if [[ $COUCHBASE_SERVER == $LOCAL_IP_STR ]]
then

    WriteLog "Couchbase is a local server/service" "${COUCHBASE_CHECK_LOG_FILE}" 
    
    # Check if Couchbase installed
    if [ -f /opt/couchbase/bin/couchbase-server ]
    then

        CheckPorts "${COUCHBASE_CHECK_LOG_FILE}"

        while [[ $tryCount -ne 0 ]]
        do
            WriteLog "Try count: ${tryCount}" "${COUCHBASE_CHECK_LOG_FILE}"
            couchbaseState=$( pgrep -f 'beam' )
            if [[ -z $couchbaseState ]]
            then
                WriteLog "Couchbase is stoped! Start it!" "${COUCHBASE_CHECK_LOG_FILE}"

                cmd='sudo /opt/couchbase/bin/couchbase-server \-- -noinput -detached'
                WriteLog "CMD: '${cmd}'" "${COUCHBASE_CHECK_LOG_FILE}"

                res=$( ${cmd} 1>/dev/null 2>&/dev/stdout )
                WriteLog "Res: ${res}" "${COUCHBASE_CHECK_LOG_FILE}"
        
                sleep 30
            else
                WriteLog "Couchbase is up in this system (IP:$LOCAL_IP_STR)!" "${COUCHBASE_CHECK_LOG_FILE}"
                
                break
            fi
            tryCount=$(( $tryCount-1 ))
        done
        if [[ $tryCount -eq 0 ]]
        then
            WriteLog "Couchbase doesn't start on this system (IP:$LOCAL_IP_STR)! Give up and send Email to Agyi!" "${COUCHBASE_CHECK_LOG_FILE}"
            # send email to Agyi
            echo "Couchbase Doesn't start on this system (IP:$LOCAL_IP_STR)!" | mailx -s "Problem with Couchbase" -u $USER  ${ADMIN_EMAIL_ADDRESS}
        fi
    else
        WriteLog "Couchbase not installed in this system (IP:$LOCAL_IP_STR)! Give up and send Email to Agyi!" "${COUCHBASE_CHECK_LOG_FILE}"
        # send email to Agyi
        echo "Couchbase  not installed in this system (IP:$LOCAL_IP_STR)!" | mailx -s "Problem with Couchbase" -u $USER  ${ADMIN_EMAIL_ADDRESS}

    fi
else
    WriteLog "Couchbase is a remote server/service on $COUCHBASE_SERVER" "${COUCHBASE_CHECK_LOG_FILE}" 
    
    # For this my/user publick key should copied into the local ~/.ssh/authorized_keys file
    
    res=$( ssh -i  ~/.ssh/obt_rsa $COUCHBASE_USER@$COUCHBASE_SERVER << 'EOF'
echo "remote host: $HOSTNAME"
cd ${HOME}/build/bin/
./checkCouchbase.sh
EOF
)
    WriteLog "res:\n$res" "${COUCHBASE_CHECK_LOG_FILE}"

    remoteIsUp=0
    #set -x

    remoteIsUp=$( for line in "${res}";                                                          \
        do                                                                                       \
            if [[ "$line" =~ "Couchbase is up" ]];                                              \
            then                                                                                 \
                echo "1";                                                                        \
                break;                                                                           \
            fi;                                                                                  \
        done;                                                                                    \
        );

    set +x

    if [[ $remoteIsUp -eq 1 ]]
    then
        WriteLog "Remote server (IP:$COUCHBASE_SERVER) is up" "${COUCHBASE_CHECK_LOG_FILE}"
    else
        WriteLog "Remote server (IP:$COUCHBASE_SERVER) is down." "${COUCHBASE_CHECK_LOG_FILE}"
        # send email to Agyi
        echo "On $LOCAL_IP_STR the $0 is failed to check Couchbase server on $COUCHBASE_SERVER !" | mailx -s "Problem with Couchbase" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
 
fi

WriteLog "End of Couchbase Server check." "${COUCHBASE_CHECK_LOG_FILE}"
