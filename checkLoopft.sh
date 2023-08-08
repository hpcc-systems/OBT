#!/bin/bash

TEST_NAME="loopft"

find /tmount/data2/nightly_builds/HPCC/candidate-7.0.x/ -iname 'thor*.log' -type f -exec grep -E -H '(Pass|Fail) '"${TEST_NAME}" '{}' \; | sort > ${TEST_NAME}-$(date "+%Y-%m-%d_%H-%M-%S").log
