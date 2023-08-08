#!/bin/bash

#
#---------------------------------
#
# Import functions if not exists
#

# Git branch settings, etc

. ./settings.sh

# StopHpcc() function

declare -f -F StopHpcc> /dev/null

if [ $? -ne 0 ]
then
    . ./utils.sh
fi

# WriteLog() function

declare -f -F WriteLog > /dev/null

if [ $? -ne 0 ]
then

    . ./timestampLogger.sh
fi

# -----------------------------------------------------
# 
# Safe Uninstall HPCC Systems
# 
#

UninstallHPCC()
(
    logFile=$1

    if [[ "$2." == "." ]]
    then
        wipeOut=0
    else
        wipeOut=$2
    fi

    WriteLog "In UninstallHPCC()..." "$logFile"

    WriteLog "[$( caller )] $*" "$logFile"

    WriteLog "Uninstall HPCC started ($0)" "$logFile"
    WriteLog "Log file: ${logFile}" "$logFile"
    WriteLog "Wipe out: ${wipeOut}" "$logFile"

    uninstallFailed=FALSE
    
    if [[ $wipeOut -eq 1 && -f /opt/HPCCSystems/sbin/complete-uninstall.sh ]]
    then
        WriteLog "Stop HPCC Platform before remove it." "$logFile"
        StopHpcc "$logFile"
        
        WriteLog "Use 'complete-uninstall.sh' to remove HPCC." "$logFile"
        # Check '-p' parameter
        purge=$( /opt/HPCCSystems/sbin/complete-uninstall.sh -h | while read l; do [[ "${l}" =~ "-p, " ]] && echo "-p"; done )

        sudo /opt/HPCCSystems/sbin/complete-uninstall.sh $purge >> "$logFile" 2>&1
        [ $? -ne 0 ] && uninstallFailed=TRUE

    else
        if [ $wipeOut -eq 0 ]
        then
            WriteLog "Remove HPCC but keep data." "$logFile"
            StopHpcc "$logFile"
        else
            WriteLog "It seems HPCC Systems isn't istalled." "$logFile"
            
            # Check if any log directory left
            if [[ -d /var/log/HPCCSystems ]]
            then
                logDirLeft=( $( find /var/log/HPCCSystems/ -iname 'my*' -type d ) )

                if [[ ${#logDirLeft[@]} -ne 0 ]]
                then
                    WriteLog "It seems some log directory left. Remove them." "$logFile"
                    sudo rm -rf ${logDirLeft[*]}
                fi
            fi

        fi
        
        ( ${PKG_QRY_CMD} hpccsystems-platform ) | grep hpcc | grep -v grep |
        while read hpcc_package
        do
          WriteLog "HPCC package:"${hpcc_package} "$logFile"

          sudo ${PKG_REM_CMD} $hpcc_package  >> "$logFile" 2>&1

          [ $? -ne 0 ] && uninstallFailed=TRUE
        done
    
        ( ${PKG_QRY_CMD}  hpccsystems-platform ) | grep hpcc > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
            WriteLog "Can't remove HPCC package: ${hpcc_package}" "$logFile"
            uninstallFailed=TRUE
        fi
    fi
    
    ret=0
    getent passwd hppc >/dev/null 2>&1 && ret=1
    if [[ ${ret} -eq 1 ]]
    then
        WriteLog "hpcc user still exists" "$logFile"
    fi

    WriteLog "Check if any hpcc owned process is running" "$logFile"

    query="thor|roxie|d[af][fslu]|ecl[s|c|\s|a][g|c]|sase|topo|gdb"
    res=$(pgrep -l "${query}" 2>&1 )

    if [ -n "$res" ] 
    then
        WriteLog "res:${res}" "$logFile"
        res=$( sudo pkill -9 -e -c "${query}" )
        WriteLog "res:${res}" "$logFile"

        # Give it some time
        sleep 1m

        res=$(pgrep -l "${query}" 2>&1 )
        WriteLog "After pkill res:${res}" "$logFile"
    else
        WriteLog "There is no leftover process" "$logFile"
    fi

    if [ "$uninstallFailed" = "TRUE" ]
    then
        echo "TestResult:FAILED" >> uninstall.summary 
        WriteLog "Uninstall HPCC-Platform FAILED" "$logFile"
    
    else
        echo "TestResult:PASSED" >> uninstall.summary 
        WriteLog "Uninstall HPCC-Platform PASSED" "$logFile"

        if [ -f /etc/HPCCSystems/environment.xml ]
        then
            WriteLog "Remove environment.xml to ensure clean, out-of-box environment." "$logFile"
            sudo rm /etc/HPCCSystems/environment.xml
        fi
    fi

    WriteLog "Generate port usage summary file." "$logFile"
    portUsage="$( ss -antp4 2>&1 )"
    echo -e "Used ports before HPCC started:\n ${portUsage}" > usedPort.summary
)

# call arguments verbatim:
#"$@"
