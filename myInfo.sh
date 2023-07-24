#!/bin/bash

LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S") 
LOGFILE=myInfo-${LONG_DATE}.log

while ( true )
do 
    echo $(date "+%Y-%m-%d %H:%M:%S")" jinst: $( ps aux | grep '[j]ava' | wc -l), proc: $(ps -LF | wc -l)/$(ps -eLF | wc -l), M:$(  free -g | grep -E "^(Mem)" | awk '{print $4"GB from "$2"GB" }' ) " >>  ${LOGFILE}
    sleep 1; 
done;
