#!/bin/bash

clear 

#
#------------------------------
#
# Imports (settings, functions)
#

# Git branch settings

. ./settings.sh

# WriteLog() function

. ./timestampLogger.sh

#
#------------------------------
#
# Constants
#

ROOT=~
BIN_DIR=${ROOT}/build/bin
TEST_ROOT=${ROOT}/build/CE/platform
TEST_HOME=${TEST_ROOT}/HPCC-Platform/testing/regress 
BUILD_DIR=${TEST_ROOT}/build
COVERAGE_ROOT=${ROOT}/HPCC-Platform-coverage
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S") 
COVERAGE_LOG_FILE=${COVERAGE_ROOT}/individualCoverage-${LONG_DATE}.log 
FILE_MASK='*.ecl'

DEBUG=0
DRY_RUN=0
ONLY_STARTUP=0
START_UP=1
FIRST_ONLY=0

TARGET=thor

declare -A testCases

#
#-----------------------------------------
#
# Functions

ReadTestCases()
{

    echo "ECl dir: $1"
    echo "Target: $2"

    _pwd=$( pwd )
    cd $1
    target=$2

    testCs=( $(find . -maxdepth 1 -name "${FILE_MASK}" -type f | sort) )

    testCases=()
    for test in ${testCs[@]}
    do
        #echo "Test case:"$test
        versions=$( grep '^//version' $test | awk '{print $2}' )
        if [ -n "$versions" ]
        then
            for version in ${versions[@]}
            do
                #echo "version:$version"

                ls=(${version//,/ })
                local versionId=""
                for item in ${ls[@]}
                do 
                    #echo "    item:'$item'"
                    case $item in
                        no*) 
                            plat=$( echo $item | grep 's/no//' )

                            ;;
                        *)  #echo "            versionId:$versionId"
                            versionId=$versionId"-D\"${item}\" "
                            #echo "    updated versionId:$versionId"
                            ;;
                    esac

                done
                #echo "     versionID:$versionId"
                newItem=($(echo ${test} | sed 's/^\.\///' )" ${versionId}"$'\n')
                #echo "    New item:${newItem}"
                testCases+="${newItem}"
            done
        else
            newItem=($(echo ${test} | sed 's/^\.\///')$'\n')
            testCases+="${newItem}"
        fi
    done

    cd ${_pwd}
}

ListTestCases()
{
    IFS=:$'\n'
    lineNo=1
    for line in ${testCases[*]}
    do
        echo $lineNo": $line"
        lineNo=$(( ${lineNo} + 1 ))
    done
    echo ""
}

CleanUpCoverageData()
{
    WriteLog "Clean-up coverage data" "${COVERAGE_LOG_FILE}"
    echo "Clean-up coverage data"

    sudo find ${BUILD_DIR} -name "*.dir" -type d -exec chmod -R 777 {} \; 
    res=$( sudo lcov --zerocounters --directory ${BUILD_DIR} 2>&1 )
    retCode=$( echo $? )
    if [ ${retCode} -ne 0 ]
    then
        WriteLog "Error in cleanup! retCode:"$retCode" res:"$res "${COVERAGE_LOG_FILE}"
        echo "Error in cleanup! retCode:"$retCode" res:"$res

        exit
    fi
}
 

GenerateCoverageReport()
{
    WriteLog "Generate coverage data for $1" "${COVERAGE_LOG_FILE}"
    echo "Generate coverage data for $1"

    res=$( sudo lcov --quiet --capture --directory ${BUILD_DIR} --output-file ${COVERAGE_ROOT}/hpcc_$1_coverage.lcov 2>&1 )
    if [ ${retCode} -ne 0 ]
    then
        WriteLog "Error in processsing! retCode:"$retCode" res:"$res "${COVERAGE_LOG_FILE}"
        echo "Error in processing! retCode:"$retCode" res:"$res

        exit
    else
        if [ -n "$res" ]
        then
            echo $res > ${COVERAGE_ROOT}/hpcc_$1_coverage.log
        fi
    fi
}

