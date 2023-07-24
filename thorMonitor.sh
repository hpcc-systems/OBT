#!/bin/bash

# while true; do failed=$( tail -n100 regress-2019-10-28_09-23-43.log | grep -E -c  'Fail' ); echo -e $(date "+%Y-%m-%d %H:%M:%S: ")$failed; if [[ $failed -ge 5 ]]; then sudo service hpcc-init -c mythor restart; sudo service hpcc-init -c mythor restart; sleep 5m; fi; sleep 1m; done

while true
do
    echo -n $(date "+%Y-%m-%d %H:%M:%S:")" "

    # 1. Check if there is regress-2*.log file
    logFile=$( find . -maxdepth 1 -iname 'regress-2*.log' -type f -print )

    if [[ -z "$logFile" ]]
    then
        echo -n "No logfile"
    else
        # 2. check if current "Suite: thor" in regress log file

    echo -n " $logFile"
        isThor=$(  grep -E  'Suite: ' $logFile | tail -n 1 | grep -E -c 'thor' )

        if [[ $isThor -eq 0 ]]
        then
            echo -n ", Engine is not Thor."
        else
            echo -n ", Engine is Thor"

            failed=$( tail -n100 $logFile | grep -E -c  'Fail' )

            echo -n ", failed: $failed" 

            # 3. check if the number of Failed log lines is >= 10.
            if [[ $failed -ge 10 ]]; 
            then 
                echo ", restart Thor"
                # If yes, restart thor 
                sudo service hpcc-init -c mythor restart; 
                sudo service hpcc-init -c mythor restart; 
            fi
         fi
    fi

    echo ""

    sleep 5m;

done

