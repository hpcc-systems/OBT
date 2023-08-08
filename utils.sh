#!/bin/bash
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

#
#------------------------------
#
# Import settings
#

# WriteLog() function

#. ./timestampLogger.sh

#
#----------------------------------------------------
#
# Common functions
#

GetFreeMem()
{
    freeMem=$( free | grep -E "^(Mem)" | awk '{ print $4 }' )
    echo ${freeMem}
}

GetFreeMemGB()
{
    freeMemGB=$( free -g | grep -E "^(Mem)" | awk '{print $4"GB from "$2"GB" }' )
    echo ${freeMemGB}
}

SecToTimeStr()
{
    [[ "$1." != "." ]] && sec=$1 || sec=0

    printf "%s sec (" "${sec}"
    [[ ${sec} -ge 86400 ]] && printf "%s" "$( date -d@${sec} -u +%-d) days " ;
    echo "$( date -d@${sec} -u +%H:%M:%S))"
}

KillCheckDiskSpace()
{
   WriteLog "KillCheckDiskSpace()" "$1"
   pids=$( ps ax | grep "[c]heckDiskSpace.sh" | awk '{print $1}' )

    for i in $pids
    do 
        WriteLog "kill checkdiskspace.sh with pid: ${i}" "$1"
        kill -9 $i
        sleep 1
    done;
    [[ -f ./checkdiskspace.pid ]] && rm ./checkdiskspace.pid

    sleep 1

   WriteLog "Kill myInfo.sh" "$1"
   pids=$( ps ax | grep "[m]yInfo.sh" | awk '{print $1}' )

    for i in $pids
    do 
        WriteLog "kill myInfo.sh with pid: ${i}" "$1"
        kill -9 $i
        sleep 1
    done;
    [[ -f ./myinfo.pid ]] && rm ./myinfo.pid

    sleep 1

    WriteLog "Kill port logger" "$1"
    if [[ -f ./portlog.pid ]]
    then
       sudo kill $( cat ./portlog.pid )
       rm ./portlog.pid
    fi  
}

StopHpcc()
{
    hpccComponenets=$( ${HPCC_SERVICE} status  )
    WriteLog "Current status:\n${hpccComponenets}" "$1"
    
    WriteLog "Stop HPCCSystems" "$1"
    hpccRunning=$( ${HPCC_SERVICE} stop  | grep -E 'still' | wc -l )
    WriteLog "${hpccRunning} running component(s)" "$1"
    
    if [[ $hpccRunning -ne 0 ]]
    then
        dafilesrv=$( ${DAFILESRV_STOP} 2>&1 )
        WriteLog "result:${dafilesrv}" "$1"
    
        res=$( ${HPCC_SERVICE} status | grep 'still' )

        # If the result is "Service dafilesrv, mydafilesrv is still running."
        if [[ -n $res ]]
        then
            WriteLog "result:${res}" "$1"
        else
            WriteLog "HPCC System stopped." "$1"
        fi
    else
        WriteLog "HPCC System stopped." "$1"
    fi
    
    hpccComponenets=$( ${HPCC_SERVICE} status  )
    WriteLog "Current status:\n${hpccComponenets}" "$1"
}

ExitEpilog()
{
    WriteLog "Stop disk space checker" "$1"
    echo "Stop disk space checker"

    KillJava "$1"

    KillCheckDiskSpace "$1"

    sleep 10
    
    cd ${OBT_BIN_DIR}
    ./archiveLogs.sh obt-exit-cleanup timestamp=${OBT_TIMESTAMP}

    myParent=$(ps -o comm=  $PPID)
    myTrace=$( local frame=0; while caller $frame; do ((frame++)); done )
    WriteLog "End of OBT. Something went wrong: in '${myParent}' ($2\n${myTrace})." "$1"

    echo "End of OBT on ${OBT_SYSTEM} with ${BRANCH_ID}. Somethng went wrong: in '${myParent}' ($2\n${myTrace}).\nError:$3" | mailx -s "Problem with OBT on ${OBT_SYSTEM} with ${BRANCH_ID}" -u $USER ${ADMIN_EMAIL_ADDRESS}

    if [ "$2." == "$2" ]
    then
        exit -1
    else
        exit $2
    fi
}

KillJava()
{
    javaInstances=$(  ps aux | grep '[j]ava' | wc -l )
    if [[ ${javaInstances} -ne 0 ]]
    then
        WriteLog "There are ${javaInstances} instances of Java running. Kill them." "$1"

        sudo pkill java
        sleep 1m
        javaInstances=$(  ps aux | grep '[j]ava' | wc -l )
    
        WriteLog "Now, there are ${javaInstances} instances of Java running." "$1"
    fi

    freeMemGB=$(  free -g | grep -E "^(Mem)" | awk '{print $4"GB from "$2"GB" }' )
    WriteLog "The free memory is (${freeMemGB})!" "$1"
}

LatestBrRelease()
{
    CANDIDATE=$1
    if [[ -n "$2" ]]
    then
        SOURCE_HOME="$2"
    fi
    
    if [ -n $CANDIDATE ]
    then
        if [ -d ${SOURCE_HOME} ]
        then
            pushd ${SOURCE_HOME} > /dev/null 2&>1

            git remote add upstream git@github.com:hpcc-systems/HPCC-Platform.git    
            git fetch upstream

            #            list git      get given candidates                  convert release number to '0'          sort       get the     remove trailing
            #            branches                                            prefixed to reach proper sort order    them       first one   '0's
            #
            releaseId=$( git branch | grep -E 'te\-'${CANDIDATE}'.([0-9].*)' | gawk -F. '{ printf("%03d\n", $3); }' | sort -gr | head -n 1 | tr -d "^0" )
            popd > /dev/null 2&>1

            echo $releaseId
        else
            echo "No source dir. Exit."
        fi
    else
        echo "Missing candidate. Exit."
    fi
}

ElementIn()
{
    lookFor=$1
    if [[ -n "$2" ]]
    then
        arr="$2"
    fi
    
    local e
    for e in arr
    do
        if [[ "$e" == "$lookFor" ]]
        then
            return 1
        fi
    done
    
    return 0
}

