#!/bin/bash
touch  clean.failed
rpm -qa | grep hpcc | grep -v grep | \
while read hpcc_package
do
   rpm -e $hpcc_package
done


rpm -qa | grep -v grep | grep hpcc > /dev/null 2>&1
if [ $? -eq 0 ]
then
   touch  clean.failed
   exit
fi

# Post uninstall
rm -rf /var/*/HPCCSystems/*
rm -rf /*/HPCCSystems 
userdel hpcc  
rm -rf /Users/hpcc 
rm -rf /tmp/remote_install 
rm -rf /home/hpcc



