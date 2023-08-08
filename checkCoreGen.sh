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

LOG_DIR=.
LONG_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
CRASH_TEST_LOG_FILE=${LOG_DIR}/Core-gen-test-${LONG_DATE}.log

CPP_SOURCE_NAME=mycrash.cpp
CPP_BIN_NAME=mycrash

ECL_SOURCE_NAME=ecl/mycrash.ecl

#
#-----------------------------------------
#
# Functions

CreateMyCrashCpp()
{
    WriteLog "Create $CPP_SOURCE_NAME source file..." "${CRASH_TEST_LOG_FILE}"
    
    echo '#include "stdio.h"'               >  $CPP_SOURCE_NAME
    echo 'int main(int argc, char* argv[])' >> $CPP_SOURCE_NAME
    echo '{'                                >> $CPP_SOURCE_NAME
    echo '  int *p;'                        >> $CPP_SOURCE_NAME
    echo '  *p = 0;'                        >> $CPP_SOURCE_NAME
    echo '  return 0;'                      >> $CPP_SOURCE_NAME
    echo '}'                                >> $CPP_SOURCE_NAME
    
    WriteLog "Done." "${CRASH_TEST_LOG_FILE}"
}

CreateMyCrashEcl()
{
    WriteLog "Create $ECL_SOURCE_NAME source file..." "${CRASH_TEST_LOG_FILE}"

    [[ ! -d ecl ]] && mkdir ecl
    
    echo 'boolean seg() := beginc++ #option action' >  $ECL_SOURCE_NAME
    echo '    #include <csignal>'                   >> $ECL_SOURCE_NAME
    echo '    #include <csignal>'                   >> $ECL_SOURCE_NAME
    echo '    #body'                                >> $ECL_SOURCE_NAME
    echo '    raise(SIGABRT);'                      >> $ECL_SOURCE_NAME
    echo '    return false;'                        >> $ECL_SOURCE_NAME
    echo 'endc++;'                                  >> $ECL_SOURCE_NAME
    echo 'output(seg());'                           >> $ECL_SOURCE_NAME
    
    WriteLog "Done." "${CRASH_TEST_LOG_FILE}"
}


BuildMyCrashBin()
{
    WriteLog "Build $CPP_BIN_NAME ..." "${CRASH_TEST_LOG_FILE}"
    res=$( c++ $CPP_SOURCE_NAME -o $CPP_BIN_NAME 2>&1)
    if [[ $? -ne 0 ]]
    then
        WriteLog "Build $CPP_BIN_NAME resturns with ${res}!" "${CRASH_TEST_LOG_FILE}"
    else
        WriteLog "Build $CPP_BIN_NAME test finished!" "${CRASH_TEST_LOG_FILE}"
    fi
}

#
#-----------------------------------------
#
# Main start

WriteLog "Core generation test started." "${CRASH_TEST_LOG_FILE}"

#
WriteLog "Current core generation is: $(cat /proc/sys/kernel/core_pattern)" "${CRASH_TEST_LOG_FILE}"

# would cause all future core dumps to be generated in same directory as the binary 
# and be named core_[program].[pid]

WriteLog "Forceing standard core to be generated in same directory" "${CRASH_TEST_LOG_FILE}"
res=$(echo 'core_%e.%p' | sudo tee /proc/sys/kernel/core_pattern)
WriteLog "res:${res}" "${CRASH_TEST_LOG_FILE}"

res=$(sudo service abrtd reload)
WriteLog "res:${res}" "${CRASH_TEST_LOG_FILE}"



if [ "$1." == "." ]
then

    if [ ! -f $CPP_BIN_NAME ]
    then
        WriteLog "There is not $CPP_BIN_NAME binary file." "${CRASH_TEST_LOG_FILE}"
    
        if [ ! -f $CPP_SOURCE_NAME ]
        then
            WriteLog "There is not $CPP_SOURCE_NAME source file." "${CRASH_TEST_LOG_FILE}"
            CreateMyCrashCpp   
        fi
   
        BuildMyCrashBin
    fi

    if [ -f $CPP_BIN_NAME ]
    then
        chmod +x ./$CPP_BIN_NAME

        WriteLog "Execute ${CPP_BIN_NAME} to create core dump!" "${CRASH_TEST_LOG_FILE}"
        res=$( ./${CPP_BIN_NAME} 2>&1 )
        WriteLog "res: $?." "${CRASH_TEST_LOG_FILE}"
            
        cores=( $( find . -maxdepth 1 -name 'core*' -type f ) )
        if [ ${#cores[@]} -ne 0 ]
        then
            WriteLog "There is/are ${#cores[@]} core file(s) '${cores[*]}'" "${CRASH_TEST_LOG_FILE}"
            WriteLog "Core generation is OK!" "${CRASH_TEST_LOG_FILE}"
            WriteLog "Clean up." "${CRASH_TEST_LOG_FILE}"
            rm -f ${cores[*]}
            rm -f ${CPP_SOURCE_NAME}
        else
            WriteLog "Core generation disabled!" "${CRASH_TEST_LOG_FILE}"
        fi
    fi
else
    
    if [ ! -f $ECL_SOURCE_NAME ]
    then
        WriteLog "There is not $ECL_SOURCE_NAME source file." "${CRASH_TEST_LOG_FILE}"
        CreateMyCrashEcl
    fi

    WriteLog "Execute ${ECL_SOURCE_NAME} on hthor to create core dump!" "${CRASH_TEST_LOG_FILE}"

    res=$( ecl run -t hthor ./${ECL_SOURCE_NAME} 2>&1 )
    WriteLog "res: $?." "${CRASH_TEST_LOG_FILE}"

    WriteLog "Execute ${ECL_SOURCE_NAME} on thor to create core dump!" "${CRASH_TEST_LOG_FILE}"
    res=$( ecl run -t thor ./${ECL_SOURCE_NAME} 2>&1 )
    WriteLog "res: $?." "${CRASH_TEST_LOG_FILE}"

    # Somehow this execution on Roxie takes ages to finish. Should investigate.
    #WriteLog "Execute ${ECL_SOURCE_NAME} on roxie to create core dump!" "${CRASH_TEST_LOG_FILE}"
    #res=$( ecl run -t roxie ./${ECL_SOURCE_NAME} 2>&1 )
    #WriteLog "res: $?." "${CRASH_TEST_LOG_FILE}"

            
    cores=( $( find /var/lib/HPCCSystems/ -name 'core_*' -type f ) )

    if [ ${#cores[@]} -ne 0 ]
    then
        WriteLog "There is/are ${#cores[@]} core file(s) '${cores[*]}'" "${CRASH_TEST_LOG_FILE}"
        if [ ${#cores[@]} -eq 2 ]
        then
            WriteLog "Core generation is OK!" "${CRASH_TEST_LOG_FILE}"
        else
            WriteLog "Core generation failed on some platform(s)!" "${CRASH_TEST_LOG_FILE}"
        fi
        WriteLog "Clean up." "${CRASH_TEST_LOG_FILE}"
        ${SUDO} rm -f ${cores[*]}
        rm eclcc.log
    else
        WriteLog "Core generation disabled!" "${CRASH_TEST_LOG_FILE}"
    fi
fi

WriteLog "End." "${CRASH_TEST_LOG_FILE}"        