GenerateCoverageFor()
{
    if [[ $DRY_RUN -eq 0 ]]
    then
        CleanUpCoverageData

        WriteLog "Start HPCC-System" "${COVERAGE_LOG_FILE}"
        sudo ${BIN_DIR}/start.sh
    fi

    if [ "$1" != "" ]
    then
        cmd="ecl run -t $2 ecl/$1"
        echo "CMD:${cmd}"
        WriteLog "CMD: ${cmd}" "${COVERAGE_LOG_FILE}"
        if [[ $DRY_RUN -eq 0 ]]
        then
            res=$( $cmd 2>&1 )
            #echo $res
            echo ""
        fi
    fi;

    if [[ $DRY_RUN -eq 0 ]]
    then
        WriteLog "Stop HPCC-System" "${COVERAGE_LOG_FILE}"
        sudo ${BIN_DIR}/stop.sh

        GenerateCoverageReport $3
    fi
}

#
#-----------------------------------------
#
# Main start

[ ! -e $COVERAGE_ROOT ] && mkdir -p $COVERAGE_ROOT

rm -rf ${COVERAGE_ROOT}/* 

WriteLog "Individual Coverage generation started" "${COVERAGE_LOG_FILE}" 

echo "Start..."

WriteLog "Target is ${TARGET}" "${COVERAGE_LOG_FILE}"

WriteLog "Read testcases" "${COVERAGE_LOG_FILE}"
ReadTestCases ${TEST_HOME}/ecl $TARGET

IFS=:$'\n'

maxTestCase=${#testCases[@]}
WriteLog "Number of testcases is ${maxTestCase}" "${COVERAGE_LOG_FILE}"

echo "Number of Testcases: ${maxTestCase}"
if [[ $DEBUG -eq 1 ]]
then
    ListTestCases "$testCases"
fi

#
#-----------------------------------------
#
# Stop HPCC system

WriteLog "Stop HPCC Systems" "${COVERAGE_LOG_FILE}" 
echo "Stop HPCC Systems"
sudo ${BIN_DIR}/stop.sh 

#
#-----------------------------------------
#
# Collect coverage for start-stop only
#

if [[ $START_UP -eq 1 ]]
then
    WriteLog "Collect coverage for start-stop only" "${COVERAGE_LOG_FILE}" 
    echo "Collect coverage for start-stop only"

    GenerateCoverageFor "" "" "Start-Stop"
else
    WriteLog "Skip coverage for start-stop" "${COVERAGE_LOG_FILE}" 
    echo "Skip coverage for start-stop"
fi

#
#-----------------------------------------
#
# Generate coverage for individual test cases

if [[ $ONLY_STARTUP -eq 0 ]]
then

    WriteLog "Start generate coverage for individual test cases" "${COVERAGE_LOG_FILE}" 
    echo "Start generate coverage for individual test cases"
    
    index=1
    pwd=$( pwd )
    
    cd ${TEST_HOME}
    
    for test in ${testCases[@]}
    do
        
        msg=$( printf "%3d/%3d. %s\n" ${index} ${maxTestCase} ${test} )
        echo $msg
        WriteLog "${msg}" "${COVERAGE_LOG_FILE}"
    
        if true
        then
            GenerateCoverageFor ${test} ${TARGET} "${test}-${TARGET}"
        else
            cmd="ecl run -t ${TARGET} ecl/${test}"
            echo "CMD:${cmd}"

            echo $res
            echo ""
        fi
    
        index=$(($index+1))
    
        if [[ $FIRST_ONLY -eq 1 ]]
        then
            WriteLog "It was a first only call. Stop testing more test cases." "${COVERAGE_LOG_FILE}" 
            echo "It was a first only call.  Stop testing more test cases."
    
            break
        fi
    
    done
    
    cd ${pwd}
fi

echo "End."
WriteLog "End." "${COVERAGE_LOG_FILE}"
