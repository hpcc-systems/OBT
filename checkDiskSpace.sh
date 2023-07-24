#!/bin/bash

LOG_DIR=~/build/bin
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
DISK_SPACE_LOG_FILE=${LOG_DIR}/diskspace-${LONG_DATE}.log
MEM_SPACE_LOG_FILE=${LOG_DIR}/memspace-${LONG_DATE}.log

#
#-----------------------------------------
#
# Functions

WriteLog()
(
    TIMESTAMP=$( date +%Y-%m-%d_%H-%M-%S)
    printf "%s:%s\n" "${TIMESTAMP}" "$1" >> $2
)

# Run if user hits control-c
ControlC()
{
  echo "\n*** KILL signal recived! Exiting ***\n"
  WriteLog "End." "${DISK_SPACE_LOG_FILE}"
  WriteLog "End." "${MEM_SPACE_LOG_FILE}"

  exit $?
}

WriteHeaders()
{
    # Print disk space header
    header1=$(df -h . | grep -E "^(Filesystem)" | tr '\n' ' ')
    header2=$(df -hP . | grep -E "^(Filesystem)" | tr '\n' ' ')
    header="${header1}    ${header2}"

    WriteLog "${header}" "${DISK_SPACE_LOG_FILE}"

    # Print memory space header
    header=$(free | grep -E "^(\s)" | tr '\n' ' ')
    WriteLog "${header}" "${MEM_SPACE_LOG_FILE}"
}

#
#-----------------------------------------
#
# Main start

WriteLog "Disk space logger started." "${DISK_SPACE_LOG_FILE}"
WriteLog "Memory space logger started." "${MEM_SPACE_LOG_FILE}"

# trap keyboard interrupt (control-c)
trap ControlC SIGINT
trap ControlC SIGTERM
trap ControlC SIGKILL

WriteHeaders

while true
do 
    myDs1=$(df -lh  . | grep -E "^(/dev/)" | tr '\n' ' ')

    # On our testfarm /var/lib located on other partition/disk
    myDs2=$(df -Ph  /var/lib | grep -E "^(/dev/)" | tr '\n' ' ')

    myDs="${myDs1}    ${myDs2}"

    WriteLog "${myDs}" "${DISK_SPACE_LOG_FILE}"
 
    myMem=$( free | grep -E "^(Mem|Swap)" | tr '\n' ' ')
    WriteLog "${myMem}" "${MEM_SPACE_LOG_FILE}"

    sleep 10
done

