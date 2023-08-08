#!/bin/bash

ENGINE=hthor
ENGINE_BIN="/opt/HPCCSystems/bin/hthor"
LOG_FILE_NAME="$ENGINE-$( date +%Y-%m-%d-%H-%M-%S ).log"

TOP_LOG=1
AFFINITY_CHECK=1

echo "$0 start."
echo "Log file: '${LOG_FILE_NAME}'"
echo "$0 start." > $LOG_FILE_NAME

echo "CPU info:"  >> ${LOG_FILE_NAME}
cat /proc/cpuinfo >> ${LOG_FILE_NAME}
echo "================================"  >> ${LOG_FILE_NAME}

while [ true ]
do
        pid=$( pidof ${ENGINE} )

        if [[ -n "${pid}" ]]
        then
                echo "${ENGINE} pid: '${pid}' @$( date +%Y-%m-%d-%H-%M-%S ):" >> ${LOG_FILE_NAME}
                echo "----------------------------------------"  >> ${LOG_FILE_NAME}
    
        if [[ AFFINITY_CHECK -eq 1 ]]
        then
            # run affinity check script only once
            AFFINITY_CHECK=0
            ./tidAffinityCheck.sh "hthor" >> ${LOG_FILE_NAME}
            echo "............................." >> ${LOG_FILE_NAME}
        fi

        if [[ TOP_LOG -eq 1 ]]
                then
            echo "$( top -H -b -n 1 | head -n 20 )" >> ${LOG_FILE_NAME}
            echo "............................." >> ${LOG_FILE_NAME}
            top -H -b -n 1 -p ${pid} >> ${LOG_FILE_NAME}
                        echo "............................." >> ${LOG_FILE_NAME}
        fi
                echo "Stack traces of ${ENGINE}"  >> ${LOG_FILE_NAME}
                sudo gdb --batch --quiet -ex "set interactive-mode off" -ex "thread apply all bt" -ex "quit" ${ENGINE_BIN} ${pid} >> ${LOG_FILE_NAME} 2>&1
        else
                echo "pid: 'none' $( date +%Y-%m-%d-%H-%M-%S ):" >> ${LOG_FILE_NAME}
        fi
        echo "================================"  >> ${LOG_FILE_NAME}
        echo ""  >> ${LOG_FILE_NAME}

        sleep 10
done

echo "$0 End." >> $LOG_FILE_NAME
echo "End."

