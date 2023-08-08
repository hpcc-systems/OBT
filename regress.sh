#!/bin/bash

#
#------------------------------
#
# Import settings
#

# Git branch, common macros, etc

. ./settings.sh

# Git branch cloning

. ./cloneRepo.sh

# WriteLog() function

. ./timestampLogger.sh

# UninstallHPCC() fuction

. ./UninstallHPCC.sh

#
#------------------------------
#
# Constants
#

BUILD_ROOT=~/build
BIN_ROOT=${BUILD_ROOT}/bin

TEST_HOME=${TEST_ROOT}/testing/regress

BUILD_HOME=~/build/CE/platform/build
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
REGRESS_LOG_FILE=${OBT_LOG_DIR}/regress-${LONG_DATE}.log

#
#----------------------------------------------------
#
# Start Regression Test process
#

WriteLog "Regression test started" "${REGRESS_LOG_FILE}"

#
#----------------------------------------------------
#
# Reserve ports for Thor Slaves
#

WriteLog "Reserve ports for Thor Slaves" "${REGRESS_LOG_FILE}"

START_PORT=20100
SLAVES_PER_NODE=$REGRESSION_NUMBER_OF_THOR_SLAVES 
CHANNELS_PER_SLAVE=$REGRESSION_NUMBER_OF_THOR_CHANNELS
LOCAL_THOR_PORT_INC=$REGRESSION_THOR_LOCAL_THOR_PORT_INC
END_PORT=$(( $START_PORT + $SLAVES_PER_NODE * $CHANNELS_PER_SLAVE * $LOCAL_THOR_PORT_INC ))

WriteLog "Slave start port: $START_PORT, end port: $END_PORT " "${REGRESS_LOG_FILE}"

WriteLog "Done" "${REGRESS_LOG_FILE}"

#
#----------------------------------------------------
#
# Check MySQL server state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check MySQL server state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check MySQL server state" "${REGRESS_LOG_FILE}"
    ./checkMySQL.sh
fi

#
#----------------------------------------------------
#
# Check Cassandra state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check Cassandra state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check Cassandra state" "${REGRESS_LOG_FILE}"
    WriteLog "Temporarily Cassandra not started based on the Log4j problem." "${REGRESS_LOG_FILE}"
fi

#
#----------------------------------------------------
#
# Check Memcached state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check Memcached state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check Memcached state" "${REGRESS_LOG_FILE}"
    ./checkMemcached.sh
fi

#
#----------------------------------------------------
#
# Check Redis state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check Redis state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check Redis state" "${REGRESS_LOG_FILE}"
    ./checkRedis.sh
fi

#
#----------------------------------------------------
#
# Check Kafka state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check Kafka state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check Kafka state" "${REGRESS_LOG_FILE}"
    WriteLog "Temporarily Kafka (and Zookepper) not started based on the Log4j problem." "${REGRESS_LOG_FILE}"
fi

#
#----------------------------------------------------
#
# Check Couchbase state
#

if [[ "$REGRESSION_EXCLUDE_CLASS" =~ "embedded,3rdparty" ]]
then
    WriteLog "Check Couchbase state skipped" "${REGRESS_LOG_FILE}"
else
    WriteLog "Check Couchbase state" "${REGRESS_LOG_FILE}"
    ./checkCouchbase.sh
fi

#
#----------------------------------------------------
#
# Un-install HPCC Systems
#

WriteLog "Un-install HPCC Systems" "${REGRESS_LOG_FILE}"

UninstallHPCC "${REGRESS_LOG_FILE}" "${REGRESSION_WIPE_OFF_HPCC}"

#
#----------------------------------------------------
#
# Clean-up, 
#

WriteLog "Clean system" "${REGRESS_LOG_FILE}"

# Post uninstall
sudo rm -rf /var/*/HPCCSystems/*
sudo rm -rf /*/HPCCSystems
sudo userdel hpcc 
sudo rm -rf /Users/hpcc
sudo rm -rf /tmp/remote_install
sudo rm -rf /home/hpcc

#----------------------------------------------------
#
# Install HPCC
#

WriteLog "Install HPCC-Platform" "${REGRESS_LOG_FILE}"

