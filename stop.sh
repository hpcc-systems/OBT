#!/bin/bash

HPCC_RUNNING=$( sudo service hpcc-init status | grep -c "running")

echo $HPCC_RUNNING' running component(s)'
if [[ $HPCC_RUNNING -ne 0 ]]
then
    echo "Stop HPCC System..."
    res=$(sudo service hpcc-init stop |grep 'still')
    
    # If the result is "Service dafilesrv, mydafilesrv is still running."
    if [[ -n $res ]]
    then
        echo $res
        sudo service dafilesrv stop
    fi
else
    echo "HPCC System already stopped."
fi

HPCC_RUNNING=$( sudo service hpcc-init status | grep -c "running")

if [[ $HPCC_RUNNING -ne 0 ]]
then
    echo $HPCC_RUNNING" components are still up!"
    exit -1
else
    echo "All components are down!"
fi

