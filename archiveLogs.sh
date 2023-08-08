#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

#
#------------------------------
#
# Import settings
#
# Git branch, common macros, etc

. ~/build/bin/settings.sh

# WriteLog() function

. ~/build/bin/timestampLogger.sh

#
#------------------------------
#
# Constants
#
#

if [ -n $OBT_TIMESTAMP ] 
then 
    TIMESTAMP=${OBT_TIMESTAMP}
else
    TIMESTAMP=$(date "+%H-%M-%S")
fi

if [ -n $OBT_DATESTAMP ] 
then 
    DATE_SHORT=${OBT_DATESTAMP}
else
    
    DATE_SHORT=$(date "+%Y-%m-%d") 
fi

DATE=$(date "+%Y-%m-%d_%H-%M-%S") 

HPCC_LOG_DIR=/var/log/HPCCSystems
HPCC_BINARY_DIR=/var/lib/HPCCSystems
DALI_DIR=/var/lib/HPCCSystems/mydali
HPCC_BUILD_DIR=~/build/CE/platform/build
OBT_LOG_DIR=~/build/bin
TEST_LOG_DIR=~/HPCCSystems-regression
COVERAGE_LOG_DIR=~/coverage
ECLCC_DIR=/var/lib/HPCCSystems/myeclccserver


ARCHIVE_TARGET_DIR=~/HPCCSystems-log-archive
ARCHIVE_LOG_DIR=${OBT_LOG_DIR}/archiveLogs-${DATE}.log

TEST_LOG_SUBDIRS=('log' 'archives' 'results' 'zap')
MOVE_TO_ZIP_FLAG=''
MOVE_LOG_TO_ZIP_FLAG=-m
MOVE_OBT_CONSOLE_LOG_TO_ZIP_FLAG=''

IS_COVERAGE=
DO_ARCHIVE=1

#
#---------------------------------------
#
# Functions
#

CheckAndZip()
{
    #set -x

    flags=${1:-${MOVE_TO_ZIP_FLAG}}
    target=${2:-${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}}
    sourceDir=${3:-${OBT_LOG_DIR}}
    source=$4
    log=${5:-${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log}
 
    if [ -d "${sourceDir}" ]
    then
        res=$(find "${sourceDir}"/ -maxdepth 1 -name "$source" -print -quit)
    
        if test -n "$res"
        then
            zip ${flags} ${target} ${sourceDir}/${source} >> ${log}
    
        fi
    
        set +x
    fi
}



if [ ! -d $ARCHIVE_TARGET_DIR ]
then
    mkdir $ARCHIVE_TARGET_DIR
fi


ARCHIVE_NAME='Logs-archive'

while [ $# -gt 0 ]
do

    param=$1

    param=${param,,}
    WriteLog "param:${param}" "${ARCHIVE_LOG_DIR}"

    case $param in
        obt-build)  WriteLog "mode:OBT-build (log files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    ;;

        obt-exit*)  WriteLog "mode:OBT-exit-cleanup (log files move into archive, skip copy to wiki)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    MOVE_TO_ZIP_FLAG=-m
                    DO_ARCHIVE=1
                    MOVE_OBT_CONSOLE_LOG_TO_ZIP_FLAG=-m
                    ARCHIVE_NAME=obt-exit-cleanup
                    ;;

        *clean*)    WriteLog "mode:OBT-cleanup (log files move into archive, skip copy to wiki)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    MOVE_TO_ZIP_FLAG=-m
                    DO_ARCHIVE=0
                    MOVE_OBT_CONSOLE_LOG_TO_ZIP_FLAG=-m
                    ARCHIVE_NAME=obt-cleanup
                    ;;

        intern*)    WriteLog "mode:Internal testing (unit, wutool,  files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param

                    ;;


        obt*)       WriteLog "mode:OBT (files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    MOVE_TO_ZIP_FLAG=-m

                    ;;

        regr*)      WriteLog "mode:Regression (move test log files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    ;;
            

        perf*)      WriteLog "mode:Performance (log files copy into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    MOVE_LOG_TO_ZIP_FLAG=''
                    ;;

        coverage)   WriteLog "mode:Coverage (log files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    IS_COVERAGE=1
                    ;;

        ml*)        WriteLog "mode:ML (files move into archive)" "${ARCHIVE_LOG_DIR}"
                    ARCHIVE_NAME=$param
                    MOVE_TO_ZIP_FLAG=-m
                    ;;


        time*)      TIMESTAMP=${param//time*=/}
                    WriteLog "Archive timestamp is: '${TIMESTAMP}'" "${ARCHIVE_LOG_DIR}"
                    ;;

        nopub*)     WriteLog "Do not publish archive." "${ARCHIVE_LOG_DIR}"
            DO_ARCHIVE=0
                    ;;

        *)          MOVE_LOG_TO_ZIP_FLAG=''
                    ;;
    esac
    
    shift