${SUDO} ${PKG_INST_CMD} ${BUILD_HOME}/hpccsystems-platform?community*$PKG_EXT > install.log 2>&1

if [ $? -ne 0 ]
then
    echo "TestResult:FAILED" >> install.summary 
    WriteLog "Install HPCC-Platform FAILED" "${REGRESS_LOG_FILE}"
    exit
else
    echo "TestResult:PASSED" >> install.summary
    WriteLog "Install HPCC-Platform PASSED" "${REGRESS_LOG_FILE}"
    WriteLog "Installed version is: $( ${PKG_QRY_CMD} hpccsystems-platform )" "${REGRESS_LOG_FILE}"
fi

# Should be configurable in settings.sh
if [[ $SKIP_LIB64_ISSUE -eq 0 ]]
then
    if [[ -d "/opt/HPCCSystems/lib64" ]]
    then
        WriteLog "There is an unwanted /opt/HPCCSystems/lib64 directory, copy its contents into lib" "${REGRESS_LOG_FILE}"
        res=$( sudo cp -v /opt/HPCCSystems/lib64/* /opt/HPCCSystems/lib/ 2>&1 )
        WriteLog "Res: ${res}" "${REGRESS_LOG_FILE}"
    fi
else
    WriteLog "Skip lib64 issue fixing." "${REGRESS_LOG_FILE}"
fi


[ -z $NUMBER_OF_HPCC_COMPONENTS ] && NUMBER_OF_HPCC_COMPONENTS=$( /opt/HPCCSystems/sbin/configgen -env /etc/HPCCSystems/environment.xml -list | grep -E -i -v 'eclagent' | wc -l )


# Hack SELinux
WriteLog  "Hack SELinux." "${REGRESS_LOG_FILE}"

sudo chcon -R unconfined_u:object_r:user_home_t:s0 /home/hpcc/.ssh/

#
#---------------------------
#
# Patch environment.xml to use multi slaves Thor
#

WriteLog "Patch environment.xml to use ${REGRESSION_NUMBER_OF_THOR_SLAVES} slaves for Thor" "${REGRESS_LOG_FILE}"

${SUDO} cp /etc/HPCCSystems/environment.xml /etc/HPCCSystems/environment.xml.bak
${SUDO} sed -e 's/slavesPerNode=\(.*\)/slavesPerNode="'${REGRESSION_NUMBER_OF_THOR_SLAVES}'"/g' "/etc/HPCCSystems/environment.xml" > temp.xml && ${SUDO} mv -f temp.xml "/etc/HPCCSystems/environment.xml"

WriteLog "Patch environment.xml to use ${REGRESSION_NUMBER_OF_THOR_CHANNELS} channels per slave for Thor" "${REGRESS_LOG_FILE}"
${SUDO} sed -e 's/channelsPerSlave=\(.*\)/channelsPerSlave="'${REGRESSION_NUMBER_OF_THOR_CHANNELS}'"/g' "/etc/HPCCSystems/environment.xml" > temp.xml && ${SUDO} mv -f temp.xml "/etc/HPCCSystems/environment.xml"

if [[ $REGRESSION_NUMBER_OF_THOR_CHANNELS -ne 1 ]]
then 
    WriteLog "Patch environment.xml to use ${REGRESSION_THOR_LOCAL_THOR_PORT_INC} for LOCAL_THOR_PORT_INC for Thor because ${REGRESSION_NUMBER_OF_THOR_CHANNELS} channels per slave used" "${REGRESS_LOG_FILE}"
    ${SUDO} sed -e 's/localThorPortInc="20"/localThorPortInc="'${REGRESSION_THOR_LOCAL_THOR_PORT_INC}'"/g' "/etc/HPCCSystems/environment.xml" > temp.xml && ${SUDO} mv -f temp.xml "/etc/HPCCSystems/environment.xml"
fi    

cp /etc/HPCCSystems/environment.xml ${OBT_BIN_DIR}/environment-sl${REGRESSION_NUMBER_OF_THOR_SLAVES}-ch${REGRESSION_NUMBER_OF_THOR_CHANNELS}.xml

#----------------------------------------------------
#
# Start HPCC Systems
#

WriteLog "Start HPCC system" "${REGRESS_LOG_FILE}"

res=$( sudo service hpcc-init start 2>&1)

WriteLog "res:\n${res}" "${REGRESS_LOG_FILE}"

HPCC_RUNNING=$( sudo service hpcc-init status | grep -c "running")
    
WriteLog $HPCC_RUNNING" HPCC component started." "${REGRESS_LOG_FILE}"

if [[ "$HPCC_RUNNING" -eq "$NUMBER_OF_HPCC_COMPONENTS" ]]
then        
    WriteLog "HPCC Start: OK" "${REGRESS_LOG_FILE}"
else
    WriteLog "HPCC Start: Fail" "${REGRESS_LOG_FILE}"

    res=$( sudo service hpcc-init status | grep  "stopped" ) 
    WriteLog $res "${REGRESS_LOG_FILE}"

    exit
fi

#
#----------------------------------------------------
#
# Check if HPCC can generate core with execute ECL code
#

cd ${BIN_ROOT}

WriteLog "Check ECL core generation." "${REGRESS_LOG_FILE}"

res=$( ulimit -a | grep '[c]ore' )

WriteLog "ulimit: ${res}" "${REGRESS_LOG_FILE}"

./checkCoreGen.sh ecl >> "${REGRESS_LOG_FILE}" 2>&1

# The crash test causes some problem in Roxie therefore it should restart
WriteLog "Restart roxie" "${REGRESS_LOG_FILE}"

res=$( sudo service hpcc-init -c roxie stop )
WriteLog "Stop roxie: ${res}" "${REGRESS_LOG_FILE}"

res=$( sudo service hpcc-init -c roxie start )
WriteLog "Start roxie: ${res}" "${REGRESS_LOG_FILE}"

#----------------------------------------------------
#
# Git repo clone
#

WriteLog "cd ${TEST_ROOT}" "${REGRESS_LOG_FILE}"

cd  ${TEST_ROOT}

#
#----------------------------------------------------
#
# We use branch which is set in settings.sh
#

WriteLog "git checkout $BRANCH_ID" "${REGRESS_LOG_FILE}"

echo "git checkout "$BRANCH_ID >> ${GIT_2DAYS_LOG}
res=$( git checkout ${BRANCH_ID} 2>&1 )

WriteLog "result:${res}" "${REGRESS_LOG_FILE}"

echo $res >> ${GIT_2DAYS_LOG}

#
#----------------------------------------------------
#
# Update submodule
#

WriteLog "Update git submodule" "${REGRESS_LOG_FILE}"

SUB_RES=$( SubmoduleUpdate "--init --recursive")

if [[ 0 -ne  $? ]]
then
    WriteLog "Submodule update failed ! Result is: ${SUB_RES}" "${REGRESS_LOG_FILE}"
else
    WriteLog "Submodule update success !" "${REGRESS_LOG_FILE}"
fi

#
#-----------------------------------------------------
# Patch regression suite teststdlibrary.ecl to see how long it runs
#

TEST_STD_LIBRARY_TIMEOUT=3600

WriteLog "Patch regression suite teststdlibrary.ecl with $TEST_STD_LIBRARY_TIMEOUT sec to force timeout" "${REGRESS_LOG_FILE}"

cp -fv ${SOURCE_HOME}/testing/regress/ecl/teststdlibrary.ecl ${SOURCE_HOME}/testing/regress/ecl/teststdlibrary.ecl-back

sed -e 's/^\/\/timeout \(.*\).*$/\/\/ Patched by the OBT on '"$( date '+%Y.%m.%d %H:%M:%S')"'\n\/\/timeout '"$TEST_STD_LIBRARY_TIMEOUT"'/g' ${SOURCE_HOME}/testing/regress/ecl/teststdlibrary.ecl > patched-teststdlibrary.ecl && mv -f patched-teststdlibrary.ecl ${SOURCE_HOME}/testing/regress/ecl/teststdlibrary.ecl

WriteLog "Done." "${REGRESS_LOG_FILE}"

operation_timeout=15
config_total_timeout=45

WriteLog "Patch regression suite couchbase-simple.ecl with operation_timeout=${operation_timeout} and config_total_timeout=${config_total_timeout} sec to check it is fails or not" "${REGRESS_LOG_FILE}"

cp -fv ${SOURCE_HOME}/testing/regress/ecl/couchbase-simple.ecl ${SOURCE_HOME}/testing/regress/ecl/couchbase-simple.ecl-back

sed -i -e 's/operation_timeout(5.5)/operation_timeout('"${operation_timeout}"')/g' -e 's/config_total_timeout(15)/config_total_timeout('"${config_total_timeout}"')/g'  ${SOURCE_HOME}/testing/regress/ecl/couchbase-simple.ecl

WriteLog "Done." "${REGRESS_LOG_FILE}"


#
#-----------------------------------------------------
# Patch regression suite tests if it needed to prevent extra long execuion tme
# See utlis.sh "Individual timeouts" section

if [[ -n $TIMEOUTS ]]
then
    COUNT=${#TIMEOUTS[@]}
    WriteLog "There is $COUNT test case need individual timeout setting" "${REGRESS_LOG_FILE}"
    for((testIndex=0; testIndex<$COUNT; testIndex++))
    do
        TEST=(${!TIMEOUTS[$testIndex]})
        WriteLog "\tPatch ${TEST[0]} with ${TEST[1]} sec timeout" "${REGRESS_LOG_FILE}"
        file="${SOURCE_HOME}/testing/regress/ecl/${TEST[0]}"
        if [[ -f ${file} ]]
        then
            timeout=${TEST[1]}
            # Check if test already has '//timeout' tag
            if [[ $( grep -E -c '\/\/timeout' $file ) -eq 0 ]]
            then
                # it has not, add one at the beginning of the file
                mv -fv $file $file-back
                echo "// Patched by the Smoketest on $( date '+%Y.%m.%d %H:%M:%S')" > $file
                echo "//timeout $timeout" >> $file
                cat $file-back >> $file
            else
                # yes it has, change it
                cp -fv $file $file-back
                sed -e 's/^\/\/timeout \(.*\).*$/\/\/ Patched by the Smoketest on '"$( date '+%Y.%m.%d %H:%M:%S')"'\n\/\/timeout '"$timeout"'/g' $file > $file-patched && mv -f $file-patched $file
            fi
            WriteLog "$(grep -E -H -B1 -A1 '//timeout ' $file)" "${REGRESS_LOG_FILE}"
            WriteLog "\t\tDone.\n" "${REGRESS_LOG_FILE}"
        else
            WriteLog "\t\t${file} file not exists, skip patching." "${REGRESS_LOG_FILE}"
        fi
    done
else
    WriteLog "No file to patch." "${REGRESS_LOG_FILE}"
fi

#
#-----------------------------------------------------
#
# Handle Python version
#

if [ -f $SOURCE_HOME/initfiles/etc/DIR_NAME/environment.conf.in ]
then
    echo "$SOURCE_HOME/initfiles/etc/DIR_NAME/environment.conf.in"

    ADDITIONAL_PLUGINS=($( cat $SOURCE_HOME/initfiles/etc/DIR_NAME/environment.conf.in | grep -E '^additionalPlugins'| cut -d= -f2 ))
    for plugin in ${ADDITIONAL_PLUGINS[*]}
    do
        UPPER_PLUGIN=${plugin^^}
        echo "plugin: $UPPER_PLUGIN"
        case $UPPER_PLUGIN in
            
            PYTHON2*)   if [[ -z $REGRESSION_EXCLUDE_CLASS  ]]
                        then
                            REGRESSION_EXCLUDE_CLASS="-e python3"
                        else
                            REGRESSION_EXCLUDE_CLASS=$REGRESSION_EXCLUDE_CLASS",python3"
                        fi
                        
                        PYTHON_PLUGIN="-DSUPPRESS_PY3EMBED=ON -DINCLUDE_PY3EMBED=OFF"
                        ;;
                        
            PYTHON3*)   if [[ -z $REGRESSION_EXCLUDE_CLASS  ]]
                        then
                            REGRESSION_EXCLUDE_CLASS="-e python2"
                        else
                            REGRESSION_EXCLUDE_CLASS=$REGRESSION_EXCLUDE_CLASS",python2"
                        fi
                      
                        PYTHON_PLUGIN="-DSUPPRESS_PY2EMBED=ON -DINCLUDE_PY2EMBED=OFF"
                        ;;
                        
            *)          # Do nothing yet
                        ;;
        esac
    done
    echo "Done."
else
    echo "$SOURCE_HOME/initfiles/etc/DIR_NAME/environment.conf.in not found."
fi

# Should check the content(lentgh) of REGRESSION_EXCLUDE_CLASS and REGRESSION_EXCLUDE_FILES
# to avoid orphan ',' char in "Regression:" line.
#echo "Regression:${REGRESSION_EXCLUDE_CLASS}, ${REGRESSION_EXCLUDE_FILES}" > ${GLOBAL_EXCLUSION_LOG}

REG_EXCLUSION=$( [[ -n ${REGRESSION_EXCLUDE_CLASS} ]] && echo "${REGRESSION_EXCLUDE_CLASS}"  || echo "" )

REG_EXCLUSION=$( [[ -n ${REGRESSION_EXCLUDE_FILES} ]] && ( [[ -n "${REG_EXCLUSION}" ]] && echo "${REG_EXCLUSION}, ${REGRESSION_EXCLUDE_FILES}" || echo "${REGRESSION_EXCLUDE_FILES}" ) || ( echo "${REG_EXCLUSION}" ) )

REG_EXCLUSION="Regression: ${REG_EXCLUSION}"

WriteLog "Regression exclusion class: '${REGRESSION_EXCLUDE_CLASS}', file: '${REGRESSION_EXCLUDE_FILES}'" "${REGRESS_LOG_FILE}"

sed -i '1s/^/'"$REG_EXCLUSION"'\n/' $TARGET_DIR/GlobalExclusion.log

cp $TARGET_DIR/GlobalExclusion.log ${GLOBAL_EXCLUSION_LOG}

#
#-----------------------------------------------------
#
# Prepare regression test 
#

cd ..

WriteLog "Prepare regression test" "${REGRESS_LOG_FILE}"

[ ! -d $LOG_DIR ] && mkdir -p $LOG_DIR 
rm -rf ${LOG_DIR}/*

#
#-----------------------------------------------------
#
# Run test 
#

WriteLog "Run regression test" "${REGRESS_LOG_FILE}"

cd  $REGRESSION_TEST_ENGINE_HOME

# ----------------------------------------------------
#
# From ecl-test v0.15 the 'setup' removed from clusters and it becomes separated sub command (See: HPCC-11071)
#
# Setup should run on all clusters

WriteLog "Setup phase" "${REGRESS_LOG_FILE}"

echo -n "TestResult:" > ${TEST_ROOT}/setup.summary 
./ecl-test list | grep -v "Cluster" |
while read cluster
do
    CMD="./ecl-test setup --target ${cluster} --suiteDir $TEST_HOME ${REGRESSION_SETUP_TIMEOUT} --pq ${REGRESSION_SETUP_PARALLEL_QUERIES} ${REGRESSION_GENERATE_STACK_TRACE} ${REGRESSION_PREABORT} ${REGRESSION_EXTRA_PARAM}"

    WriteLog "${CMD}" "${REGRESS_LOG_FILE}"

    if [ ${EXECUTE_REGRESSION_SUITE} -ne 0 ]
    then
        total=0
        passed=0
        failed=0
        
        ${CMD} >> ${REGRESS_LOG_FILE} 2>&1

        RET_CODE=$( echo $? )
        WriteLog "RET_CODE: ${RET_CODE}" "${REGRESS_LOG_FILE}"

        IN_FILE=$( find ${TEST_LOG_DIR} -name 'setup_'${cluster}'.*.log' -type f -print | sort -r | head -n 1 ) 
        WriteLog "IN_FILE: '$IN_FILE'" "${REGRESS_LOG_FILE}"
        
        if [ -n $IN_FILE ]
        then
            total=$( cat ${IN_FILE} | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            passed=$(cat ${IN_FILE} | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            failed=$(cat ${IN_FILE} | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            elapsed=$(cat ${IN_FILE} | sed -n "s/^Elapsed time: \(.*\)$/\1/p")

            [ -z $failed ] && failed=1
            [[ $failed -gt 0 ]] && export setupFailed=1
        fi

        WriteLog "cp ${TEST_LOG_DIR}/setup_${cluster}*.log ${OBT_LOG_DIR}/" "${REGRESS_LOG_FILE}"
        cp ${TEST_LOG_DIR}/setup_${cluster}*.log ${OBT_LOG_DIR}/
        
        HAS_ERROR=$( cat ${REGRESS_LOG_FILE} | grep -c '\[Error\]' )
        
        WriteLog "RET_CODE:${RET_CODE}, HAS_ERROR:$HAS_ERROR, failed:$failed" "${REGRESS_LOG_FILE}"
        
        if [[ (${RET_CODE} -eq 0) && ($HAS_ERROR -eq 0) && ($failed -eq 0) ]]
        then
            WriteLog "Result is clean" "${REGRESS_LOG_FILE}"
            grep -i passed ${OBT_LOG_DIR}/setup.summary 
            [ $? -eq 0 ] && echo -n "," >> ${OBT_LOG_DIR}/setup.summary 
            echo -n "${cluster}:total:${total} passed:${passed} failed:${failed} elapsed:${elapsed} " >> ${OBT_LOG_DIR}/setup.summary 

            WriteLog "${cluster}:total:${total} passed:${passed} failed:${failed} elapsed:${elapsed} " "${REGRESS_LOG_FILE}"
        else
            WriteLog "Result is dirty" "${REGRESS_LOG_FILE}"
            WriteLog "Regression setup on ${cluster} returns with ${RET_CODE}" "${REGRESS_LOG_FILE}"
            #                                  get part from        Start        End             Remove  END              &  empty line
            IN_SUITE_ERROR_LOG=$( cat ${REGRESS_LOG_FILE} | sed -n "/\[Error\]/,/Suite destructor./ { /Suite destructor./d ; /^$/d ; p }" )
            WriteLog "IN_SUITE_ERROR_LOG:${IN_SUITE_ERROR_LOG}" "${REGRESS_LOG_FILE}"
            
            grep -i passed ${TEST_ROOT}/setup.summary 
            [ $? -eq 0 ] && echo -n "," >> ${OBT_LOG_DIR}/setup.summary 
            echo -n "${cluster}:total:${total} passed:${passed} failed:${failed} elapsed:${elapsed} " >> ${TEST_ROOT}/setup.summary
            echo "${IN_SUITE_ERROR_LOG}" >> ${OBT_LOG_DIR}/setup.summary
            WriteLog "${cluster}:total:${total} passed:${passed} failed:${failed} elapsed:${elapsed} " "${REGRESS_LOG_FILE}"
            
            WriteLog "Exit with code 7" "${REGRESS_LOG_FILE}"
            exit 7
        fi
    else
        WriteLog "Skip regression suite setup execution on ${cluster}!" "${REGRESS_LOG_FILE}"
        WriteLog "                                                    " "${REGRESS_LOG_FILE}"        
    fi
done

# -----------------------------------------------------
# 
# Run regression suite on all clusters
# 

WriteLog "Regression Suite phase" "${REGRESS_LOG_FILE}"

if [[ ${COUCHBASE_SERVER} == "" ]]
then
    COUCHBASE_SERVER_VAR=
else
    COUCHBASE_SERVER_VAR="-X CouchbaseServerIp="${COUCHBASE_SERVER}
fi

WriteLog "COUCHBASE_SERVER_VAR:'${COUCHBASE_SERVER_VAR}'" "${REGRESS_LOG_FILE}"

./ecl-test list | grep -v "Cluster" |
while read cluster
do

    CMD="./ecl-test run --target ${cluster} --suiteDir $TEST_HOME ${REGRESSION_TIMEOUT} --pq ${REGRESSION_PARALLEL_QUERIES} ${COUCHBASE_SERVER_VAR} ${REGRESSION_EXCLUDE_CLASS} ${REGRESSION_EXCLUDE_FILES} ${REGRESSION_GENERATE_STACK_TRACE} ${REGRESSION_PREABORT} ${REGRESSION_EXTRA_PARAM}"

    WriteLog "${CMD}" "${REGRESS_LOG_FILE}"
    if [ ${EXECUTE_REGRESSION_SUITE} -ne 0 ]
    then
        ${CMD} >> ${REGRESS_LOG_FILE} 2>&1 

        RET_CODE=$( echo $? )
        WriteLog "RET_CODE: ${RET_CODE}" "${REGRESS_LOG_FILE}"

        IN_FILE=$( find ${TEST_LOG_DIR} -name ${cluster}'.*.log' -type f -print | sort -r | head -n 1 ) 
        if [ -n $IN_FILE ]
        then
            total=$( cat ${IN_FILE} | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            passed=$(cat ${IN_FILE} | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            failed=$(cat ${IN_FILE} | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
            elapsed=$(cat ${IN_FILE} | sed -n "s/^Elapsed time: \(.*\)$/\1/p")

            [ -z $failed ] && failed=1

            [ $failed -gt 0 ] && export testFailed=1
        fi

        HAS_ERROR=$( cat ${REGRESS_LOG_FILE} | grep -c '\[Error\]' )

        if [[ (${RET_CODE} -eq 0) && ($HAS_ERROR -eq 0) ]] 
        then
            WriteLog "cp ${LOG_DIR}/${cluster}*.log ${OBT_LOG_DIR}/" "${REGRESS_LOG_FILE}"
            cp ${TEST_LOG_DIR}/${cluster}*.log ${OBT_LOG_DIR}/.
            
            echo "TestResult:Total:${total} passed:${passed} failed:${failed} elapsed:${elapsed}" > ${OBT_LOG_DIR}/${cluster}.summary 

            WriteLog "${cluster} test result:Total:${total} passed:${passed} failed:${failed} elapsed:${elapsed}" "${REGRESS_LOG_FILE}"
        else
            WriteLog "Regression tests on ${cluster} returns with ${RET_CODE}" "${REGRESS_LOG_FILE}"
            #                                  get part from        Start        End             Remove  END              &  empyt line
            IN_SUITE_ERROR_LOG=$( cat ${REGRESS_LOG_FILE} | sed -n "/\[Error\]/,/Suite destructor./ { /Suite destructor./d ; /^$/d ; p }" )
            WriteLog "${IN_SUITE_ERROR_LOG}" "${REGRESS_LOG_FILE}"
            echo -n "TestResult:Total:${total} passed:${passed} failed:${failed} elapsed:${elapsed}" > ${OBT_LOG_DIR}/${cluster}.summary 
            echo "${IN_SUITE_ERROR_LOG}" >> ${OBT_LOG_DIR}/${cluster}.summary 

            exit -1
        fi
    else
        WriteLog "Skip regression suite execution on ${cluster}!" "${REGRESS_LOG_FILE}"
        WriteLog "                                              " "${REGRESS_LOG_FILE}"    
    fi
done

# Get tests stat
if [[ -f $OBT_BIN_DIR/QueryStat2.py ]]
then
    WriteLog "Get tests stat..." "${REGRESS_LOG_FILE}"
    CMD="$OBT_BIN_DIR/QueryStat2.py -p ${HOME}/Perfstat/ -d '' -a --timestamp --compileTimeDetails 1 "
    WriteLog "  CMD: '$CMD'" "${REGRESS_LOG_FILE}"
    ${CMD} >> ${REGRESS_LOG_FILE} 2>&1
    RET_CODE=$( echo $? )
    WriteLog "  RET_CODE: $RET_CODE" "${REGRESS_LOG_FILE}"
    WriteLog "  Files: $( ls -l perfstat* )" "${REGRESS_LOG_FILE}"
    WriteLog "Done." "${REGRESS_LOG_FILE}"
else
    WriteLog "$OBT_BIN_DIR/QueryStat2.py not found. Skip perfromance result collection " "${REGRESS_LOG_FILE}"
fi

#-----------------------------------------------------------------------------
#
# Epilog of Regression test
#

WriteLog "Copy regression test logs to ${TARGET_DIR}/test" "${REGRESS_LOG_FILE}"

if [ ! -e ${TARGET_DIR}/test ]
then
    WriteLog "Create ${TARGET_DIR}/test directory..." "${REGRESS_LOG_FILE}"
    mkdir -p ${TARGET_DIR}/test
fi

WriteLog "cp ${TEST_LOG_DIR}/*.log   ${TARGET_DIR}/test/" "${REGRESS_LOG_FILE}"
cp ${TEST_LOG_DIR}/*.log   ${TARGET_DIR}/test/

WriteLog "cp ${OBT_LOG_DIR}/*.summary   ${TARGET_DIR}/test/" "${REGRESS_LOG_FILE}"
cp ${OBT_LOG_DIR}/*.summary   ${TARGET_DIR}/test/

WriteLog "cp ${OBT_LOG_DIR}/environment*.xml  ${TARGET_DIR}/" "${REGRESS_LOG_FILE}"
cp ${OBT_LOG_DIR}/environment*.xml  ${TARGET_DIR}/


WriteLog "Store trace file(s) from ${TEST_LOG_DIR} into the relatted ZAP file " "${REGRESS_LOG_FILE}"
pushd $TEST_LOG_DIR 

res=$( find . -iname 'W20*.trace' -type f -print | tr -d './' | tr '-' ' ' | awk {'print $1"-"$2'} | while read myid; do  find ../zap/ -iname 'ZAPReport_'"$myid"'_*.zip' -type f -print  | while read zap; do echo "id:${myid}, zap:$zap"; zip -u $zap $myid*.trace; done ; done; )
WriteLog "res: ${res}" "${REGRESS_LOG_FILE}"

res=$( find . -iname 'W20*.trace' -type f -print | tr -d './' | tr '-' ' ' | awk {'print $1"-"$2"-"$3'} | while read myid; do  find ../zap/ -iname 'ZAPReport_'"$myid"'_*.zip' -type f -print  | while read zap; do echo "id:${myid}, zap:$zap"; zip -u $zap $myid*.trace; done ; done; )
WriteLog "res: ${res}" "${REGRESS_LOG_FILE}"

popd

WriteLog "Copy regression test ZAP files to ${TARGET_DIR}/test/ZAP" "${REGRESS_LOG_FILE}"

if [ ! -e ${TARGET_DIR}/test/ZAP ]
then
    WriteLog "Create ${TARGET_DIR}/test/ZAP directory..." "${REGRESS_LOG_FILE}"
    mkdir -p ${TARGET_DIR}/test/ZAP
fi

WriteLog "cp ${ZAP_DIR}/* ${TARGET_DIR}/test/ZAP/" "${REGRESS_LOG_FILE}"
cp ${ZAP_DIR}/* ${TARGET_DIR}/test/ZAP/


if [[ $setupFailed -eq 1 || $testFailed -eq 1 ]] 
then
    WriteLog "Setup and/or test failed (setupFailed: ${$setupFailed}, testFailed: $testFailed)" "${REGRESS_LOG_FILE}"
    WriteLog "Zip whole engine log set from /var/log/HPCCSystem and upload into '${TARGET_DIR}/log-archive/'" "${REGRESS_LOG_FILE}"

    # ZIP and upload whole /var/log/HPCCSystem into ${TARGET_DIR}/log-archive/
    find /var/log/HPCCSystems/ -name '*.log' -type f -exec \
    zip 'var-log-HPCCSystems' '{}' \; >> 'var-log-HPCCSystems.log'

    [ -f var-log-HPCCSystems.zip ] && cp var-log-HPCCSystems* ${TARGET_DIR}/log-archive/

fi

cd ${BIN_ROOT}
WriteLog "Send Email notification about Regression test" "${REGRESS_LOG_FILE}"

# Email Notify
./BuildNotification.py -d ${OBT_DATESTAMP} -t ${OBT_TIMESTAMP} >> "${REGRESS_LOG_FILE}" 2>&1

WriteLog "Archive regression testing logs" "${REGRESS_LOG_FILE}"

./archiveLogs.sh regress timestamp=${OBT_TIMESTAMP}

rm ./dump.rdb

#-----------------------------------------------------------------------------
#
# End of Regression test
#

WriteLog "End of Regression test" "${REGRESS_LOG_FILE}"

