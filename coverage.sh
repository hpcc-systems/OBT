#!/bin/bash
clear 

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

. ./UninstallHPCC.sh

#
#------------------------------
#
# Constants
#

COVERAGE_ROOT=~/coverage
TEST_ROOT=~/build/CE/platform
TEST_HOME=${TEST_ROOT}/HPCC-Platform/testing/regress
BUILD_HOME=~/build/CE/platform/build
BUILD_LOG=${COVERAGE_ROOT}/build_log
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
COVERAGE_LOG_FILE=${BUILD_HOME}/coverage-${LONG_DATE}.log

BUILD_ONLY=1

DEFAULT_UMASK=$(umask)

#
#----------------------------------------------------
#
# Start Coverage process
#

WriteLog "Coverage test started" "${COVERAGE_LOG_FILE}"

#
#----------------------------------------------------
#
# Clean-up
#

WriteLog "Clean system" "${COVERAGE_LOG_FILE}"

echo "Clean system" > ${BUILD_LOG} 2>&1

[ ! -e $COVERAGE_ROOT ] && mkdir -p $COVERAGE_ROOT

${SUDO} rm -rf ${COVERAGE_ROOT}/*

#----------------------------------------------------
#
# Uninstall HPCC
#

WriteLog "Uninstall HPCC-Platform" "${COVERAGE_LOG_FILE}"

UninstallHPCC "${COVERAGE_LOG_FILE}"

# --------------------------------------------------------------
#
# Build HPCC with coverage
#

WriteLog "Build HPCC with coverage in ${BUILD_HOME}" "${COVERAGE_LOG_FILE}"

cd ${BUILD_HOME}

CMD="cmake -DGENERATE_COVERAGE_INFO=ON -DCMAKE_BUILD_TYPE=Release -DUSE_LIBXSLT=ON -DXALAN_LIBRARIES= -DMYSQL_LIBRARIES=/usr/lib64/mysql/libmysqlclient.so -DMYSQL_INCLUDE_DIR=/usr/include/mysql -DMAKE_MYSQLEMBED=1 ../HPCC-Platform"

WriteLog "cdm:${CMD}" "${COVERAGE_LOG_FILE}"

${CMD} >> ${COVERAGE_LOG_FILE} 2>&1

#make -j 8 package >> ${COVERAGE_LOG_FILE} 2>&1
# Won't work with 
CMD="make -j ${NUMBER_OF_CPUS} package"
    
${CMD} >> ${COVERAGE_LOG_FILE} 2>&1

if [ $? -ne 0 ] 
then
   WriteLog "Build failed: no rpm package found" "${COVERAGE_LOG_FILE}"
   echo "Build failed: build has errors " >> ${BUILD_LOG}
   buildResult=FAILED
else
   ls -l hpcc*.rpm >/dev/null 2>&1
   if [ $? -ne 0 ] 
   then
      WriteLog "Build failed: no rpm package found" "${COVERAGE_LOG_FILE}"
      echo "Build failed: no rpm package found " >> ${BUILD_LOG}
      buildResult=FAILED
   else
      WriteLog "Build succeed" "${COVERAGE_LOG_FILE}"
      echo "Build succeed" >> ${BUILD_LOG}
      buildResult=SUCCEED
   fi
fi

CURRENT_DATE=$( date "+%Y-%m-%d %H:%M:%S")
WriteLog "Build ${buildResult} at ${CURRENT_DATE}" "${COVERAGE_LOG_FILE}"
echo "Build ${buildResult} at "${CURRENT_DATE} >> ${BUILD_LOG} 2>&1

if [ "$buildResult" = "FAILED" ]
then
    echo "No Coverage result." >> ./coverage.summary

    cp ./coverage.summary $COVERAGE_ROOT/

    # send email to Agyi
    echo "Coverage build Failed! Check the logs!" | mailx -s "Problem with Coverage" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    
    exit
fi

#----------------------------------------------------
#
# Install HPCC
#

WriteLog "Install HPCC-Platform" "${COVERAGE_LOG_FILE}"
echo "Install HPCC-Platform"  >> ${BUILD_LOG} 2>&1

${SUDO} rpm -i --nodeps ${BUILD_HOME}/hpccsystems-platform?community*.rpm

if [ $? -ne 0 ]
then
   echo "TestResult:FAILED" >> $TEST_ROOT/install.summary
   echo "TestResult:FAILED" >> ${BUILD_LOG} 2>&1
   WriteLog "Install HPCC-Platform FAILED" "${COVERAGE_LOG_FILE}"

   exit
else
   echo "TestResult:PASSED" >> $TEST_ROOT/install.summary
   echo "TestResult:PASSED" >> ${BUILD_LOG} 2>&1
   WriteLog "Install HPCC-Platform PASSED" "${COVERAGE_LOG_FILE}"
fi

# --------------------------------------------------------------
#
# Set up coverage environment
#

WriteLog "Set up coverage environment" "${COVERAGE_LOG_FILE}"
echo "Set up coverage environment" >> ${BUILD_LOG} 2>&1

find . -name "*.dir" -type d -exec chmod -R 777 {} \;

umask 0

lcov --zerocounters --directory .

res=$( grep 'umask' -c /etc/HPCCSystems/environment.conf )

if [[ ${res} -eq 0 ]]
then
    echo ""
    echo "Patch environment.conf file. Add 'umask=0' at the end."
    echo "Patch environment.conf file. Add 'umask=0' at the end." >> ${BUILD_LOG} 2>&1

    sudo cp /etc/HPCCSystems/environment.conf /etc/HPCCSystems/environment.conf-orig
    sudo bash -c 'echo "umask=0" >>/etc/HPCCSystems/environment.conf'
fi

# --------------------------------------------------------------
#
# Start HPCC Systems
#

WriteLog "Start HPCC Systems" "${COVERAGE_LOG_FILE}"
echo "Start HPCC" >> ${BUILD_LOG} 2>&1

${SUDO} service hpcc-init start

if [[ $BUILD_ONLY -eq 1 ]]
then
    WriteLog "That was a build only run. Exit." "${COVERAGE_LOG_FILE}"
    echo "That was a build only run. Exit."
    exit
fi

# --------------------------------------------------------------
#
# Prepare regression test in coverage enviromnment
#

WriteLog "Prepare regression test in coverage enviromnment" "${COVERAGE_LOG_FILE}"

echo "Prepare reqgression test" >> ${BUILD_LOG} 2>&1

logDir=${TEST_LOG_DIR}
[ ! -d $logDir ] && mkdir -p $logDir
rm -rf ${logDir}/*

libDir=/var/lib/HPCCSystems/regression
[ ! -d $libDir ] && mkdir  -p  $libDir
rm -rf ${libDir}/*

#
# --------------------------------------------------------------
#
# Run test
#

WriteLog "Run regression test" "${COVERAGE_LOG_FILE}"
echo "Run reqgression test" >> ${BUILD_LOG} 2>&1

cd  $TEST_HOME

WriteLog "Set and export coverage variable for create coverage build" "${COVERAGE_LOG_FILE}"
echo "Set and export coverage variable for create coverage build" >> ${BUILD_LOG} 2>&1

coverage=1
export coverage

# ----------------------------------------------------
#
#From ecl-test v0.15 the 'setup' removed from clusters and it becomes separated sub command (See: HPCC-11071)
#
# Setup should run on all clusters

WriteLog "Setup phase" "${COVERAGE_LOG_FILE}"

./ecl-test list | grep -v "Cluster" |
while read cluster
do

  echo ""

  CMD="./ecl-test setup --target $cluster"
 
  echo "${CMD}" >> ${BUILD_LOG} 2>&1
  WriteLog "${CMD}" "${COVERAGE_LOG_FILE}"

  ${CMD} >> ${COVERAGE_LOG_FILE} 2>&1

  # --------------------------------------------------
  # temporarly fix for wrongly generated setup logfile

  for f in $(ls -1 ${logDir}/${cluster}.*.log)
     do mv $f ${logDir}/setup_${cluster}.${f#*.}
  done

  for f in $(ls -1 ${logDir}/${cluster}-exclusion.*.log)
     do mv $f ${logDir}/setup_${cluster}-exclusion.${f#*.}
  done

  # -------------------------------------------------

  cp ${logDir}/setup_${cluster}*.log ${COVERAGE_ROOT}/

  total=$(cat ${logDir}/setup_${cluster}*.log | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  passed=$(cat ${logDir}/setup_${cluster}*.log | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  failed=$(cat ${logDir}/setup_${cluster}*.log | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")

  echo ${cluster}" Setup Result:Total:${total} passed:$passed failed:$failed" >> ${COVERAGE_ROOT}/setup.summary 
  echo ${cluster}" Setup Result:Total:${total} passed:$passed failed:$failed" >> ${BUILD_LOG} 2>&1
  echo ${cluster}" Setup Result:Total:${total} passed:$passed failed:$failed"
  WriteLog "${cluster} Setup Result:Total:${total} passed:$passed failed:$failed" "${COVERAGE_LOG_FILE}"

done

# -----------------------------------------------------
#
# Run tests
#

WriteLog "Regression Suite phase" "${COVERAGE_LOG_FILE}"

./ecl-test list | grep -v "Cluster" |
while read cluster
do
  CMD="./ecl-test run --target $cluster"
  echo "${CMD}" >> ${BUILD_LOG} 2>&1
  WriteLog "./ecl-test run --target $cluster" "${COVERAGE_LOG_FILE}"

  ${CMD} >> ${COVERAGE_LOG_FILE} 2>&1

  cp ${logDir}/${cluster}*.log ${COVERAGE_ROOT}/

  total=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  passed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  failed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")

  echo "TestResult:Total:${total} passed:$passed failed:$failed" > ${COVERAGE_ROOT}/${cluster}.summary
  echo "TestResult:Total:${total} passed:$passed failed:$failed" >> ${BUILD_LOG} 2>&1
  echo ${cluster}" testResult:Total:${total} passed:$passed failed:$failed"
  WriteLog "TestResult:Total:${total} passed:$passed failed:$failed" "${COVERAGE_LOG_FILE}"

done

res=$(sudo service hpcc-init stop |grep 'still')
# If the result is "Service dafilesrv, mydafilesrv is still running."
if [[ -n $res ]]
then
   echo $res
   sudo service dafilesrv stop
fi

#
# --------------------------------------------------------------
#
# Generate coverage report
#

WriteLog "Generate coverage report" "${COVERAGE_LOG_FILE}"

echo "Generate coverage report"  >> ${BUILD_LOG} 2>&1

cd $BUILD_HOME
${SUDO} lcov --capture --directory . --output-file $COVERAGE_ROOT/hpcc_coverage.lcov > $COVERAGE_ROOT/lcov.log 2>&1

${SUDO} genhtml --highlight --legend --ignore-errors source --output-directory $COVERAGE_ROOT/hpcc_coverage $COVERAGE_ROOT/hpcc_coverage.lcov > $COVERAGE_ROOT/genhtml.log 2>&1

cd $COVERAGE_ROOT

WriteLog "Generate coverage report summary" "${COVERAGE_LOG_FILE}"

echo "Generate coverage summary" >> ${BUILD_LOG} 2>&1

grep -i "coverage rate" -A3 ./genhtml.log > coverage.summary
echo "(This is an experimental result, yet. Use it carefully.)" >> coverage.summary

cp coverage.summary ~/test/

umask $DEFAULT_UMASK

WriteLog "Uninstall HPCC-Platform" "${COVERAGE_LOG_FILE}"

UninstallHPCC "${COVERAGE_LOG_FILE}"

#-----------------------------------------------------------------------------
#
# End of Coverage process
#
#

WriteLog "End of Coverage process" "${COVERAGE_LOG_FILE}"

echo ""
echo "End."
echo "End." >> ${BUILD_LOG} 2>&1

