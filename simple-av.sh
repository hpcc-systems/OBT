#!/bin/bash
DATE=$(date "+%Y-%m-%d")
BUILD_DIR=/root/build
RELEASE_BASE=master
RELEASE=
STAGING_DIR=/tmount/data2/nightly_builds/HPCC/$RELEASE_BASE
BUILD_SYSTEM=centos_6_x86_64
BUILD_TYPE=CE/platform

cd ${BUILD_DIR}/$BUILD_TYPE
rm -rf build HPCC-Platform
git clone https://github.com/hpcc-systems/HPCC-Platform.git
mkdir build
cd HPCC-Platform
echo "git remote -v:"  > ../build/git_2days.log
git remote -v  >> ../build/git_2days.log

echo ""  >> ../build/git_2days.log
echo "git branch: $(git branch)"  >> ../build/git_2days.log

echo ""  >> ../build/git_2days.log
cat ${BUILD_DIR}/bin/gitlog.sh >> ../build/git_2days.log
${BUILD_DIR}/bin/gitlog.sh >> ../build/git_2days.log

cd ../build

${BUILD_DIR}/bin/build_pf.sh HPCC-Platform

make package > build.log 2>&1
if [ $? -ne 0 ] 
then
   echo "Build failed: build has errors " >> build.log
   buildResult=FAILED
else
   ls -l hpcc*.rpm >/dev/null 2>&1
   if [ $? -ne 0 ] 
   then
      echo "Build failed: no rpm package found " >> build.log
      buildResult=FAILED
   else
      echo "Build succeed" >> build.log
      buildResult=SUCCEED
   fi
fi

TARGET_DIR=${STAGING_DIR}/${DATE}/${BUILD_SYSTEM}/${BUILD_TYPE}

[ ! -e "${TARGET_DIR}" ] && mkdir -p  $TARGET_DIR

cp git_2days.log  $TARGET_DIR/
cp build.log  $TARGET_DIR/
cp hpcc*.rpm  $TARGET_DIR/
if [ "$buildResult" = "SUCCEED" ]
then
   echo "BuildResult:SUCCEED" >   $TARGET_DIR/build_summary
else
   echo "BuildResult:FAILED" >   $TARGET_DIR/build_summary
fi

# Test
cd /root/build/bin
./regress.sh
mkdir -p   ${TARGET_DIR}/test
cp /root/test/*.log   ${TARGET_DIR}/test/
cp /root/test/*.summary   ${TARGET_DIR}/test/


# Remove old builds
${BUILD_DIR}/bin/clean_builds.sh

# Email Notify
./BuildNotification.py

