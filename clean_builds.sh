#!/bin/bash
REPORT_DIR=/tmount/data2/nightly_builds/HPCC/4.2
[ -n "$1" ] && RREPORT_DIR=$1

buildsToKeep=14

cd  $REPORT_DIR 
i=0
ls $REPORT_DIR | sort -r | \
while read file
do
  i=$(expr $i \+ 1)
  #echo $file
  if [ $i -gt $buildsToKeep ] 
  then
     echo "Will remote build $file"
     rm -rf $file
  fi
   
done
