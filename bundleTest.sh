#!/bin/bash
#set -x

#
#------------------------------
#
# Import settings
#

# Git branch

. ./settings.sh

# WriteLog() function

. ./timestampLogger.sh

# UninstallHPCC() fuction

declare -f -F UninstallHPCC > /dev/null
    
if [ $? -ne 0 ]
then
    . ./UninstallHPCC.sh
fi

#
#------------------------------
#
# Constants
#

LOG_DIR=~/HPCCSystems-regression/log
BIN_HOME=~/

PLATFORM_HOME=${TEST_ROOT}
TEST_ENGINE_HOME=${PLATFORM_HOME}/testing/regress

LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
BUILD_LOG_FILE=${BIN_HOME}/"ML_build_"${LONG_DATE}".log";

BUNDLES_TO_TEST=( "ML_Core" "PBblas" "GLM" "DBSCAN" "GNN" "LearningTrees" "TextVectors" "KMeans" "SupportVectorMachines" "LinearRegression" "LogisticRegression" )

# For testing purposes
SKIP_INSTALL_BUNDLES=0

ML_PBLAS_VERSION="V3_0"
ML_TEST_ROOT=~/.HPCCSystems/bundles/_versions/PBblas/${ML_PBLAS_VERSION}/PBblas
ML_TEST_HOME=~/.HPCCSystems/bundles/_versions/
ML_TEST_LOG=${OBT_LOG_DIR}/ML_test-${LONG_DATE}.log
ML_TEST_RESULT_LOG=${OBT_LOG_DIR}/mltest.${LONG_DATE}.log
ML_TEST_SUMMARY=${OBT_LOG_DIR}/mltests.summary

#
#----------------------------------------------------
#

