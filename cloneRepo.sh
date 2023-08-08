#!/bin/bash
#export PS4='+ $LINENO: ' ## single quotes prevent $LINENO being expanded immediately
#set -ux

declare -f -F WriteLog> /dev/null

if [ $? -ne 0 ]
then
    [ -f ./timestampLogger.sh ] && . ./timestampLogger.sh || . ~/build/bin/timestampLogger.sh
    # . ~/build/bin/timestampLogger.sh
fi

# Git branch settings

.  ~/build/bin/settings.sh

KillWatchDogAndWaitToDie()
{
    DELAY=10
    ps -p $1 > /dev/null
    [ "$?" -eq 0 ] && sudo kill -TERM $1

    while (true)
    do
        STILL_RUNNING=$( ps aux | grep -c -i '[w]atchdog.py' )

        if [[ ${STILL_RUNNING} -eq 0 ]]
        then 
            WriteLog "WatchDog ($1) finished." "$2"
            break
        fi
        WriteLog "WatchDog ($1) is still running. Wait ${DELAY} sec and try again." "$2"
        sleep ${DELAY}
        sudo kill -KILL $1
    done

    rm ./WatchDog.pid
}


CloneRepo()
{
    LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
    CLONE_LOG_FILE=$OBT_BIN_DIR/CloneRepo-${LONG_DATE}.log
    WATCHDOG_LOG_FILE=${OBT_LOG_DIR}/WatchDog-$(date "+%Y-%m-%d_%H-%M-%S").log


    if [ -f "$OBT_BIN_DIR/WatchDog.py" ]
    then
        watchDogStartCmd="$OBT_BIN_DIR/WatchDog.py -p 'git-*' -t 900 -r 3600 -v"
        WriteLog "Start WatchDog: ${watchDogStartCmd}" "${CLONE_LOG_FILE}"
        WriteLog "Watchdog logfile: ${WATCHDOG_LOG_FILE}" "${CLONE_LOG_FILE}"

        ${watchDogStartCmd} >> ${WATCHDOG_LOG_FILE} 2>&1 &
        echo $! > ./WatchDog.pid
        WriteLog "WatchDog pid: $( cat ./WatchDog.pid )." "$CLONE_LOG_FILE"

    fi
    
    NO_ERROR=0
    RECOVERABLE_ERROR=1
    UNRECOVERABLE_ERROR=2
    DESTINATION_EXISTS_ERROR=3
    HTTP_REQUEST_ERROR=4

    TRY_COUNT=20
    TRY_DELAY=2m
    repo=$1
    target=$2

    WriteLog "Clone $1  (into '$target')" "${CLONE_LOG_FILE}"
    WriteLog "[$( caller )] $*" "${CLONE_LOG_FILE}"

    while true
    do
        WriteLog "Try count: ${TRY_COUNT}" "${CLONE_LOG_FILE}"
        res=0
        err=0

        while read line
           do
               WriteLog "${line}" "${CLONE_LOG_FILE}" > /dev/null
               res=$( echo "${line}" | grep -E -i '^fatal' | grep -E -c -i 'not an empty directory' )
               if [ $res -ne 0 ]
               then
                    err=$DESTINATION_EXISTS_ERROR
                    break
               fi
               
               res=$( echo "${line}" | grep -E -i '^fatal' | grep -E -c -i 'HTTP request failed' )
               if [ $res -ne 0 ]
               then
                    err=$HTTP_REQUEST_ERROR
                    break
               fi
               
               res=$( echo "${line}" | grep -E -i '^fatal' | grep -E -c -i 'unable to access' )
               if [ $res -ne 0 ]
               then
                    err=$HTTP_REQUEST_ERROR
                    break
               fi;
               
               res=$( echo "${line}" | grep -E -c -i '^fatal' )
               if [ $res -ne 0 ]
               then
                    err=$UNRECOVERABLE_ERROR
                    break
               fi;
               
               res=$( echo "${line}" | grep -E -c -i '^error' )
               if [ $res -ne 0 ]
               then
                    err=$RECOVERABLE_ERROR
                    break
               fi
               
            done < <( git clone $repo $target 2>&1 )

        # There was no error
        if [ $err -eq 0 ] 
        then 
            WriteLog "Cloned! " "${CLONE_LOG_FILE}"
            break
        else
            WriteLog "Error:${err}" "${CLONE_LOG_FILE}"
            case $err in
                $RECOVERABLE_ERROR ) WriteLog "res:$err -> 'RECOVERABLE_ERROR'" "${CLONE_LOG_FILE}"
                                    # Check/set MTU with 'ip link set eth0 mtu 1400'
                                    ipResetCMD="ip link set eth0 mtu 1400"    
                                    WriteLog "Reset link: ${ipResetCMD}" "${CLONE_LOG_FILE}"
                                    ${ipResetCMD} >> ${CLONE_LOG_FILE} 2>&1 &
                                    ;;

                $UNRECOVERABLE_ERROR ) WriteLog "res:$err -> 'UNRECOVERABLE_ERROR'" "${CLONE_LOG_FILE}"
                                    # return 1
                                    rmt=$( git ls-remote  ${repo} | wc -l )
                                    WriteLog "ls-remote returns with ${rmt} results." "${CLONE_LOG_FILE}"
                                    gitproc=$( pgrep -f 'git-' )
                                    WriteLog "git process(es): ${gitproc} ." "${CLONE_LOG_FILE}"
                                    [ -n "$gitproc" ]  && sudo pkill -KILL ${gitproc}
                                    ;;

                $DESTINATION_EXISTS_ERROR ) WriteLog "res:$err -> 'DESTINATION_EXISTS_ERROR'." "${CLONE_LOG_FILE}"
                                    WriteLog "Remove target directory and try again." "${CLONE_LOG_FILE}"
                                    rm -rf $target

                                    ;;
                $HTTP_REQUEST_ERROR ) WriteLog "res:$err -> 'HTTP_REQUEST_ERROR'" "${CLONE_LOG_FILE}"
                                    WriteLog "Try it with SSH: 'git@github.com:hpcc-systems/HPCC-Platform.git'" "${CLONE_LOG_FILE}"
                                    repo='git@github.com:hpcc-systems/HPCC-Platform.git'
                                    ;;

            esac

            TRY_COUNT=$(( $TRY_COUNT-1 ))
            if [[ $TRY_COUNT -ne 0 ]]
            then
                WriteLog "Wait for ${TRY_DELAY} to try again." "${CLONE_LOG_FILE}"
                sleep ${TRY_DELAY}
                continue
            else
                break;
            fi
        fi
    done

    WD_PID=$( cat ./WatchDog.pid )
    WriteLog "Kill WatchDog (${WD_PID})." "${CLONE_LOG_FILE}"

    KillWatchDogAndWaitToDie "${WD_PID}" "${CLONE_LOG_FILE}"

    if [[ $TRY_COUNT -eq 0 ]]
    then
        WriteLog "Give up ! " "${CLONE_LOG_FILE}"
        # send email to Agyi
        return 1
    fi
    
    WriteLog "End." "${CLONE_LOG_FILE}"
    return 0
}
    

