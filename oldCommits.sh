#!/bin/bash

PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }' 
#set -x

GetCommitSha()
{
    #set -x
    testDate=$1
    sourceDate=$( date -I -d "$testDate - 1 day" )
    
    pushd ~/HPCC-Platform
    
    sha=$( git log --after="$sourceDate 00:00" --before="$testDate 00:00$" --merges | grep -A3 'commit' | head -n 1 | cut -d' ' -f2 )
    until [[ -n "$sha" ]]
    do
        # step one day back
        sourceDate=$( date -I -d "$sourceDate - 1 day" )
        # Get SHA
        sha=$( git log --after="$sourceDate 00:00" --before="$testDate 00:00$" --merges | grep -A3 'commit' | head -n 1 | cut -d' ' -f2 )
    done
    echo $sha
    
    popd > /dev/null
    set +x
}

CWD=$( pwd ) 
targetFile="${PWD}/settings.inc"
firstDate="2020-06-24"
sourceDate=$firstDate
testDate=$( date -I -d "$firstDate + 1 day" )
lastDate="2020-06-27"

printf "from %s to %s\n" "$firstDate" "$lastDate"
printf "#\n" > ${targetFile}
printf "# from %s to %s\n#\n\n" "$firstDate" "$lastDate" >> ${targetFile}

pushd ~/HPCC-Platform

dayCount=0
commitCounts=0
mark=''

printf "Test date\tsource date\tcommit\n"
until [[ "$testDate" > "$lastDate" ]]
do 
    commit=$( git log --after="$sourceDate 00:00" --before="$testDate 00:00" --merges | grep -A3 'commit' )
    #echo "$commit"
    sha=$( git log --after="$sourceDate 00:00" --before="$testDate 00:00" --merges | grep -A3 'commit' | head -n 1 | cut -d' ' -f2 )
    if [[ -n "$sha" ]]
    then
        testSha=$sha
        commitCounts=$(( $commitCounts + 1 ))
        mark=''
    else
        mark="$mark +"
    fi
    
    printf "%s\t%s\t%s %s\n" "$testDate" "$sourceDate" "$testSha" "$mark"
    printf "# test date:%s source date:%s\n" "$testDate" "$sourceDate" >> ${targetFile}
    printf "#SHA=%s\n\n" "$testSha" >> ${targetFile}
    
    sourceDate="$testDate"
    testDate=$( date -I -d "$sourceDate + 1 day")
    dayCount=$(( $dayCount + 1 ))
done

printf "day counts:%d, commit counts: %d\n" $dayCount $commitCounts

testDate=$( date -I -d "$firstDate + 6 days" )
sha=$( GetCommitSha "$testDate" )

printf "test date %s, sha: %s\n" "$testDate" "$sha"

popd

