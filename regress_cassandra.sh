#!/bin/bash

#
#------------------------------
#
# Import settings
#
# Git branch

. ./settings.sh

# WriteLog() function

. ./timestampLogger.sh

#
#------------------------------
#
# Constants
#

TEST_ROOT=~/test
TEST_HOME=${TEST_ROOT}/HPCC-Platform/testing/regress
BUILD_HOME=~/build/CE/platform/build
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
REGRESS_LOG_FILE=${BUILD_HOME}/regress-${LONG_DATE}.log

#
#----------------------------------------------------
#
# Start Regression Test process
#

WriteLog "Regression test started" "${REGRESS_LOG_FILE}"

#
#----------------------------------------------------
#
# Check MySQL server state
#

WriteLog "Check MySQL server state" "${REGRESS_LOG_FILE}"

#./checkMySQL.sh


#
#----------------------------------------------------
#
# Check Cassandra state
#

WriteLog "Check Cassandra state" "${REGRESS_LOG_FILE}"

./checkCassandra.sh

exit

#
#----------------------------------------------------
#
# Check Memcached state
#

WriteLog "Check Memcached state" "${REGRESS_LOG_FILE}"

./checkMemcached.sh


#
#----------------------------------------------------
#
# Clean-up, git repo clone and git submodule
#

WriteLog "Clean system" "${REGRESS_LOG_FILE}"

[ ! -e $TEST_ROOT ] && mkdir -p $TEST_ROOT

rm -rf ${TEST_ROOT}/*
cd  ${TEST_ROOT}


rpm -qa | grep hpcc | grep -v grep | \
while read hpcc_package
do
   rpm -e $hpcc_package
done


rm -rf  clean.failed
rpm -qa | grep -v grep | grep hpcc > /dev/null 2>&1
if [ $? -eq 0 ]
then
   touch  clean.failed
   exit
fi

#backup sys log files
[ ! -e /root/HPCCSystems-regression/syslog ] && mkdir -p /root/HPCCSysytems-regression/syslog
/bin/cp -rf /var/log/HPCCSystems/*/*.* /root/HPCCSystems-regression/syslog/

# Post uninstall
rm -rf /var/*/HPCCSystems/*
rm -rf /*/HPCCSystems
userdel hpcc 
rm -rf /Users/hpcc
rm -rf /tmp/remote_install
rm -rf /home/hpcc


#----------------------------------------------------
#
# Install HPCC
#

WriteLog "Install HPCC-Platform" "${REGRESS_LOG_FILE}"

rpm -i --nodeps ${BUILD_HOME}/hpccsystems-platform?community*.rpm > install.log 2>&1
if [ $? -ne 0 ]
then
   echo "TestResult:FAILED" >> install.summary 
   WriteLog "Install HPCC-Platform FAILED" "${REGRESS_LOG_FILE}"
   exit
else
   echo "TestResult:PASSED" >> install.summary
   WriteLog "Install HPCC-Platform PASSED" "${REGRESS_LOG_FILE}"
fi
service hpcc-init start


#----------------------------------------------------
#
# Get test from github
#

WriteLog "Get test from github" "${REGRESS_LOG_FILE}"

git clone https://github.com/hpcc-systems/HPCC-Platform.git 
cd HPCC-Platform
git submodule update --init


#
#----------------------------------------------------
#
# We use branch which is set in settings.sh
#

WriteLog "git checkout "$BRANCH_ID "${REGRESS_LOG_FILE}"

echo "git checkout "$BRANCH_ID >> ../build/git_2days.log
res=$( git checkout ${BRANCH_ID} 2>&1 )

WriteLog "result:"${res} "${REGRESS_LOG_FILE}"

echo $res >> ../build/git_2days.log


#
#-----------------------------------------------------
#
# Use roxie debug version of environment.xml
#

WriteLog "Use roxie debug version of environment.xml" "${REGRESS_LOG_FILE}"

cp /root/build/bin/environment.xml.roxie.debug /etc/HPCCSystems/environment.xml


#
#-----------------------------------------------------
#
# Prepare regression test 
#

