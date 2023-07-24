#!/bin/bash

dumpstacks()
{
    local processName=$1
    local binPath=$( find /opt/HPCCSystems/ -iname ${processName} -type f 2>&1 )
    if [[ -n "$binPath" ]]
    then
        pids=$(pidof ${processName})
        if [[ -n $pids ]]
        then
            for p in $(pidof ${processName})
            do
                echo "${processName}[${p}] stacks:"
                sudo gdb --batch --quiet -ex "set interactive-mode off" -ex "thread apply all bt" -ex "quit" ${binPath} ${p}
            done
        else
            echo "No pid found for ${processName}"
        fi
    else
            echo "${processName} binary not found."
    fi
    echo '==============='
    echo
}

echo 'List of processes:'
ps aux 
echo '==============='
echo
 
dumpstacks daserver
dumpstacks esp
dumpstacks ecl
dumpstacks eclcc

daliadminPath=$( find /opt/HPCCSystems/ -iname 'daliadmin' -type f 2>&1 )
if [[ -n "$daliadminPath" ]]
then
    echo 'job queues meta data:'
    eval ${daliadminPath} . export /JobQueues jq.xml
    cat jq.xml
else
    echo "daliadmin not found"
fi
echo '***************'    
