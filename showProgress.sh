clear

while ( true ); do echo $(date); if [[ -f /tmp/build.log ]]; then break; fi; sleep 10; done; tail -n200 --retry --max-unchanged-stats=500 -F /tmp/build.log

