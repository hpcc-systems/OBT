OUTTER_LOOP_COUNT=2
INNER_LOOP_COUNT=10
TARGET="hthor"
TEST_SET="02bb_sort.ecl"

START_STACK_MONITOR=1

clear

ulimit -s 81920
ulimit -u 524288
ulimit -n 524288
ulimit -c unlimited

echo "ulimits: $( ulimit -a | grep -E '[pr]ocesses|open|stack|core' )"

printf " Outter loop         : %6d\n" "${OUTTER_LOOP_COUNT}"
printf " inner loop          : %6d\n" "${INNER_LOOP_COUNT}"
printf " number of executions: %6d\n" "$(( $OUTTER_LOOP_COUNT * $INNER_LOOP_COUNT ))"
printf " Test set            : '%s'\n" "${TEST_SET}"
printf " Target(s)           : '%s'\n\n" "${TARGET}"

STACK_MONITOR_PID=

if [[ $START_STACK_MONITOR -eq 1 ]]
then
    printf "Start Stack monitor..." 
    $HOME/build/bin/stackMonitor.sh > /dev/null 2>&1 &
    STACK_MONITOR_PID=$(pgrep stackMonitor)
    printf "Stack monitor pid : %d\n" "$STACK_MONITOR_PID"
    printf "Res: '%s'\n" "$res"
fi

pushd ~/build/CE/platform/HPCC-Platform/testing/regress/

for (( i=1; i<=$OUTTER_LOOP_COUNT; i++ ))
do 
    echo "Loop:$i" 
    sudo /etc/init.d/hpcc-init start

    for (( j=1; j <=$INNER_LOOP_COUNT; j++ ))
    do 
        echo "Exec:$j"
        suffix=$( printf "F542D241_L%03d_E%02d" "$i" "$j" )
        echo $suffix

        CMD="./ecl-test query -t ${TARGET} --suiteDir /home/vamosax/perftest/PerformanceTesting/PerformanceTesting --timeout  -3600 -fthorConnectTimeout=36000 -e stress --pq 1 --flushDiskCache --flushDiskCachePolicy 1 --jobnamesuffix ${suffix} ${TEST_SET}"

    ${CMD}

        echo "-------------------------------------"
    done

    sudo /etc/init.d/hpcc-init stop
    sudo service dafilesrv stop

    echo "======================================"
done

popd

sudo /etc/init.d/hpcc-init start
if [[ -n $STACK_MONITOR_PID ]]
then
    printf "Kill stack monitor (pid:%s)\n" "$STACK_MONITOR_PID"
    sudo kill -9 $STACK_MONITOR_PID
    STACK_MONITOR_PID=$(pidof stackMonitor)
    [[ -z $STACK_MONITOR_PID ]] && echo "Killed" || echo "Failed to kill"
fi


echo "End."
