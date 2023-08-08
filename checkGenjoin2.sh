#!/bin/bash


find /common/nightly_builds/HPCC/candidate-7.2.x/ -iname 'thor*.log' -type f -exec grep -E -H '(Pass|Fail) genjoin2.ecl' '{}' \; | sort > genjoin2-$(date "+%Y-%m-%d_%H-%M-%S").log
