TODAY="$(date +%Y.%m.%d)"

IFS=$'\n'

fs=$( find ~/OBT-*/ -name 'OBT-*' -type f -print )
for f in ${fs[@]}
do
    echo "$f"
    lines=$( echo " $(tail -n 10 $f | grep -E '^'${TODAY} )" )
    for line in ${lines[@]}
    do
        echo "line:$line"
        b=$( echo "$line" | cut  -f 1,3 )
    done

done

unset IFS

