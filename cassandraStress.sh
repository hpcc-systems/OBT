#!/bin/bash

REGRESS_PATH=~/test/HPCC-Platform/testing/regress/

TARGETS=( hthor thor roxie )
LONG_DATE=$(date +%Y-%m-%d_%H-%M-%S);

LOGFILE=~/iter-log-${LONG_DATE}.log
RESFILE=~/iter-res-${LONG_DATE}.log


ShowRes()
(
    IFS=$'\n'
    for line in $1
    do
        echo $line >> ${LOGFILE} 
    done
    #echo ""
)


echo "Start..." > ${LOGFILE}
echo "Start..." > ${RESFILE}


for target in ${TARGETS[@]}
do
    iter=1
    while true
    do 
        echo "Target:"${target}", iteration:"$iter
        echo "Target:"${target}", iteration:"$iter >> ${LOGFILE} 
        echo "Target:"${target}", iteration:"$iter >> ${RESFILE} 

        res=$( ecl run -v -t ${target} ${REGRESS_PATH}ecl/cassandra-simple.ecl 2>&1 )
        ShowRes "$res"  
        # echo $res

    pass=$( echo ${res} | grep '<Result_18>Done' )
    if [ -z "${pass}" ]
    then
        echo "Fail"
        echo "Fail" >> ${RESFILE}
    else
        echo "Pass"
        echo "Pass" >> ${RESFILE}


    fi

        echo "" >> ${LOGFILE}

    sleep 10

        echo "------------------------------------------"
        echo "------------------------------------------" >> ${LOGFILE}
        echo "------------------------------------------" >> ${RESFILE}

        iter=$(( $iter + 1 ))
        if [ ${iter} -eq 11 ]
        then
            break;
        fi
    
    done
done

echo "End." >> ${LOGFILE}
echo "End." >> ${RESFILE}

