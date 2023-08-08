#!/usr/bin/bash

if [[ "$OBT_ID" =~ "OBT-AWS" ]]
then
    SSH_KEYFILE="~/HPCC-Platform-Smoketest.pem"
    SSH_TARGET="3.99.109.118"   #SmoketestScheduler instance in AWS CA-Central
    SSH_OPTIONS="-oConnectionAttempts=2 -oConnectTimeout=10 -oStrictHostKeyChecking=no"
else
    SSH_KEYFILE="~/hpcc_keypair.pem"
    SSH_TARGET="10.224.20.54"   #OpenStack Region 8
    SSH_OPTIONS="-oConnectionAttempts=5 -oConnectTimeout=20 -oStrictHostKeyChecking=no"
fi

rsync -va -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}"  ~/build/bin/OBT-*.txt centos@${SSH_TARGET}:/home/centos/OBT/${OBT_ID}/

date >> ~/diskState.log
df -h | grep -E 'Filesys|^/dev/*|common'  >> ~/diskState.log
echo "==============================================" >> ~/diskState.log

rsync -va -e "ssh -i ${SSH_KEYFILE} ${SSH_OPTIONS}"  ~/diskState.log  centos@${SSH_TARGET}:/home/centos/OBT/${OBT_ID}/

if [[ -d ~/Perfstat ]]
then
    # Archive previous month's perfstat files into 'perfstats-YYYY-MM.zip' file
    pushd ~/Perfstat
    
    PREV_MONTH=$(date --date "$today - 1month" +%m)
    PREV_MONTH_YEAR=$(date --date "$today - 1month" +%y)
    PREV_MONTH_YEAR_LONG=$(date --date "$today - 1month" +%Y)

    find . -iname 'perfstat-*-'$PREV_MONTH_YEAR$PREV_MONTH'*.c*' -type f -print | zip -m perfstats-$PREV_MONTH_YEAR_LONG-$PREV_MONTH.zip -@
    
    # Same for this month's perfstat files into 'perfstats-YYYY-MM.zip' file
    THIS_MONTH=$(date +%m)
    THIS_MONTH_YEAR=$(date +%y)
    THIS_MONTH_YEAR_LONG=$(date +%Y)
  
    find . -iname 'perfstat-*-'$THIS_MONTH_YEAR$THIS_MONTH'*.c*' -type f -print | zip -m perfstats-$THIS_MONTH_YEAR_LONG-$THIS_MONTH.zip -@
    
    popd
    
    rsync -va -e "ssh -i  ${SSH_KEYFILE} ${SSH_OPTIONS}"  ~/Perfstat/*  centos@${SSH_TARGET}:/home/centos/OBT/${OBT_ID}/Perfstat/
fi

vcpkgZips=$(find ~/ -maxdepth 1 -iname 'vcpkg_downloads-*[rx].zip' -type f )
if [[ -n "$vcpkgZips" ]]
then
    rsync -va -e "ssh -i  ${SSH_KEYFILE} ${SSH_OPTIONS}"  ~/vcpkg_downloads*.zip  centos@${SSH_TARGET}:/home/centos/OBT/
fi

