#!/bin/bash

hpccRunning=$( sudo service hpcc-init status | grep -c "running")
if [[ $hpccRunning -gt 0 ]]
then
    echo "Stop HPCC System..."
    sudo service hpcc-init stop
fi
echo Start HPCC system
sudo service hpcc-init start

# give it some time
sleep 5

hpccRunning=$( sudo service hpcc-init status | grep -c "running")
if [[ $hpccRunning -ne 10 ]]
then
    echo "Only "$hpccRunning" components are up!"
    exit -1
else
    echo "All components are up!"
fi