SubmoduleUpdate()
{
    LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
    SUBMODULE_LOG_FILE=$OBT_BIN_DIR/SubmoduleUpdate-${LONG_DATE}.log
    WATCHDOG_LOG_FILE=${OBT_LOG_DIR}/WatchDog-$(date "+%Y-%m-%d_%H-%M-%S").log

    if [ -f "$OBT_BIN_DIR/WatchDog.py" ]
    then
        watchDogStartCmd="$OBT_BIN_DIR/WatchDog.py -p 'git-*' -t 360 -r 3600 -v"
        WriteLog "Start WatchDog: ${watchDogStartCmd}" "${SUBMODULE_LOG_FILE}"
        WriteLog "Watchdog logfile: ${WATCHDOG_LOG_FILE}" "${SUBMODULE_LOG_FILE}"
        ${watchDogStartCmd} >> ${WATCHDOG_LOG_FILE} 2>&1 &
        echo $! > ./WatchDog.pid
        WriteLog "WatchDog pid: $( cat ./WatchDog.pid )." "${SUBMODULE_LOG_FILE}"
    fi

    TRY_COUNT=20
    TRY_DELAY=3m

    export GIT_CURL_VERBOSE=1
    export GIT_CURL_RETRY=10
    export CURLOPT_RETRY=10
    export CURL_RETRY=10

    NO_ERROR=0
    SINGLE_REVISION_NEEDED_ERROR=1
    RECOVERABLE_ERROR=2
    NOT_GIT_REPO_ERROR=3

    WriteLog "git submodule update $1" "${SUBMODULE_LOG_FILE}"
    WriteLog "[$( caller )] $*" "${SUBMODULE_LOG_FILE}"
    while true
    do
        WriteLog "Try count: ${TRY_COUNT}" "${SUBMODULE_LOG_FILE}"
        res=''
        err=$NO_ERROR

        
        while read line
           do
               WriteLog "${line}" "${SUBMODULE_LOG_FILE}" # >> "${SUBMODULE_LOG_FILE}"
               if [ $err -ne  $NO_ERROR ] 
               then
                    continue
                fi

               res=$( echo "${line}" | grep -E -i '^fatal' | grep -E -c -i 'Needed a single revision' )
               if [ $res -ne 0 ]
               then
                   err=$SINGLE_REVISION_NEEDED_ERROR
                   break
               fi
               
               res=$( echo "${line}" | grep -E -i '^fatal' | grep -E -c -i 'Not a git repository' )
               if [ $res -ne 0 ]
               then
                   err=$NOT_GIT_REPO_ERROR
                   break
               fi

               res=$( echo "${line}" | grep -E -c -i '^fatal|^error|Killed|failed' )
               if [ $res -ne 0 ]
               then
                   err=$RECOVERABLE_ERROR
                   break
               fi

           done < <(  git submodule update $1 2>&1 ) 

        if [ $err -eq  $NO_ERROR ] 
        then 
            WriteLog "Submodule update finished ! " "${SUBMODULE_LOG_FILE}"
            break
        else
            set -x
            WriteLog "Error: $err" "${SUBMODULE_LOG_FILE}"

            case $err in
                $SINGLE_REVISION_NEEDED_ERROR ) 
                                      WriteLog "res: $err -> 'SINGLE_REVISION_NEEDED_ERROR'" "${SUBMODULE_LOG_FILE}"
                                      while read module
                                      do
                                          WriteLog "module: ${module}" "${SUBMODULE_LOG_FILE}"
                                          cleanUpCmd="rm -rfv ${module}"
                                          WriteLog "cmd: ${cleanUpCmd}" "${SUBMODULE_LOG_FILE}"
                                          ${cleanUpCmd} >> ${SUBMODULE_LOG_FILE} 2>&1
                                          WriteLog "retcode:$?" "${SUBMODULE_LOG_FILE}"
                                      done < <(  git config --file .gitmodules --get-regexp path | awk '{ print $2 }' )
                                      ;;

                $RECOVERABLE_ERROR ) WriteLog "res: $err -> 'RECOVERABLE_ERROR'" "${SUBMODULE_LOG_FILE}"
                                      while read submodule
                                      do
                                          WriteLog "submodule: ${submodule}" "${SUBMODULE_LOG_FILE}"
                                          cleanUpCmd2="rm -rfv ${submodule}"
                                          WriteLog "cmd: ${cleanUpCmd2}" "${SUBMODULE_LOG_FILE}"
                                          ${cleanUpCmd2} >> ${SUBMODULE_LOG_FILE} 2>&1
                                          WriteLog "retcode:$?" "${SUBMODULE_LOG_FILE}"
                                      done < <( git config --file .gitmodules --get-regexp path | awk '{ print $2 }' )
                                      ;;

                 $NOT_GIT_REPO_ERROR ) WriteLog "res: $err -> 'NOT_GIT_REPO_ERROR'" "${SUBMODULE_LOG_FILE}"                   
                                        TRY_COUNT=0
                                        break
                                        ;;

            esac
            set +x
            TRY_COUNT=$(( $TRY_COUNT-1 ))
            if [[ $TRY_COUNT -ne 0 ]]
            then
                WriteLog "Wait for ${TRY_DELAY} to try again." "${SUBMODULE_LOG_FILE}"
                sleep ${TRY_DELAY}
                continue
            else
                break;
            fi
        fi
       
    done

    WD_PID=$( cat ./WatchDog.pid )
    WriteLog "Kill WatchDog (${WD_PID})." "${SUBMODULE_LOG_FILE}"

    KillWatchDogAndWaitToDie "${WD_PID}" "${SUBMODULE_LOG_FILE}"


    if [[ $TRY_COUNT -eq 0 ]]
    then
        WriteLog "Give up ! " "${SUBMODULE_LOG_FILE}"
        # send email to Agyi
        return 1
    fi
    
    WriteLog "End." "${SUBMODULE_LOG_FILE}"
    return 0
}