done

FULL_ARCHIVE_TARGET_DIR=${ARCHIVE_TARGET_DIR}/$DATE_SHORT/${BRANCH_ID}/${TIMESTAMP}


WriteLog "Archive log dir: $FULL_ARCHIVE_TARGET_DIR" "${ARCHIVE_LOG_DIR}"

if [ ! -d $FULL_ARCHIVE_TARGET_DIR ]
then
    mkdir -p $FULL_ARCHIVE_TARGET_DIR
fi

ARCHIVE_NAME=${ARCHIVE_NAME}'-'${DATE}

WriteLog "Archive: $ARCHIVE_NAME" "${ARCHIVE_LOG_DIR}"

#
# --------------------------------
# Archive /tmp/build.log if exists
#

if [ -f /tmp/build.log ]
then
    WriteLog "Archive content of /tmp/build.log" "${ARCHIVE_LOG_DIR}"
    echo 'Archive content of /tmp/build.log' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    zip ${MOVE_OBT_CONSOLE_LOG_TO_ZIP_FLAG} ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}  /tmp/build.log >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi

if [ -f /tmp/build_sequencer.log ]
then
    WriteLog "Archive content of /tmp/build_sequencer.log" "${ARCHIVE_LOG_DIR}"
    echo 'Archive content of /tmp/build_sequencer.log' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    zip -u ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}  /tmp/build_sequencer.log >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi

#
# --------------------------------
# Archive /etc/HPCCSystems/environment.xml and .conf if exists
#

CheckAndZip "" "" "/etc/HPCCSystems" "environment.*" ""

#
# --------------------------------
# Archive logs from OBT_LOG_DIR (/root/build/bin)
#

WriteLog "Archive content of ${OBT_LOG_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${OBT_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

CheckAndZip "" "" "" "obt-*.log" ""
CheckAndZip "" "" "" "simple-*.log" ""
CheckAndZip "" "" "" "perftest-*.log"                ""
CheckAndZip "" "" "" "diskspace-*.log"               ""
CheckAndZip "" "" "" "memspace-*.log"                "" 
CheckAndZip "" "" "" "redis*.out"                    "" 
CheckAndZip "" "" "" "check*.log"                    "" 
CheckAndZip "" "" "" "Check*.log"                    "" 
CheckAndZip "" "" "" "Perf_*.log"                    "" 
CheckAndZip "" "" "" "uninst*.*"                     "" 
CheckAndZip "" "" "" "Core-gen-test-*.log"           "" 
CheckAndZip "" "" "" "CloneRepo-*.log"               "" 
CheckAndZip "" "" "" "SubmoduleUpdate-*.log"         "" 
CheckAndZip " "                   "" "" "*KnownProblems.csv"            "" 
CheckAndZip "" "" "" "unittest-*"                    "" 
CheckAndZip "" "" "" "unittests*.log"                 "" 
CheckAndZip "" "" "" "core_unittests*"               "" 

CheckAndZip "" "" "" "wutool*.log"                   "" 
CheckAndZip "" "" "" "wutool*.summary"               "" 
CheckAndZip "" "" "" "unittest-*.log"                "" 
CheckAndZip "" "" "" "WatchDog*.log"                 "" 
CheckAndZip "" "" "${HPCC_BUILD_DIR}/CMakeFiles" "CMakeOutput.log" "" 
CheckAndZip "" "" "${HPCC_BUILD_DIR}/CMakeFiles" "CMakeError.log"  "" 
CheckAndZip "" "" "" "usedPort.summary"              ""   

