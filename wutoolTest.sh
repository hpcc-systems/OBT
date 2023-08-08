#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

#
#------------------------------
#
# Import settings
#


. ./settings.sh


# WriteLog() function

. ./timestampLogger.sh

#
#-------------------------------
#
# Settings
#

OBT_LOG_DIR=$( pwd )

WUTOOLTEST_EXECUTION_LOG_FILE=${OBT_LOG_DIR}/wutoolTestExecution-$(date "+%Y-%m-%d_%H-%M-%S").log
WUTOOLTEST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTests.$(date "+%Y-%m-%d_%H-%M-%S").log
WUTOOLTEST_LAST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTests.log
WUTOOLTEST_SUMMARY_FILE=${OBT_LOG_DIR}/wutoolTests.summary
WUTOOLTEST_BIN=/opt/HPCCSystems/bin/wutool
WUTOOLTEST_EXCLUSION=
testTargets=( "Dali" "Cassandra" )
testParams=( "DALISERVER=." )
SUDO=

#
#-------------------------------
#
# Start wutoolTests
#

WriteLog "Start wutoolTests..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

#
#-------------------------------
# WUTOOLTEST_BIN
# Check dali
#

WriteLog "Check Dali..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [ -f hpcc/etc/init.d/hpcc-init ]
then
    HPCC_INIT_PATH="hpcc/etc/init.d"
    WUTOOLTEST_BIN=hpcc/opt/HPCCSystems/bin/wutool
else
    HPCC_INIT_PATH="/etc/init.d"
    SUDO=sudo
fi

WriteLog "HPCC_INIT_PATH: ${HPCC_INIT_PATH}" "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [[ -f ${HPCC_INIT_PATH}/hpcc-init ]]
then
    DALI_STOPPED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali status | grep -c '[s]topped' )
    if [[  ${DALI_STOPPED} -eq 1 ]]
    then

        WriteLog "Dali stopped, start it." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        DALI_STARTED=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali start | grep -c '[O]K' )
        if [[ ${DALI_STARTED} -eq 1 ]]
        then
            WriteLog "Dali started." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        else
            WriteLog "Dali won't start. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
            exit 1
        fi
    else
        WriteLog "Dali is up." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
else
    WriteLog "HPCC Systems not installed. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    exit 1
fi

#
#-------------------------------
#
# Check wutoolTest binary
#

WriteLog "Check wutoolTest binary..." "$WUTOOLTEST_EXECUTION_LOG_FILE"

if [ -f ${WUTOOLTEST_BIN} ]
then 
    WriteLog "wutool exists." "$WUTOOLTEST_EXECUTION_LOG_FILE"
else
    WriteLog "wutool doesn't exist. Exit." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    exit 2
fi

WriteLog "IP:$(ip -4 addr)" "$WUTOOLTEST_EXECUTION_LOG_FILE"
WriteLog "Check connection:$(ssh -oConnectTimeout=10 -p 7070 -v $LOCAL_IP_STR 2>&1 )" "$WUTOOLTEST_EXECUTION_LOG_FILE"

#
#-------------------------------
# Start WatchDog to prevent smoketest hangs up
# It should be finished in 120 sec!
#

TIMEOUT=90
DELAY=10
WATCHDOG_LOG_FILE=${OBT_LOG_DIR}/WatchDog-$(date "+%Y-%m-%d_%H-%M-%S").log

WriteLog "Start WatchDog with $TIMEOUT sec timeout and $DELAY sec delay." "$WUTOOLTEST_EXECUTION_LOG_FILE"

# The process name must be longer than the sricpt or any related parameter name!!!
# The simple 'wutool' isn't good, because it can match to this script name 'wutoolTest.sh'
# The parameter of build.sh/ In that case WatchDog can/will kill this or the build script.

sudo unbuffer ./WatchDog.py -p 'wutool -selftest' -t $TIMEOUT -d $DELAY >> ${WATCHDOG_LOG_FILE}  2>&1 &
echo $! > ./WatchDog.pid
WriteLog "WatchDog pid: $( cat ./WatchDog.pid )." "$WUTOOLTEST_EXECUTION_LOG_FILE"

#
#-------------------------------
#
# Execute wutoolTests
#

WriteLog "Excluded testcase(s): ${WUTOOLTEST_EXCLUSION}" "$WUTOOLTEST_EXECUTION_LOG_FILE"

WriteLog "Execute wutoolTests..." "$WUTOOLTEST_EXECUTION_LOG_FILE"
echo ${testParams[@]}
WriteLog "$wutoolTest" "$WUTOOLTEST_EXECUTION_LOG_FILE"

TIME_STAMP=$(date +%s)

