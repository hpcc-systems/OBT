#!/bin/bash

echo "Start $0"

if [[ -f ~/build/bin/settings.sh ]] 
then
    echo "source settings.sh..."
    . ~/build/bin/settings.sh
else
    echo "File: '~/build/bin/settings.sh' not found. Exit."
    exit -1
fi
echo "   Done."

if [[ "$OBT_ID" =~ "OBT-AWS" ]]
then
    SSH_KEYFILE="~/HPCC-Platform-Smoketest.pem"
    SSH_TARGET="3.99.109.118"   #SmoketestScheduler instance in AWS CA-Central
    SSH_OPTIONS="-oConnectionAttempts=2 -oConnectTimeout=10 -oStrictHostKeyChecking=no"
else
    SSH_KEYFILE="~/hpcc_keypair.pem"
    SSH_OPTIONS="-oConnectionAttempts=3 -oConnectTimeout=20 -oStrictHostKeyChecking=no"
    SSH_TARGET="10.224.20.54"   #OpenStack Region 8
fi

YM=$(date +%Y-%m)
echo "Current year and month: $YM"

pushd $HOME

echo "Start hthor log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'hthor.*.log' -type f -print | grep -E $YM | sort | zip -u HthorLogCollection-$YM -@ > HthorLogCollection-$YM.log &

echo "Start thor log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'thor.*.log' -type f -print | grep -E $YM | sort | zip -u ThorLogCollection-$YM -@ > ThorLogCollection-$YM.log &

echo "Start roxie log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'roxie.*.log' -type f -print | grep -E $YM | sort | zip -u RoxieLogCollection-$YM -@  > RoxieLogCollection-$YM.log &

echo "Start unit test log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'unittest*.log' -type f -print | grep -E $YM | sort | zip -u UnittestsLogCollection-$YM -@  > UnittestsLogCollection-$YM.log &

echo "Start ML test log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'ml*.log' -type f -print | grep -E $YM | sort | zip -u MlLogCollection-$YM -@  > MlLogCollection-$YM.log &

echo "Start WUTool test log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'wutooltest*.log' -type f -print  | grep -E $YM | sort | zip -u WutooltestLogCollection-$YM -@  > WutooltestLogCollection-$YM.log &

echo "Start build log collection..."
exec find ${STAGING_DIR_ROOT} -iname '*build*.log' -type f -print | grep -E $YM | sort | zip -u BuildLogCollection-$YM  -@  > BuildLogCollection-$YM.log &

echo "Start misc (report.htm, GlobalExclusion and git_2days) log collection..."
exec find ${STAGING_DIR_ROOT} -iname 'report.html' -o -iname 'GlobalExclusion.log' -o -iname 'git_2days.log' -type f | grep -E $YM | sort | zip -u MiscLogCollection-$YM  -@  > MiscLogCollection-$YM.log &

echo "Wait for processes finished."

wait 

echo "All processes are finished."
popd 

echo "Upload results.."

rsync -va -e "ssh -i  ${SSH_KEYFILE} ${SSH_OPTIONS}" ~/*LogCollection* centos@${SSH_TARGET}:/home/centos/OBT/${OBT_ID}

echo "Upload done."

echo "End."