CheckAndZip "" "" "" "regress-*.log"                 "" 
CheckAndZip "" "" "" "Regression-*.csv"              ""
CheckAndZip "" "" "" "Regression-*.txt"              ""
CheckAndZip " "                   "" "" "git_2days.log"                 "" 
CheckAndZip "" "" "" "GlobalExclusion.log"           ""
CheckAndZip "" "" "" "setup_*.log"                    ""
CheckAndZip "" "" "" "*.summary"                     ""
CheckAndZip "" "" "" "hthor*.log"                    ""
CheckAndZip "" "" "" "thor*.log"                     ""
CheckAndZip "" "" "" "roxie*.log"                    ""
CheckAndZip "" "" "" "environment*"                  ""
CheckAndZip " "                   "" "" "BuildNotification.ini"         ""
CheckAndZip " "           "" "" "settings.*"                ""
CheckAndZip "" "" "" "perfstat-*"                  ""

CheckAndZip "" "" "" "perftest*.summary"             ""
CheckAndZip "" "" "" "perfreport-*.csv"              ""
CheckAndZip "" "" "" "PerformanceTest*.pdf"          ""
CheckAndZip "" "" "" "perftest-*"                    ""
CheckAndZip "" "" "" "*.png"                         ""
CheckAndZip "" "" "" "results-thor-6.5.0.csv"        ""
CheckAndZip "" "" "" "results-roxie-6.5.0.csv"       ""
CheckAndZip "" "" "" "PerformanceIssues-1*.csv"      ""
CheckAndZip " "                   "" "" "PerformanceIssues.csv"         ""

CheckAndZip "" "" "" "ML_*.log"                      ""
CheckAndZip "" "" "" "mltests.summary"               ""

CheckAndZip "-m"                  "" "" "build-*.log"                   ""
CheckAndZip "-m"                  "" "" "install*.log"                  ""
CheckAndZip "" "" "" "myInfo-*.log"                  ""
CheckAndZip "" "" "" "myPortUsage-*.log"             ""

CheckAndZip "" "" "" "wutest*.log"                   ""
CheckAndZip "" "" "" "wutest.summary"                ""
CheckAndZip "" "" "" "wutest*.zip"                   ""

echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

#
# --------------------------------
# Archive logs from COVERAGE_LOG_DIR (~/coverage)
#

if [ -n "$IS_COVERAGE" ]
then
    WriteLog "Archive content of ${COVERAGE_LOG_DIR}" "${ARCHIVE_LOG_DIR}"
    echo 'Archive content of '${COVERAGE_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    CheckAndZip "-m" "" "${COVERAGE_LOG_DIR}" "*.summary" ""
    CheckAndZip "-m" "" "${COVERAGE_LOG_DIR}" "*.log"     ""
    CheckAndZip "-m" "" "${COVERAGE_LOG_DIR}" "*.lcov"    ""
    CheckAndZip "-m" "" "${COVERAGE_LOG_DIR}" "*_log"     ""
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi

#
# --------------------------------
# Archive logs from HPCC_BUILD_DIR (/root/build/CE/platform/build)
#

WriteLog "Archive content of ${HPCC_BUILD_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${HPCC_BUILD_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
CheckAndZip "-m" "" "${HPCC_BUILD_DIR}" "*.summary" ""
echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

#
# --------------------------------
# Archive logs from HPCC_LOG_DIR (/var/log/HPCCSystems)
#

WriteLog "Archive content of ${HPCC_LOG_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${HPCC_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log


if [ -d /var/log/HPCCSystems/ ] 
then
    find /var/log/HPCCSystems/ -name '*'$(date "+%Y_%m_%d")'*.log' -type f -exec \
         zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} '{}' \; >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
    
    # If there is any log from yesterday (overlappeds session case) add it to archive
    # (It can happen only in overlapped case, because otherwise the OBT cleans up everything at the end of a session.)
    find /var/log/HPCCSystems/ -name '*'$(date -d '-1 day'  "+%Y_%m_%d")'*.log' -type f -exec \
         zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} '{}' \; >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
    
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi

#
# --------------------------------
# Archive content of TEST_LOG_DIR (/root/HPCCSystems-regression)
#

WriteLog "Archive content of ${TEST_LOG_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${TEST_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log


for i in ${TEST_LOG_SUBDIRS[@]}
do 
    WriteLog "Archive content of ${TEST_LOG_DIR}/$i" "${ARCHIVE_LOG_DIR}"
    echo "  Archive content of :"$i >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo "  ------------------------------------" >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

    zip ${MOVE_LOG_TO_ZIP_FLAG} ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} -r ${TEST_LOG_DIR}/$i/ >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

done

#
# --------------------------------
# Archive core files if generated
#

if [ -d ${HPCC_BINARY_DIR} ] 
then

    cores=($(find ${HPCC_BINARY_DIR}/ -type f -regextype sed -regex '.*/core_.*\.[0-9]*$'))
    maxNumberOfCoresStored=3
    if [ ${#cores[@]} -ne 0 ]
    then
        WriteLog "Archive '${#cores[*]}' core file(s) from ${HPCC_BINARY_DIR}" "${ARCHIVE_LOG_DIR}" 
        echo 'Archive '${#cores[*]}' core file(s) from '${HPCC_BINARY_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
        echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
        echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
     
        coreIndex=1
        for core in ${cores[@]}
        do 
            sudo chmod 0755 $core

            coreSize=$( ls -l $core | awk '{ print $5}' )

            WriteLog "$( printf %3d $coreIndex ). Generate backtrace for $core." "${ARCHIVE_LOG_DIR}"

            corename=${core##*/}; 
            comp=$( echo $corename | tr '_.' ' ' | awk '{print $2 }' ); 
            compnamepart=$( find /opt/HPCCSystems/bin/ -iname "$comp*" -type f -print); 
            compname=${compnamepart##*/}

            WriteLog "corename: ${corename}, comp: ${comp}, compnamepart: ${compnamepart}, component name: ${compname}" "${ARCHIVE_LOG_DIR}"
            eval ${GDB_CMD} "/opt/HPCCSystems/bin/${compname}" $core | sudo tee "$core.trace"

            zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} $core.trace >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
            zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} "/opt/HPCCSystems/bin/${comp}" >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log


            if [[ ${coreIndex} -le $maxNumberOfCoresStored ]]
            then
                WriteLog "Add $core (${coreSize} bytes) to archive" "${ARCHIVE_LOG_DIR}"
                zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} $core >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
            else
                WriteLog "Skip to add $core (${coreSize} bytes) to archive" "${ARCHIVE_LOG_DIR}"
            fi
            
            coreIndex=$(( $coreIndex + 1 ))
            sudo rm $core $core.trace
    
        done
        
        echo 'Done.' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

        # send email to Agyi about core files
        echo "During to process ${ARCHIVE_NAME} there are ${#cores[*]} core file(s) found in ${HPCC_BINARY_DIR} generated in ${OBT_SYSTEM} on ${BRANCH_ID} branch at ${OBT_TIMESTAMP//-/:}. You should check them." | mailx -s "Core files generated" -u $USER  ${ADMIN_EMAIL_ADDRESS}


    else
        WriteLog "There is no core file in '${HPCC_BINARY_DIR}" "${ARCHIVE_LOG_DIR}"
        echo 'There is no core file in '${HPCC_BINARY_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
        echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
        echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    fi
else
    WriteLog "There is no directory ${HPCC_BINARY_DIR}" "${ARCHIVE_LOG_DIR}"
    echo 'There is no directory '${HPCC_BINARY_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi


#
# --------------------------------
# Archive logs from DALI_DIR (/var/log/HPCCSystems/mydali)
#

WriteLog "Archive content of ${DALI_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${DALI_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} -r ${DALI_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log


#
# --------------------------------
# Archive logs from ECLCC_DIR (/var/log/HPCCSystems/myeclccserver)
#

WriteLog "Archive content of ${ECLCC_DIR}" "${ARCHIVE_LOG_DIR}"
echo 'Archive content of '${ECLCC_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
zip ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} -r ${ECLCC_DIR}/*.log >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 
echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log



#
# --------------------------------
# End of archiving process
#

echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo 'End of archive' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log


#
# --------------------------------
# Move Unittest core file(s)archive to log archieve
#

unittest_cores=( $(find ${OBT_LOG_DIR}/ -iname 'unittest-core*zip' -type f) )
    
if [ ${#unittest_cores[@]} -ne 0 ]
then
    WriteLog "Archive '${#unittest_cores[*]}' core file(s) from ${OBT_LOG_DIR}" "${ARCHIVE_LOG_DIR}" 
    echo 'Archive '${#unittest_cores[*]}' core file(s) from '${OBT_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
     
    for c in ${unittest_cores[@]}
    do 
        WriteLog "Move $c to archive" "${ARCHIVE_LOG_DIR}"

        mv $c   ${FULL_ARCHIVE_TARGET_DIR}/.

    done
        
    echo 'Done.' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
else
    WriteLog "There is no core file in '${OBT_LOG_DIR}" "${ARCHIVE_LOG_DIR}"
    echo 'There is no core file in '${OBT_LOG_DIR} >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '-----------------------------------------------------------' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
    echo '' >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
fi

#
# --------------------------------
# Copy archive to Wiki area
#

if [ $DO_ARCHIVE -eq 1 ]
then
    REMOTE_ARCHIVE_TARGET_DIR=${TARGET_DIR}/log-archive
    
    WriteLog "Copy archive into wiki ( ${REMOTE_ARCHIVE_TARGET_DIR} )." "${ARCHIVE_LOG_DIR}"
    
    if [ ! -d ${REMOTE_ARCHIVE_TARGET_DIR} ]
    then
        mkdir $REMOTE_ARCHIVE_TARGET_DIR
    fi

    if [ -d ${REMOTE_ARCHIVE_TARGET_DIR} ]
    then
        WriteLog "cp ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}* ${REMOTE_ARCHIVE_TARGET_DIR}/" "${ARCHIVE_LOG_DIR}"
        cp ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}* ${REMOTE_ARCHIVE_TARGET_DIR}/
    else
        WriteLog "${REMOTE_ARCHIVE_TARGET_DIR} doesn't exist! Skip copy files to wiki!" "${ARCHIVE_LOG_DIR}"
    fi
else
    WriteLog "Skip copy files to wiki!" "${ARCHIVE_LOG_DIR}"
fi

#
# --------------------------------
# End of archiving process
#

WriteLog "End of archiveLogs.sh" "${ARCHIVE_LOG_DIR}"
WriteLog "" "${ARCHIVE_LOG_DIR}"


#
# --------------------------------
# House keeping
#

WriteLog "Remove all log archive directory older than ${LOG_ARCHIEVE_DIR_EXPIRE} days from ${ARCHIVE_TARGET_DIR}." "${ARCHIVE_LOG_DIR}"
echo "Remove all log archive directory older than ${LOG_ARCHIEVE_DIR_EXPIRE} days from ${ARCHIVE_TARGET_DIR}." >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

OLD_DIRS=( $( find ${ARCHIVE_TARGET_DIR}/ -maxdepth 1 -mtime +${LOG_ARCHIEVE_DIR_EXPIRE} -type d ) )

WriteLog "${#OLD_DIRS[@]} old directory found." "${ARCHIVE_LOG_DIR}"
echo "${#OLD_DIRS[@]} old directory found." >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

res=$( find ${ARCHIVE_TARGET_DIR}/ -maxdepth 1 -mtime +${LOG_ARCHIEVE_DIR_EXPIRE} -type d -print -exec rm -rf '{}' \; 2>&1 )

WriteLog "res:${res}" "${ARCHIVE_LOG_DIR}"
echo "res:${res}" >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

WriteLog "End of cleanup." "${ARCHIVE_LOG_DIR}"
echo "End of cleanup." >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
echo " " >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log

#
# ------------------------------
#
# Done
#

zip -m ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME} ${OBT_LOG_DIR}/archiveLogs*.log >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log 

echo "Done" >> ${FULL_ARCHIVE_TARGET_DIR}/${ARCHIVE_NAME}.log