for (( index = 0; index < ${#testParams[@]}; index++ ))
do
    SUB_TIME_STAMP=$(date +%s)
    
    echo "$index -> target: ${testTargets[$index]}, param: ${testParams[$index]}"
    WriteLog "$index -> target: ${testTargets[$index]}, param: ${testParams[$index]}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    
    cmd="sudo unbuffer ${WUTOOLTEST_BIN} -selftest ${testParams[$index]} "
    WriteLog "cmd:${cmd}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    echo "target:${testTargets[$index]}" >> $WUTOOLTEST_RESULT_FILE
    
    result=$( ${cmd} 2>&1 )
    IS_NOT_TIMEOUT=$( echo "$result" | grep -E -ic "ok|run|timing")
    WriteLog "IS_NOT_TIMEOUT: ${IS_NOT_TIMEOUT}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    
    if [[ $IS_NOT_TIMEOUT -ge 1 ]]
    then
        echo "${result}" >> $WUTOOLTEST_RESULT_FILE
        WriteLog "${result}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        echo "${result}" >> $WUTOOLTEST_RESULT_FILE
        echo "Run: 1 Failures: 0 Errors: 0 Timeout: 1" >> $WUTOOLTEST_RESULT_FILE
        echo "$wutoolTest run timeout" >> $WUTOOLTEST_RESULT_FILE
        WriteLog "${result} Run: 1 Failures: 0 Errors: 0 Timeout: 1" "$WUTOOLTEST_EXECUTION_LOG_FILE"
        WriteLog "$wutoolTest run timeout" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
    
    SUB_TEST_TIME=$(( $(date +%s) - ${SUB_TIME_STAMP} ))
    WriteLog "\nElaps: ${SUB_TEST_TIME}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
    echo "Elaps: ${SUB_TEST_TIME}" >> $WUTOOLTEST_RESULT_FILE
done

echo "TestResult:wutoolTest:total:${TOTAL} passed:${PASSED} failed:${FAILED}" 
WriteLog "wutoolTests finished." "$WUTOOLTEST_EXECUTION_LOG_FILE"

WriteLog "End." "$WUTOOLTEST_EXECUTION_LOG_FILE"

cp $WUTOOLTEST_RESULT_FILE $WUTOOLTEST_LAST_RESULT_FILE

#
#--------------------------------
#
# Proccess result
#

#For test the result processing
#WUTOOLTEST_RESULT_FILE=${OBT_LOG_DIR}/wutoolTest-result-2016-04-15_12-52-58.log

if [[ -f ${WUTOOLTEST_SUMMARY_FILE} ]]
then
    WriteLog "Remove ${WUTOOLTEST_SUMMARY_FILE}." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    rm -f ${WUTOOLTEST_SUMMARY_FILE}
fi

#set -x
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
TIMEOUT=0
summary_log=''
target=''
elaps=''
IFS=$'\n'
results=($( cat ${WUTOOLTEST_LAST_RESULT_FILE} | grep -E  'OK|Run:|target:|test:|assertion|expression|Error|Elaps' ))

for res in ${results[@]}
do
    echo "Res: '${res}'"
    IS_TARGET=$( echo $res | grep -i -c 'target' )
    if [[ $IS_TARGET -eq 1 ]]
    then
        target=$( echo $res | sed -rn "s/^target\:([[:alpha:]].*)$/\1/p" )
        continue
    fi
    
    IS_ELAPS=$( echo $res | grep -i -c 'Elaps' )
    if [[ $IS_ELAPS -eq 1 ]]
    then
        elaps=$( echo $res | sed -rn "s/^Elaps\:[[:space:]]*(.*)$/\1/p" )
        echo "<<$elaps>>"
        WriteLog "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:$( SecToTimeStr ${elaps} )"  "$WUTOOLTEST_EXECUTION_LOG_FILE"    
        echo "TestResult:wutoolTest(${target}):total:${UNIT_TOTAL} passed:${UNIT_PASSED} failed:${UNIT_FAILED} errors:${UNIT_ERRORS} timeout:${UNIT_TIMEOUT} elaps:$( SecToTimeStr ${elaps} )" >> $WUTOOLTEST_SUMMARY_FILE    
        continue
    fi
    
    IS_PASS=$( echo $res | grep -c 'OK (' )
    if [[ $IS_PASS -eq 1 ]]
    then
        RESULT=$(echo $res | grep 'OK (' )

        UNIT_TOTAL=$(echo "${RESULT}" | sed -n "s/^[[:space:]]*OK[[:space:]]*(\([0-9]*\)\(.*\)$/\1/p" )
        UNIT_PASSED=$UNIT_TOTAL
        UNIT_FAILED=0
        UNIT_ERRORS=0
        UNIT_TIMEOUT=0
        TOTAL=$(( $TOTAL + $UNIT_TOTAL))
        PASSED=$(( $PASSED + $UNIT_PASSED))

    else
        RESULT=$( echo $res | grep -i 'Run:' )
        if [[ "$RESULT" != "" ]]
        then
            if [[ "$RESULT" =~ "Timeout" ]]
            then
                SED_INPUT="s/^[[:space:]]*Run:[[:space:]]*\([0-9]*\)[[:space:]]*Failures:[[:space:]]*\([0-9]*\)[[:space:]]*Errors:[[:space:]]*\([0-9]*\)[[:space:]]*Timeout:[[:space:]]*\([0-9]*\)[[:space:]]*$/"
                
                UNIT_TOTAL=$(echo "${RESULT}" | sed -n $SED_INPUT"\1/p")
                UNIT_FAILED=$(echo "${RESULT}" | sed -n $SED_INPUT"\2/p")
                UNIT_ERRORS=$(echo "${RESULT}" | sed -n $SED_INPUT"\3/p")
                UNIT_TIMEOUT=$(echo "${RESULT}" | sed -n $SED_INPUT"\4/p")
            else
                SED_INPUT="s/^[[:space:]]*Run:[[:space:]]*([0-9]*)[[:space:]]*Failures:[[:space:]]*([0-9]*)[[:space:]]*Errors:[[:space:]]*([0-9]*)[[:space:]]*$/"
                
                UNIT_TOTAL=$(echo "${RESULT}" | sed -rn $SED_INPUT"\1/p")
                UNIT_FAILED=$(echo "${RESULT}" | sed -rn $SED_INPUT"\2/p")
                UNIT_ERRORS=$(echo "${RESULT}" | sed -rn $SED_INPUT"\3/p")
                UNIT_TIMEOUT=0
            fi
            UNIT_PASSED="$(( $UNIT_TOTAL - $UNIT_FAILED - $UNIT_ERRORS - $UNIT_TIMEOUT))"
            TOTAL=$(( $TOTAL + $UNIT_TOTAL))
            PASSED=$(( $PASSED + $UNIT_PASSED))
            FAILED=$(( $FAILED + $UNIT_FAILED))
            ERRORS=$(( $ERRORS + $UNIT_ERRORS))
            TIMEOUT=$(( $TIMEOUT + $UNIT_TIMEOUT))  
        else
            echo "Valami mas."
            summary_log=${summary_log}"${target}:$res\n"
            continue
        fi
    fi  
done

TEST_TIME=$(( $(date +%s) - $TIME_STAMP ))

WriteLog "TestResult:wutoolTest:total:${TOTAL} passed:${PASSED} failed:${FAILED} errors:${ERRORS} timeout:${TIMEOUT} elaps:$( SecToTimeStr ${TEST_TIME} )"  "$WUTOOLTEST_EXECUTION_LOG_FILE"    

WriteLog "${summary_log}" "$WUTOOLTEST_EXECUTION_LOG_FILE"
echo -e "${summary_log}" >> $WUTOOLTEST_SUMMARY_FILE
#set +x

if [[  ${DALI_STOPPED} -eq 1 ]]
then
    WriteLog "Dali was stopped. Stop it  to restore original state." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    DALI_STOP=$( $SUDO ${HPCC_INIT_PATH}/hpcc-init -c dali stop | grep -c '[O]K' )
    if [[ ${DALI_STOP} -eq 1 ]]
    then
        WriteLog "Dali stopped." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        WriteLog "Dali won't stop." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
fi

if [[ ($testCassandra -eq 1) && ($CASSANDRA_STOPPED -eq 1) ]]
then
    WriteLog "Cassandra was stopped. Stop it  to restore original state." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    CASSANDRA_PID=$( ps aux | grep '[c]assandra' | awk '{ print $2 }' )
    CASSANDRA_STOP=$( sudo kill ${CASSANDRA_PID}; sleep 10;  ps aux | grep '[c]assandra' | awk '{ print $2 }' | wc -l) 
    if [[ ${CASSANDRA_STOP} -eq 0 ]]
    then
        WriteLog "Cassandra stopped." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    else
        WriteLog "Cassandra won't stop." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    fi
    WriteLog "Remove Cassandra leftovers." "$WUTOOLTEST_EXECUTION_LOG_FILE"
    sudo rm -rf /var/lib/cassandra
    sudo rm -r /var/log/cassandra
    
fi


wdPid=$( cat ./WatchDog.pid )
WriteLog "Kill WatchDog (${wdPid})." "$WUTOOLTEST_EXECUTION_LOG_FILE"

sudo kill ${wdPid}

while (true)
do 
    sleep ${DELAY}
    stillRunning=$( ps aux | grep -c -i '[w]atchdog.py' )

    if [[ ${stillRunning} -eq 0 ]]
    then 
        WriteLog "WatchDog (${wdPid}) finished." "$WUTOOLTEST_EXECUTION_LOG_FILE"
        break
    fi
    WriteLog "WatchDog (${wdPid}) is still running. Wait ${DELAY} sec and try again." "$WUTOOLTEST_EXECUTION_LOG_FILE"

    [ -n "$(pgrep WatchDog)" ] && sudo pkill WatchDog.py

done

rm ./WatchDog.pid

WriteLog "End." "$WUTOOLTEST_EXECUTION_LOG_FILE"