cd ..

WriteLog "Prepare reqgression test" "${REGRESS_LOG_FILE}"

logDir=/root/HPCCSystems-regression/log
[ ! -d $logDir ] && mkdir -p $logDir 
rm -rf ${logDir}/*

libDir=/var/lib/HPCCSystems/regression
[ ! -d $libDir ] && mkdir  -p  $libDir
rm -rf ${libDir}/*

#
#-----------------------------------------------------
#
# Run test 
#

WriteLog "Run regression test" "${REGRESS_LOG_FILE}"

cd  $TEST_HOME

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

  echo ""

  echo "./ecl-test setup --target $cluster"
  WriteLog "./ecl-test setup --target $cluster" "${REGRESS_LOG_FILE}"


  ./ecl-test setup --target $cluster

 
  #cp ${logDir}/thor.*.log ${TEST_ROOT}/
  cp ${logDir}/setup_${cluster}*.log ${TEST_ROOT}/

  total=$(cat ${logDir}/setup_${cluster}.*.log | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  passed=$(cat ${logDir}/setup_${cluster}.*.log | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  failed=$(cat ${logDir}/setup_${cluster}.*.log | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  #[ $passed -gt 0 ] && passed="<span style=\"color:#298A08\">$passed</span>"
  #[ $failed -gt 0 ] && failed="<span style=\"color:#FF0000\">$passed</span>"
  grep -i passed ${TEST_ROOT}/setup.summary 
  [ $? -eq 0 ] && echo -n "," >> ${TEST_ROOT}/setup.summary 
  echo -n "${cluster}:total:${total} passed:${passed} failed:${failed}" >> ${TEST_ROOT}/setup.summary 

  WriteLog "${cluster}:total:${total} passed:${passed} failed:${failed}" "${REGRESS_LOG_FILE}"

done

# -----------------------------------------------------
# 
# Run regression suite on all clusters
# 

WriteLog "Regression Suite phase" "${REGRESS_LOG_FILE}"


./ecl-test list | grep -v "Cluster" |
while read cluster
do

  echo ""
#  echo "./ecl-test --loglevel debug run --target $cluster"
#  ./ecl-test --loglevel debug run --target $cluster

  WriteLog "./ecl-test run --target $cluster" "${REGRESS_LOG_FILE}"
  echo "./ecl-test run --target $cluster"
  ./ecl-test run --target $cluster 

  cp ${logDir}/${cluster}*.log ${TEST_ROOT}/
  total=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  passed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  failed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  #[ $passed -gt 0 ] && passed="<span style=\"color:#298A08\">$passed</span>"
  #[ $failed -gt 0 ] && failed="<span style=\"color:#FF0000\">$passed</span>"
  echo "TestResult:Total:${total} passed:$passed failed:$failed" > ${TEST_ROOT}/${cluster}.summary 

  WriteLog "TestResult:Total:${total} passed:$passed failed:$failed" "${REGRESS_LOG_FILE}"

done


# -----------------------------------------------------
# 
# Uninstall HPCC
# 

WriteLog "Uninstall HPCC-Platform" "${REGRESS_LOG_FILE}"


cd $TEST_ROOT

uninstallFailed=FALSE
hpccPackageName=$(rpm -qa | grep hpcc)
rpm -e $hpccPackageName  >  uninstall.log 2>&1
[ $? -ne 0 ] && uninstallFailed=TRUE

rpm -qa | grep hpcc  > /dev/null 2>&1
[ $? -eq 0 ] && uninstallFailed=TRUE


if [ "$uninstallFailed" = "TRUE" ]
then
   echo "TestResult:FAILED" >> uninstall.summary 
   WriteLog "Uninstall HPCC-Platform FAILED" "${REGRESS_LOG_FILE}"

else
   echo "TestResult:PASSED" >> uninstall.summary 
   WriteLog "Uninstall HPCC-Platform PASSED" "${REGRESS_LOG_FILE}"
fi


#-----------------------------------------------------------------------------
#
# End of Regression test
#

WriteLog "End of Regression test" "${REGRESS_LOG_FILE}"
