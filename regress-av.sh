#!/bin/bash

TEST_ROOT=~/test
TEST_HOME=${TEST_ROOT}/HPCC-Platform/testing/regress

# Clean system

echo ""

cd  ${TEST_ROOT}

# Prepare regression test 
echo ""
echo "Prepare reqgression test"
logDir=/root/HPCCSystems-regression/log
[ ! -d $logDir ] && mkdir -p $logDir 
rm -rf ${logDir}/*

libDir=/var/lib/HPCCSystems/regression
[ ! -d $libDir ] && mkdir  -p  $libDir
rm -rf ${libDir}/*

# Run test 
echo ""
echo "Run reqgression test"
cd  $TEST_HOME
./regress --suiteDir . list | grep -v "Cluster" |
while read cluster
do
  echo ""
  echo "./regress --suiteDir . run $cluster"
  ./regress --suiteDir . run $cluster
  cp ${logDir}/${cluster}*.log ${TEST_ROOT}/
  total=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Queries:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  passed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Passing:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")
  failed=$(cat ${logDir}/${cluster}*.log | sed -n "s/^[[:space:]]*Failure:[[:space:]]*\([0-9]*\)[[:space:]]*$/\1/p")

  echo "TestResult:Total:${total} passed:$passed failed:$failed" > ${TEST_ROOT}/${cluster}.summary 
done

cd $TEST_ROOT

