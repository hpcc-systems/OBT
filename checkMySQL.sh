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

BUILD_HOME=~/build/CE/platform/build
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
MYSQL_CHECK_LOG_FILE=${OBT_LOG_DIR}/checkMySQL-${LONG_DATE}.log

GOOD_GRANT_RESULT="Grants for rchapman@localhost
GRANT USAGE ON *.* TO 'rchapman'@'localhost'
GRANT ALL PRIVILEGES ON \`test\`.* TO 'rchapman'@'localhost' WITH GRANT OPTION"

tryCount=2

#
#------------------------------
#
# Check the state of MySQl Server
#

WriteLog "Start MySQL Server check" "${MYSQL_CHECK_LOG_FILE}"

if [[ ( -f /etc/init.d/mysqld ) || (-f /usr/sbin/mysqld) ]]
then

    while [[ $tryCount -ne 0 ]]
    do
        WriteLog "Try count: ${tryCount}" "${MYSQL_CHECK_LOG_FILE}"
        mysqlstate=$( sudo service mysqld status | grep 'running')
        if [[ -z $mysqlstate  ]]
        then
            WriteLog "Stoped! Start it!" "${MYSQL_CHECK_LOG_FILE}"
            ${SUDO} service mysqld start
            sleep 5
            tryCount=$(( $tryCount-1 ))
            continue
        else
            WriteLog "It is OK!" "${MYSQL_CHECK_LOG_FILE}"

            # Check grants
            grant=$( mysql -uroot -e "SHOW GRANTS FOR rchapman@localhost;" 2>&1 )
            if [[ "$grant" == "$GOOD_GRANT_RESULT" ]]
            then 
                WriteLog "Privileges are ok." "${MYSQL_CHECK_LOG_FILE}"
                break
            else
                WriteLog "Missing MySQL privileges!" "${MYSQL_CHECK_LOG_FILE}"
                WriteLog "Expected:\n${GOOD_GRANT_RESULT}\n" "${MYSQL_CHECK_LOG_FILE}"
                WriteLog "Result of query:\n${grant}\n" "${MYSQL_CHECK_LOG_FILE}"


                # Add user and set its grants (under development)

                # Now send an email to Agyi about missing privileges
                echo "Missing privileges in MySQL" | mailx -s "Problem with MySQL" -u "$USER" "attila.vamos@gmail.com"
            fi
        fi
    done
    if [[ $tryCount -eq 0 ]]
    then
        WriteLog "MySQL won't start! Give up and send Email to Agyi!" "${MYSQL_CHECK_LOG_FILE}"
        # send email to Agyi
        echo "MySQL won't start!" | mailx -s "Problem with MySQL" -u $USER  ${ADMIN_EMAIL_ADDRESS}
    fi
else
    WriteLog "MySQL not installed in this sysytem! Send Email to Agyi!" "${MYSQL_CHECK_LOG_FILE}"
    # send email to Agyi
    echo "MySQL not installed in this sysytem!" | mailx -s "Problem with MySQL" -u $USER  ${ADMIN_EMAIL_ADDRESS}
fi

WriteLog "End." "${MYSQL_CHECK_LOG_FILE}"
