#!/usr/bin/env python3

import sys
import subprocess
import time
import signal
import atexit
import warnings
from optparse import OptionParser

with warnings.catch_warnings():
    warnings.filterwarnings("ignore",category=DeprecationWarning)
  
process='myrun*'
delayInSec=10
timeoutInSec=40
maxSelfRuntimeInSec=300 
verbose = False

def myPrint(str):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(timestamp+": " + str)
    
def myPrintV(str):
    if verbose:
        myPrint(str)

#
#
#----------------------------------------------------------------
# Signal handling
#

def handler(signum, frame=None):
    msg = "Signal handler called with " + str(signum)

    if signum == signal.SIGALRM:
        msg +=", SIGALRM"

    elif signum == signal.SIGTERM:
        msg += ", SIGTERM"

    elif signum == signal.SIGKILL:
        msg +=", SIGKILL"

    elif signum == signal.SIGINT:
        msg += ", SIGINT (Ctrl+C)"

    else:
        msg += ", ?"

    # If there are some registered process then handle them before exit.
    handleProcess(2)

    if signum != signal.SIGKILL:
        print(msg)
        print("Interrupted at " + time.asctime())
        
    print("-------------------------------------------------\n")
    exit()

def on_exit(sig=None, func=None):
    try:
        handler(signal.SIGKILL)
    except SystemExit:
        pass
    
def getResult(myProc):
    (myStdout,  myStderr) = myProc.communicate()
    return myStdout.decode('utf-8') + myStderr.decode('utf-8')

def handleProcess(maxLoop):
    i = 1
    while (i < maxLoop) or (len(items[process]) > 0):
        # Clear the 'updated' flag to see which process is still alive
        for pid in items[process]:
            items[process][pid]['updated'] = False
        
        # Get the pids of live processes filetered bu the content of process variable
        myProc = subprocess.Popen([psCmd],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
        mypid = myProc.pid
        result = getResult(myProc)
        myPrintV('My pid is: ' + str(mypid))
        myPrintV("Result: ")
        
        # Add/update process live timer
        for line in result.split('\n'):
            line = line.replace('\n','').replace('./','').replace('\t', ' ').replace('  ',  ' ')
            myPrintV("line: "+line+" ("+str(len(line))+")")
            if len(line) == 0:
                continue
            if selfName in line:
                continue
            items2 = line.split()
            pid = items2[0]
            name = ' '.join(items2[4:])
            myPrintV("pid: "+str(pid)+", name: "+str(name) + ", len(items2): " + str(len(items2)))
            
            if pid in items[process]:
                items[process][pid]['time'] += delayInSec
                items[process][pid]['updated'] = True
            else:
                items[process][pid] = {'time': 0 ,  'updated' : True,  'name': name}
                myPrint("New process "+ name + "("+pid + ") added into the watch list.")
        pass
        
        # Check which process finished or which is runs timeout
        removePids = []
        killProcess = set()
        for pid in items[process]:
            if (not items[process][pid]['updated']):
                removePids.append(pid)
            if  (items[process][pid]['time'] > timeoutInSec):
                removePids.append(pid)
                killProcess.add(pid)
                
        # remove finished process(es)
        for pid in removePids:
            name = items[process][pid]['name']
            del  items[process][pid]
            
            # Kill timeouted process(es)
            if pid in killProcess:
                # Kill process
                killCmd = 'sudo kill -9 ' + pid
                myPrintV("Kill cmd:"+killCmd)
                myProc = subprocess.Popen([killCmd],  shell=True,  bufsize=8192, stdin=subprocess.PIPE, stdout=subprocess.PIPE,  stderr=subprocess.PIPE)
                result = getResult(myProc)
                myPrint("Still active "+ name + "("+ pid + ") is ran out of time and killed.")
            else:
                myPrint("Watched process" + name + "("+pid + ") finished and removed from the list.")
                
        myPrintV("Loop:" + str(i))
        myPrintV("number of items:"+ str(len(items[process])))
        time.sleep(delayInSec)
        i += 1
  
#
#
#----------------------------------------------------------------
# 
# 

usage = "usage: %prog [options]"
parser = OptionParser(usage=usage)
parser.add_option("-p", "--process", dest="process",  default = None,  type="string", 
                  help="Name of process to watch (can contains '*').", metavar="PROCESS_NAME")
                  
parser.add_option("-d", "--delay", dest="delayInSec", default=delayInSec, type="int", 
                  help="Delay between two checks. Default is " + str(delayInSec) + " sec"
                  , metavar="DELAY_IN_SEC")
                  
parser.add_option("-t", "--timeout", dest="timeoutInSec", default=timeoutInSec, type="int", 
                  help="Timeout before kill the process. Default is " + str(timeoutInSec) + " sec"
                  , metavar="TIMEOUT_IN_SEC")
                  
parser.add_option("-r", "--selfruntime", dest="maxSelfRuntimeInSec", default=maxSelfRuntimeInSec, type="int", 
                  help="Maximum self running time. Default is "+str(maxSelfRuntimeInSec)+" sec"
                  , metavar="MAX_SELF_RUNTIME_IN_SEC")

parser.add_option("-v", "--verbose", dest="verbose", default=False, action="store_true", 
                      help="Show more info. Default is False"
                      , metavar="VERBOSE")
                  
(options, args) = parser.parse_args()

if options.process != None:
    process = options.process.strip('\'')
else:
    parser.print_help()
    exit()
    

myPrint("Register signal handler for SIGALRM, SIGTERM, SIGINT")
signal.signal(signal.SIGALRM, handler)
signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)

atexit.register(on_exit)
    
delayInSec =options.delayInSec
timeoutInSec=options.timeoutInSec
maxSelfRuntimeInSec=options.maxSelfRuntimeInSec 
maxLoop = maxSelfRuntimeInSec/delayInSec
verbose = options.verbose

myPrint("App name:" + sys.argv[0])

selfName = sys.argv[0][2:]

myPrint("selfName: " + selfName)
myPrint("Process: " + str(process))
myPrint("Wait between two checks is: " + str(delayInSec) + " sec.")
myPrint("Timeout before kill a process is: " + str(timeoutInSec) + " sec.")
myPrint("Max self runtime is: " +str(maxSelfRuntimeInSec)+" sec.")
myPrint("Verbose is :" +str(verbose))

pass

items = {}
items[process] = {}

psCmd = "ps ax | grep '["+process[0]+"]"+process[1:]+"'"

myPrintV("psCmd: " + psCmd)

handleProcess(maxLoop)    
while len(items[process]) > 0:
    maxLoop = maxSelfRuntimeInSec/delayInSec
    myPrint("There is/are running process(es) to watch, restart handleProcess().")
    handleProcess(maxLoop)

myPrint("End.")