ProcessLog()
{ 
    BUNDLE=$1
    TARGET=$2
    logfilename=$( ls -clr ${TEST_LOG_DIR}/$TARGET.*.log | head -1 | awk '{ print $9 }' )
    WriteLog "ML test result log filename: ${logfilename}" "${ML_TEST_LOG}"
    total=$(cat ${logfilename} | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
    passed=$(cat ${logfilename} | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
    failed=$(cat ${logfilename} | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
    elapsed=$(cat ${logfilename} | sed -n "s/^Elapsed time: \(.*\)$/\1/p")

    WriteLog "TestResult:Total:${total} passed:${passed} failed:${failed} elaps:${elapsed}" "${ML_TEST_LOG}"
    echo "TestResult:$BUNDLE:total:${total} passed:${passed} failed:${failed} elaps:${elapsed}" >> ${ML_TEST_SUMMARY}
    
    # Rename result log file to name of the bundle
    logname=$(basename $logfilename)
    bundlelogfilename=${logname//$TARGET/$BUNDLE}
    printf "%s, %s\n" "$logname" "$bundlelogfilename"
    mv -v $logfilename ${TEST_LOG_DIR}/ml-$bundlelogfilename
}

#
#----------------------------------------------------
#
# Start ML Test process
#

WriteLog "ML test script log file: '${ML_TEST_LOG}'" "${ML_TEST_LOG}"
WriteLog "ML test result log file: '${ML_TEST_RESULT_LOG}'" "${ML_TEST_LOG}"

WriteLog "Machine Learning Confidence Test started" "${ML_TEST_LOG}"

WriteLog "path:'${PATH}'" "${ML_TEST_LOG}"
WriteLog "LD_LIBRARY_PATH:'${LD_LIBRARY_PATH}'" "${ML_TEST_LOG}"
WriteLog "GCC: $(gcc --version)" "${ML_TEST_LOG}"
WriteLog "CMake: $( /usr/local/bin/cmake --version | head -n 1 )" "${ML_TEST_LOG}"
WriteLog "Python: $(python --version  2>&1 )" "${ML_TEST_LOG}"
WriteLog "Python2: $(python2 --version 2>&1 )" "${ML_TEST_LOG}"
WriteLog "Python3: $(python3 --version  2>&1 )" "${ML_TEST_LOG}"
WriteLog "Tensorflow: $(pip3 list | grep -E 'tensorflow ')" "${ML_TEST_LOG}"

WriteLog "System id: ${SYSTEM_ID}, HPCC_SERVICE = '${HPCC_SERVICE}'" "${ML_TEST_LOG}"

STARTUP_MSG=""

if [[ "$ML_BUILD" -eq 1 ]]
then
    STARTUP_MSG=${STARTUP_MSG}"build"
fi

if [[ "$ML_RUN_THOR" -eq 1 ]]
then
    [[ -n "$STARTUP_MSG" ]] && STARTUP_MSG+=", "
    STARTUP_MSG="${STARTUP_MSG}thor"
fi

if [[ -n "$STARTUP_MSG" ]]
then
    WriteLog "Execute bundle tests on ${STARTUP_MSG}" "${ML_TEST_LOG}"
else
    WriteLog "No target selected. This is a dry run." "${ML_TEST_LOG}"
fi

#
#---------------------------
#
# Determine the package manager

WriteLog "packageExt: '${PKG_EXT}', installCMD: '${PKG_INST_CMD}'." "${ML_TEST_LOG}"

#
#---------------------------
#
# Clean system
#

WriteLog "Clean system" "${ML_TEST_LOG}"

[ ! -e $ML_TEST_ROOT ] && mkdir -p $ML_TEST_ROOT


cd  ${ML_TEST_ROOT}

 
#
#---------------------------
#
# Uninstall HPCC to free as much disk space as can
#

if [[ ${ML_KEEP_HPCC} -eq 0 ]]
then
    WriteLog "Uninstall HPCC to free as much disk space as can" "${ML_TEST_LOG}"
    
    WriteLog "Uninstall HPCC-Platform" "${ML_TEST_LOG}"
    
    UninstallHPCC "${ML_TEST_LOG}" "${ML_WIPE_OFF_HPCC}"
else
    WriteLog "Skip Uninstall HPCC but stop it!" "${ML_TEST_LOG}"
    StopHpcc "${ML_TEST_LOG}"
fi

#
#--------------------------------------------------
#
# Build it
#

if [[ $ML_BUILD -eq 1 ]]
then
    WriteLog "                                           " "${ML_TEST_LOG}"
    WriteLog "*******************************************" "${ML_TEST_LOG}"
    WriteLog " Build HPCC Platform from ${BUILD_HOME} ..." "${ML_TEST_LOG}"
    WriteLog "                                           " "${ML_TEST_LOG}"
    #-------------------------------------------------------------------------------------
    # Build HPCC
    #
    
    cd ${BUILD_HOME}

    date=$( date "+%Y-%m-%d %H:%M:%S")
    WriteLog "Start build at ${date}" "${ML_TEST_LOG}"

    if [ ! -f  ${BUILD_DIR}/bin/build_pf.sh ]
    then
        C_CMD="cmake -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -D CMAKE_BUILD_TYPE=$ML_BUILD_TYPE -D CMAKE_ECLIPSE_MAKE_ARGUMENTS=-30 -DECLWATCH_BUILD_STRATEGY='IF_MISSING' ../HPCC-Platform ln -s ../HPCC-Platform"
        WriteLog "${C_CMD}" "${ML_TEST_LOG}"

        res=( "$(${C_CMD} 2>&1)" )
        echo "${res[*]}" > $BUILD_LOG_FILE
    else
        res=( ". $(${BUILD_DIR}/bin/build_pf.sh HPCC-Platform 2>&1)" )
        echo "${res[*]}"  > $BUILD_LOG_FILE

        WriteLog "Execute '${BUILD_DIR}/bin/build_pf.sh'" "${ML_TEST_LOG}"
    fi

    CMD="sudo make -j ${NUMBER_OF_CPUS} package"

    WriteLog "cmd: ${CMD}" "${ML_TEST_LOG}"

    ${CMD} >> ${BUILD_LOG_FILE} 2>&1

    if [ $? -ne 0 ] 
    then
        WriteLog "Build failed: build has errors " "${ML_TEST_LOG}"
        exit
    else
        ls -l hpcc*${PKG_EXT} >/dev/null 2>&1
        if [ $? -ne 0 ] 
        then
            WriteLog "Build failed: no rpm package found " "${ML_TEST_LOG}"
            exit
        else
            WriteLog "Build succeed" "${ML_TEST_LOG}"
        fi
    fi

    date=$( date "+%Y-%m-%d %H:%M:%S")
    WriteLog "Build end at ${date}" "${ML_TEST_LOG}"

    HPCC_PACKAGE=$( grep 'Current release version' ${BUILD_LOG_FILE} | cut -c 31- )${PKG_EXT}
    
    WriteLog " Default package: '${HPCC_PACKAGE}'." "${ML_TEST_LOG}"
    WriteLog "                                           " "${ML_TEST_LOG}"      

else
    WriteLog "                                           " "${ML_TEST_LOG}"
    WriteLog "*******************************************" "${ML_TEST_LOG}"
    WriteLog " Skip build HPCC Platform...               " "${ML_TEST_LOG}"
    WriteLog "                                           " "${ML_TEST_LOG}"      

    cd ${BUILD_HOME}

    HPCC_PACKAGE=$(find ~/build/CE/platform/build/ -maxdepth 1 -iname 'hpccsystems-platform*' -type f )
    WriteLog " Default package: \n\t'${HPCC_PACKAGE}' ." "${ML_TEST_LOG}"
    WriteLog "                                           " "${ML_TEST_LOG}"      

fi

TARGET_PLATFORM="thor"

if [ $ML_RUN_THOR -eq 1 ]
then
    #***************************************************************
    #
    #           THOR test
    #
    #***************************************************************
    
    WriteLog "                                   " "${ML_TEST_LOG}"
    WriteLog "***********************************" "${ML_TEST_LOG}"
    WriteLog " Start ML ${TARGET_PLATFORM} test. " "${ML_TEST_LOG}"
    WriteLog "                                   " "${ML_TEST_LOG}"
    
    #
    # --------------------------------------------------------------
    # Install HPCC
    #
    WriteLog "Install HPCC Platform ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
    
    res=$( ${SUDO} ${PKG_INST_CMD} ${HPCC_PACKAGE} 2>&1 )
    retCode=$?
    WriteLog "ret code:$retCode" "${ML_TEST_LOG}"
    
    if [ $retCode -ne 0 ]
    then
        if [[ "$res" =~ "already installed" ]]
        then
            WriteLog "$res" "${ML_TEST_LOG}"
            WriteLog "REmove installed one..." "${ML_TEST_LOG}"
            res=$( ${SUDO} ${PKG_REM_CMD} hpccsystems-platform 2>&1 )
            retCode=$?
            WriteLog "ret code:$retCode" "${ML_TEST_LOG}"
            WriteLog "res:$res" "${ML_TEST_LOG}"
            WriteLog "$( sudo rm -v /etc/HPCCSystems/environment.xml)\n" "${ML_TEST_LOG}"
            WriteLog "Install the latest '${PKG_INST_CMD} ${HPCC_PACKAGE}' ..." "${ML_TEST_LOG}"
            res=$( ${SUDO} ${PKG_INST_CMD} ${HPCC_PACKAGE} 2>&1 )
            retCode=$?
            WriteLog "ret code:$retCode" "${ML_TEST_LOG}"
            WriteLog "res:$res" "${ML_TEST_LOG}"
        else
            WriteLog "Error in install! ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
            exit
        fi
    fi

    #
    #---------------------------
    #
    # Patch environment.xml to use diferent size Memory
    #

    MEMSIZE=$(( $ML_THOR_MEMSIZE_GB * (2 ** 30) ))
    MEMSIZE_KB=$(( $ML_THOR_MEMSIZE_GB * (2 ** 20) ))

    # for hthor we should change 'defaultMemoryLimitMB' as well 
    
    WriteLog "Patch environment.xml to use ${ML_THOR_MEMSIZE_GB}GB Memory for test on ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
    WriteLog "Patch environment.xml to use ${ML_THOR_NUMBER_OF_SLAVES} slaves for ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
    
    WriteLog "$( ${SUDO} cp -v /etc/HPCCSystems/environment.xml /etc/HPCCSystems/environment.xml.bak )"  "${ML_TEST_LOG}"
    ${SUDO} sed -e 's/totalMemoryLimit="1073741824"/totalMemoryLimit="'${MEMSIZE}'"/g' -e 's/slavesPerNode="1"/slavesPerNode="'${ML_THOR_NUMBER_OF_SLAVES}'"/g' "/etc/HPCCSystems/environment.xml" > temp.xml && ${SUDO} mv -f temp.xml "/etc/HPCCSystems/environment.xml"

    if [ $? -ne 0 ]
    then
        WriteLog "Error in update environment.xml file! ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
    else
        WriteLog "The environment.xml file Updated. ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
        WriteLog "$(ls -l /etc/HPCCSystems/environment.xml)" "${ML_TEST_LOG}"
        WriteLog "$(grep -E 'totalMemoryLimit=|slavesPerNode=' /etc/HPCCSystems/environment.xml)" "${ML_TEST_LOG}"
    fi
    
    #
    #---------------------------
    #
    # Check HPCC Systems
    #
    WriteLog "Check HPCC Systems on ${TARGET_PLATFORM}" "${ML_TEST_LOG}"

    NUMBER_OF_HPCC_COMPONENTS=$( /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -list | grep -E -i -v 'eclagent' | wc -l )
    
    if [[ $NUMBER_OF_HPCC_COMPONENTS -eq 0 ]]
    then
        WriteLog "Unable start HPCC system!! Only ${NUMBER_OF_HPCC_COMPONENTS} component is configured to run." "${ML_TEST_LOG}"
        exit -2
    fi

    hpccRunning=$( ${HPCC_SERVICE} status | grep -c 'running' )

    WriteLog "Number of HPCC components:$NUMBER_OF_HPCC_COMPONENTS, running:$hpccRunning" "${ML_TEST_LOG}"

    if [[ "$hpccRunning" -ne "$NUMBER_OF_HPCC_COMPONENTS" ]]
    then
        WriteLog "Start HPCC System on ${TARGET_PLATFORM}..." "${ML_TEST_LOG}"
        
        hpccStatus=$( ${HPCC_SERVICE} start  2>&1 )
 
        WriteLog "Result:\n${hpccStatus}" "${ML_TEST_LOG}"
    fi
    
    # give it some time
    sleep 5
    
    hpccRunning=$( ${HPCC_SERVICE} status | grep -c 'running' )
    if [[ "$hpccRunning" -ne ${NUMBER_OF_HPCC_COMPONENTS} ]]
    then
        WriteLog "Unable start HPCC system!! Only ${hpccRunning} component is up on ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
        exit -2
    else
        hpccStatus=$( ${HPCC_SERVICE} status )
        WriteLog "HPCC system status: \n${hpccStatus}" "${ML_TEST_LOG}"
    fi
    
    #
    #---------------------------
    #
    # Get test from github
    #
    
    WriteLog "Get the latest ML bundles" "${ML_TEST_LOG}"
    
    cd  ${PERF_TEST_ROOT}
    myPwd=$( pwd )

    WriteLog "Pwd: ${myPwd} for $TARGET_PLATFORM" "${ML_TEST_LOG}"

    WriteLog "Install ML_Core bundle from GitHub" "${ML_TEST_LOG}"

    BUNDLES_COUNT=${#BUNDLES_TO_TEST[@]}
    [[ $SKIP_INSTALL_BUNDLES -eq 1 ]] && BUNDLES_COUNT=0
    
    for ((i=0; i<$BUNDLES_COUNT; i++))
    do
        BUNDLE_NAME=${BUNDLES_TO_TEST[i]}
        WriteLog "Bundle: $BUNDLE_NAME" "${ML_TEST_LOG}"
        BUNDLE_REPO="https://github.com/hpcc-systems/${BUNDLES_TO_TEST[i]}.git"
        WriteLog "Repo: $BUNDLE_REPO" "${ML_TEST_LOG}"
        INSTALL_CMD="ecl bundle install --update --force ${BUNDLE_REPO}"
        WriteLog "Install cmd: $INSTALL_CMD" "${ML_TEST_LOG}"
     
        tryCountMax=5
        tryCount=$tryCountMax
        tryDelay=1m

        while true
        do
            cRes=$( ${INSTALL_CMD} 2>&1 )
            if [[ 0 -ne  $? ]]
            then
                WriteLog "cRes: '$cRes'" "${ML_TEST_LOG}"
                tryCount=$(( $tryCount-1 ))

                if [[ $tryCount -ne 0 ]]
                then
                    WriteLog "Wait for ${tryDelay} to try again." "${ML_TEST_LOG}"
                    sleep ${tryDelay}
                    continue
                else
                    WriteLog "Install $BUNDLE_NAME bundle was failed after ${tryCountMax} attempts. Result is: '${cRes}'" "${ML_TEST_LOG}"
                fi
            else
                WriteLog "Install $BUNDLE_NAME bundle was success." "${ML_TEST_LOG}"
                BUNDLE_VERSION=$( echo "${cRes}" | grep -E "^$BUNDLE_NAME" | awk '{ print $2 }' )
                WriteLog "Version: $BUNDLE_VERSION" "${ML_TEST_LOG}"
                break
            fi
        done
        
        WriteLog ".............................." "${ML_TEST_LOG}"

    done
    
    if [[ ! -d ${ML_TEST_HOME} ]]
    then
        WriteLog "${ML_TEST_HOME} doesn't exists! Check the version, maybe changed!" "${ML_TEST_LOG}"
        exit -4
    fi

    cd  ${ML_TEST_HOME}

    myPwd=$( pwd )
    
    #
    #---------------------------
    #
    # Run ML tests 
    #
    
    WriteLog "Run ML tests  on platforms pwd:${myPwd}" "${ML_TEST_LOG}"
    
    WriteLog "ML_TEST_HOME  : ${ML_TEST_HOME}" "${ML_TEST_LOG}"
    WriteLog "ML_ENGINE_HOME: ${ML_ENGINE_HOME}" "${ML_TEST_LOG}"

    CMD="${REGRESSION_TEST_ENGINE_HOME}/ecl-test run -t ${TARGET_PLATFORM} --config ${REGRESSION_TEST_ENGINE_HOME}/ecl-test.json --timeout ${ML_TIMEOUT} -fthorConnectTimeout=36000 --pq ${ML_PARALLEL_QUERIES} ${ML_EXCLUDE_FILES}"

    if [ ${EXECUTE_ML_SUITE} -ne 0 ]
    then
        while read bundle
        do
            bundleRunPath=${bundle%/ecl}
            bundlePath=${bundleRunPath%/OBTTests}; 
            bundleName=${bundlePath%/test}
            bundleName=$(basename $bundleName )
            
            # Until it is fully implemented, skip the log running LearningTrees bundle test
            if [[ "$bundle" =~ "LearningTreess" ]]
            then
                WriteLog "Bundle with Regression Test: $bundleName is skipped." "${ML_TEST_LOG}"
                continue
            fi
            
            WriteLog "Bundle with Regression Test: $bundleName" "${ML_TEST_LOG}"
            pushd $bundleRunPath
        
            WriteLog "CMD: '${CMD}'" "${ML_TEST_LOG}"
        
            ${CMD} >> ${ML_TEST_LOG} 2>&1
            
            retCode=$( echo $? )
            WriteLog "retcode: ${retCode}" "${ML_TEST_LOG}"
        
            if [ ${retCode} -ne 0 ] 
            then
                WriteLog "Machine Learning $bundle tests on ${TARGET_PLATFORM} returns with ${retCode}" "${ML_TEST_LOG}"
                #exit -1
            else 
                ProcessLog "$bundleName" "${TARGET_PLATFORM}"
            fi
           
            popd
            
            WriteLog ".............................." "${ML_TEST_LOG}"
            
        done< <(find . -iname 'ecl' -type d | sort )
    else
                WriteLog "Skip Machine Learning test suite execution!" "${ML_TEST_LOG}"
                WriteLog "                                      " "${ML_TEST_LOG}"        
    fi

    NUM_OF_ML_ZAPS=( $(sudo find ${ZAP_DIR}/ -iname 'ZAPReport*' -type f -exec printf "%s\n" '{}' \; ) )
    if [ ${#NUM_OF_ML_ZAPS[@]} -ne 0 ]
    then
        WriteLog "Copy ML test ZAP files to ${TARGET_DIR}/test/ZAP" "${ML_TEST_LOG}"
        if [ ! -e ${TARGET_DIR}/test/ZAP ]
        then
            WriteLog "Create ${TARGET_DIR}/test/ZAP directory..." "${ML_TEST_LOG}"
            mkdir -p ${TARGET_DIR}/test/ZAP
        fi
    
        WriteLog "cp ${ZAP_DIR}/* ${TARGET_DIR}/test/ZAP/" "${ML_TEST_LOG}"
        cp ${ZAP_DIR}/* ${TARGET_DIR}/test/ZAP/
    else
        WriteLog "No ZAP file generated." "${ML_TEST_LOG}"
    fi

    # Check if any core file generated. If yes, create stack trace with gdb

    NUM_OF_ML_CORES=( $(sudo find /var/lib/HPCCSystems/ -iname 'core*' -type f -exec printf "%s\n" '{}' \; ) )
    
    if [ ${#NUM_OF_ML_CORES[@]} -ne 0 ]
    then
        WriteLog "${#NUM_OF_ML_CORES[@]} ML test core files found." "${ML_TEST_LOG}"

        for  core in ${NUM_OF_ML_CORES[@]}
        do
            WriteLog "Generate backtrace for $core." "${ML_TEST_LOG}"
            base=$( dirname $core )
            lastSubdir=${base##*/}
            comp=${lastSubdir##my}
    

            sudo ${GDB_CMD} "/opt/HPCCSystems/bin/${comp}" $core | sudo tee "$core.trace" 2>&1
    
       done

    else
        WriteLog "No core file generated." "${ML_TEST_LOG}"
    fi

    # Archive  logs
    pushd ${OBT_BIN_DIR}
    
    # Copy test summary to Wiki
    WriteLog "Copy ML test result files to ${TARGET_DIR}..." "${ML_TEST_LOG}"

    WriteLog "--->'${LOG_DIR}/ml-*.log'" "${ML_TEST_LOG}"
    WriteLog "--->$(ls -l ${LOG_DIR}/ml-* )" "${ML_TEST_LOG}"
    [ !  -d ${TARGET_DIR}/test/ ] && mkdir -p ${TARGET_DIR}/test
    res=$( cp -v ${LOG_DIR}/ml-*.log ${TARGET_DIR}/test/  2>&1 )
    WriteLog "---->res:${res}" "${ML_TEST_LOG}"

    WriteLog "--_>mltests.summary" "${ML_TEST_LOG}"
    res=$( cp -v mltests.summary ${TARGET_DIR}/test/mltests.summary 2>&1 )
    WriteLog "---->res:${res}" "${ML_TEST_LOG}"
    
    WriteLog "Archive ${TARGET_PLATFORM} ML logs" "${ML_TEST_LOG}"
    ./archiveLogs.sh ml-${TARGET_PLATFORM} timestamp=${OBT_TIMESTAMP}
    
    popd
    
    #
    #---------------------------
    #
    # Uninstall HPCC to free as much disk space as can
    #

    if [[ ${KEEP_HPCC} -eq 0 ]]
    then
        WriteLog "Uninstall HPCC to free as much disk space as can on ${TARGET_PLATFORM}!" "${ML_TEST_LOG}"
    
        WriteLog "Uninstall HPCC-Platform" "${ML_TEST_LOG}"
    
        UninstallHPCC "${ML_TEST_LOG}" "${ML_WIPE_OFF_HPCC}"
    else
        WriteLog "Skip Uninstall HPCC on ${TARGET_PLATFORM} but stop it!" "${ML_TEST_LOG}"
        StopHpcc "${ML_TEST_LOG}"
    fi

    if [[ -f /etc/HPCCSystems/environment.xml.bak ]]
    then
        WriteLog "Restore original environment.xml on ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
        
        ${SUDO} cp /etc/HPCCSystems/environment.xml.bak /etc/HPCCSystems/environment.xml
     
        if [ $? -ne 0 ]
        then
            WriteLog "Error in restore environment.xml file! ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
        else
            WriteLog "The environment.xml file restored. ${TARGET_PLATFORM}" "${ML_TEST_LOG}"
        fi
    fi

    #
    #----------------------------
    #
    # Remove ECL-Bundles
    #
    
    WriteLog "                                    " "${ML_TEST_LOG}"
    WriteLog "************************************" "${ML_TEST_LOG}"
    WriteLog " End of ML ${TARGET_PLATFORM} test. " "${ML_TEST_LOG}"
    WriteLog "                                    " "${ML_TEST_LOG}"
    
else
    WriteLog "                                   " "${ML_TEST_LOG}"
    WriteLog "***********************************" "${ML_TEST_LOG}"
    WriteLog " Skip ML ${TARGET_PLATFORM} test.  " "${ML_TEST_LOG}"
    WriteLog "                                   " "${ML_TEST_LOG}"

fi

#
#-----------------------------------------------------------------------------
#
# End of ML test
#

cd ${OBT_BIN_DIR}

#
#---------------------------
#
# Stop HPCC Systems
#

WriteLog "End of Machine Learning test" "${ML_TEST_LOG}"

set +x
