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
MEMCACHED_CHECK_LOG_FILE=${OBT_LOG_DIR}/CheckMemcached-${LONG_DATE}.log

TRY_COUNT=2

#
#------------------------------
#
# Check the state of Memcached
#

WriteLog "Start Memcached Server check..." "${MEMCACHED_CHECK_LOG_FILE}"

# Check if Memcached installed
if type "memcached" &> /dev/null
then
    while [[ $TRY_COUNT -ne 0 ]]
    do
        WriteLog "Try count: ${TRY_COUNT}" "${MEMCACHED_CHECK_LOG_FILE}"

        MEMCACHED_STATE=$( ps ax | grep ' [m]emcached -d -u root' )
        if [[ -z $MEMCAHCED_STATE ]]
        then
            WriteLog "Stoped! Start it! " "${MEMCACHED_CHECK_LOG_FILE}"
            memcached -d -u root > /dev/null 2>&1
            sleep 20
            TRY_COUNT=$(( $TRY_COUNT-1 ))
            continue
        else
            WriteLog "It is OK! " "${MEMCACHED_CHECK_LOG_FILE}"
            break
        fi
    done
    
    if [[ $TRY_COUNT -eq 0 ]]
    then
        WriteLog "Memcached won't start! Give up and send Email to Agyi! " "${MEMCACHED_CHECK_LOG_FILE}"
        # send email to Agyi
        echo "Memcached won't start! " | mailx -s "Problem with Memcached" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
else
    WriteLog "Memcached not installed in this sysytem! Give up and send Email to Agyi! " "${MEMCACHED_CHECK_LOG_FILE}"
    # send email to Agyi
    echo "Memcached not installed in this sysytem! " | mailx -s "Problem with Memcached" -u $USER  ${ADMIN_EMAIL_ADDRESS}
fi

WriteLog "End of Memcached Server check." "${MEMCACHED_CHECK_LOG_FILE}"
