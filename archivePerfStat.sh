#!/bin/bash

echo "Start..."

YEAR=$(date "+%Y")

echo "Add all new/changed perfstat-* files to PerfstatArchive-$YEAR.zip."
zip -u ./PerfstatArchive$YEAR.zip perfstat-*
echo "Done"

echo ""
achieveOlderThan=181
toBeRemove="$(find . -mtime +$achieveOlderThan -name 'perfstat*' -type f -print )"
numToBeRemove=$(find . -mtime +$achieveOlderThan -name 'perfstat*' -type f -print | wc -l)

if [[ $numToBeRemove -gt 0 ]]
then
    echo "Remove $numToBeRemove perfstat-* files older than $achieveOlderThan days."
    echo "$toBeRemove"

    find . -mtime +$achieveOlderThan -name 'perfstat*' -type f -exec rm '{}' \;

else

    echo "There is not perfstat-* files older than $achieveOlderThan days to be remove."

fi

echo "End."