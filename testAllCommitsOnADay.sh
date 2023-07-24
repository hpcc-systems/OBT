#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }' 
#set -x

#
#------------------------------
#
# Imports (settings, functions)
#

# Git branch settings

. ./settings.sh

#
#------------------------------
#

SOURCE_PATH=~/build/CE/platform/HPCC-Platform
if [ ! -d $SOURCE_PATH ]
then
    SOURCE_PATH=~/HPCC-Platform
    if [ ! -d $SOURCE_PATH ]
    then
        echo "$SOURCE_PATH does not exist."
        exit
    fi
fi

BRANCH_ID=master
DEBUG=0
PERFORMANCE_QUERY_LIST="01* 02* 03* 04* 05* 06* 07*"
targetFile="${PWD}/settings.inc"

TEST_DATE="2017-12-05"
before=4
after=2

GetAllCommitsShaOnDay()
{
#    set -x
    TEST_DATE=$1
    before=$2
    after=$3
 
    if [[ -n $before ]]
    then
        SOURCE_DATE=$( date -I -d "$TEST_DATE - $before day" )
    else
        SOURCE_DATE=$( date -I -d "$TEST_DATE - 1 day" )
    fi
 
    if [[ -n $after ]]
    then
        TEST_DATE=$( date -I -d "$TEST_DATE + $after day" )
    fi
    
    printf "On %s (Between %s and %s)\n" "$1" "$SOURCE_DATE" "$TEST_DATE"
    pushd ${SOURCE_PATH} > /dev/null

    # to restore whole commit tree
    git checkout -f ${BRANCH_ID} 2> /dev/null
    
    while read c
    do 
        #echo "commit: $c"
        commits+=($(printf "%s\n" "$c" ))
        #echo "len: ${#commits[@]}"
        #echo "commits: ${commits[@]} "
    done < <(git log --after="$SOURCE_DATE 00:00" --before="$TEST_DATE 00:00$" --merges --reverse | grep 'commit' | cut -d' ' -f2)
    #echo "len: ${#commits[@]}"
    #echo "${commits[@]}"
    
    popd > /dev/null
#    set +x
}


printf "On %s\n" "$TEST_DATE"
GetAllCommitsShaOnDay "$TEST_DATE" "$before" "$after"

if [ $DEBUG -eq 1 ]
then
    echo "len: ${#commits[*]}"
    echo "${commits[@]}"
fi

COMMIT_COUNT=${#commits[*]}
i=0

if [ $DEBUG -eq 0 ] 
then
    sudo service ntpd stop
fi

IS_SCL=$( type "scl" 2>&1 )
if [[ "${IS_SCL}" =~ "not found" ]]
then 
    printf "SCL is not installed."
else 
    id=$( scl -l | grep -c 'devtoolset' )
    if [[ $id -ne 0 ]]
    then
        DEVTOOLSET=$(  scl -l | tail -n 1 )
        printf "%s is installed." "${DEVTOOLSET}"
        . scl_source enable ${DEVTOOLSET}
        export CL_PATH=/opt/rh/${DEVTOOLSET}/root/usr;
    else
        printf "DEVTOOLSET is not installed."
    fi
fi

printf "Commit\n"
for TEST_SHA in ${commits[@]}
do 
    printf "%s\n" $TEST_SHA
    
    # create setting.inc with SHA
    printf "# test date:%s \n" "$TEST_DATE" > ${targetFile}
    printf "SHA=%s\n\n" "$TEST_SHA" >> ${targetFile}
    printf "PERFORMANCE_QUERY_LIST=\"%s\"\n\n" "$PERFORMANCE_QUERY_LIST" >> ${targetFile}

    if [ $DEBUG -eq 0 ] 
    then
        # magic with date set it back to original test date (one minute after midnight)
        sudo date -s "$TEST_DATE $i:01:00"
        date
        
        # Execute OBT with performance test
        ./obtMain.sh perf
        
        rename 6.5.0.csv 6.5.0-${TEST_SHA:0:8}.csv ~/Perfstat/*.csv
        rename 6.4.1.csv 6.4.1-${TEST_SHA:0:8}.csv ~/Perfstat/*.csv
  
        #  Restore the correct date with NTPD 
        sudo ntpdate time.nist.gov
        date
    fi

    i=$(( $i + 1 ))
    
    if [ $DEBUG -eq 1 ]
    then
        if [[ $i -gt 10 ]]
        then
            break
        fi
    fi
done

if [ $DEBUG -eq 0 ] 
then
    sudo service ntpd start
fi

printf "On %s there were %d commits \n" $TEST_DATE $COMMIT_COUNT
