#!/usr/bin/env python3

import smtplib
import re
import os
from datetime import datetime
from optparse import OptionParser
import configparser
import glob
import socket
import inspect
import traceback
import sys

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

try:
    from RegressionLogProcessor.regressionLogProcessor import RegressionLogProcessor
except ImportError:
    print("Reparable import error...")
    try:
        from regressionLogProcessor import RegressionLogProcessor
    except ImportError:
        print("Unreparable import error ...")
        RegressionLogProcessor = None
finally:
    print(RegressionLogProcessor)
    pass

debug=False
# TODO  
# - Check dead code

class SpanMaker():
    @classmethod
    def makeSpan(cls, color, result):
        return "<span style=\"color:" + color + "\">" + result + "</span><br>\n"

class BuildNotificationConfig( object ):

    def __init__(self, options, iniFile = 'BuildNotification.ini'):
        self._buildDate = options.dateString 
        self.config = configparser.ConfigParser()
        self._buildTime = options.timeString
        global debug
        debug = options.debug

        self.today = datetime.today()
        if not self.buildDate:
            self._buildDate =  self.today.strftime("%Y-%m-%d")

        if not self._buildTime:
            self._buildTime =  self.today.strftime("%H:%M:%S")
            self._buildTimeAsPathMemeber = self.today.strftime("%H-%M-%S")
        else:
            if re.match("[0-9][0-9]-[0-9][0-9]-[0-9][0-9]", self._buildTime):
                self._buildTimeAsPathMemeber = self._buildTime
                self._buildTime = self._buildTime.replace('-', ':')
            elif re.match("[0-9][0-9]:[0-9][0-9]:[0-9][0-9]", self._buildTime):
                self._buildTimeAsPathMemeber = self._buildTime.replace(':', '-')
            else:
                print("Unrecognised time format. Ignored and use current time")
                self._buildTime =  self.today.strftime("%H:%M:%S")
                self._buildTimeAsPathMemeber = self.today.strftime("%H-%M-%S")

        self.config.read( iniFile )
        pass

    def get( self, section, key ):
        retVal = None
        try:
            retVal = self.config.get( section, key )
        except:
            retVal = "Missing value(section: %s, key: %s)" % (section,  key)

        return retVal

    @property
    def buildDate( self ):
        return self._buildDate

    @property
    def buildTime( self ):
        return self._buildTime
        
    @property
    def buildTimeAsPathMemeber( self ):
        return self._buildTimeAsPathMemeber      

    @property
    def reportDirectory( self ):
        return  "{buildDate}/{buildSystem}/{buildTime}/{buildDirectory}".format(
                    buildDate = self.buildDate,
                    buildSystem = self.get( 'OBT', 'ObtSystem' ) + '-' + self.get( 'Build', 'BuildSystem' ),
                    buildTime = self.buildTimeAsPathMemeber, 
                    buildDirectory = self.get( 'Build', 'BuildDirectory' ))

    @property
    def reportDirectoryURL( self ):
        return  "{urlBase}/{buildBranch}/{reportDirectory}".format(
                    urlBase=self.get( 'Build', 'urlBase' ),
                    buildBranch=self.get('Build', 'BuildBranch' ),
                    reportDirectory=self.reportDirectory )

    @property
    def archiveDirectoryURL( self ):
        return  "{urlBase}".format(
                    urlBase=self.get( 'Build', 'urlBase' ))

    @property
    def reportDirectoryFileSystem( self ):
        return  "{shareBase}/{buildBranch}/{reportDirectory}".format(
                    shareBase=self.get( 'Build', 'shareBase' ),
                    buildBranch=self.get('Build', 'BuildBranch' ),
                    reportDirectory=self.reportDirectory )

    @property
    def reportObtSystem( self ):
        return  "{obtSystem}".format(
                    obtSystem=self.get( 'OBT', 'ObtSystem'))

    @property
    def reportObtSystemEnv(self):                
        return "{ObtSystemEnv}".format(
                ObtSystemEnv = self.config.get('OBT', 'ObtSystemEnv'))
                
    @property
    def buildType(self):
        return "{buildType}".format(
                    buildType=self.get( 'Build', 'BuildType'))

    @property
    def thorSlaves(self):
        return "{thorSlaves}".format(
                    thorSlaves=self.get( 'Build', 'ThorSlaves'))

    @property
    def thorChannelsPerSlave(self):
        return "{thorChannelsPerSlave}".format(
                    thorChannelsPerSlave=self.get( 'Build', 'ThorChannelsPerSlave'))

    
    @property
    def buildSystem(self):                
        return "{buildSystem}".format(
                self.config.get('Build', 'BuildSystem'))
                
    @property
    def hostAddress(self):
        try:
            hostAddress = socket.gethostbyname(socket.gethostname())
        except:
            # Something wrong with OBT-18 machine network settings
            if 'hpcc-platform-dev-el5-dailybuild1.novalocal' in socket.gethostname():
                try:
                    hostAddress = socket.gethostbyname('centos-6-4-daily')
                except:
                    hostAddress = '10.240.34.18'
            else:
                hostAddress = "127.0.0.1 (Error in IP query)"

        return hostAddress

class Task( object ):

    def __init__( self, name, config ):
        self._name = name
        self.config = config
        self._status = 'FAILED'
        self._result = ''
        self._gitBranch = 'master'
        self._logFileName = self.getLogFileName()
        self._gitBranchName = self._gitBranch
        self._gitBranchDate = ''
        self._gitBranchCommit = ''
        self._gitBranchNumOfCommits = 0
        self._globalExclusion = ''
        self._globalExclusions = {}
        self._errorMsg = ''
        self._total = 0
        self._passed = 0
        self._failed = 0
        self._error = 0
        self._timeout = 0
        self._failedSubtask = []
        self._elapsTime = []
   
    def getLogFileName( self ):
        return "Unimplementated"

    @property
    def name( self ):
        return self._name

    @property
    def status( self ):
        return self._status

    @property
    def result( self ):
        return self._result

    @property
    def gitBranch( self ):
        return self._gitBranch

    @property
    def gitBranchName( self ):
        return self._gitBranchName

    @property
    def gitBranchDate( self ):
        return self._gitBranchDate

    @property
    def gitBranchCommit( self ):
        return self._gitBranchCommit

    @property
    def gitBranchCommitHtml( self ):
        return '<b>' + self._gitBranchCommit[0:8].upper() + '</b> (' + self._gitBranchCommit[8:]+')'

    @property
    def gitBranchNumOfCommits( self ):
        return self._gitBranchNumOfCommits
        
    @property
    def logFileName( self ):
        if not self._logFileName:
            self._logFileName = self.getLogFileName()

        return self._logFileName

    @property
    def globalExclusion( self ):
        return self._globalExclusion

    @property
    def globalExclusions( self ):
        return self._globalExclusions

    @property
    def errorMsg(self):
        return self._errorMsg
        
    @property
    def total(self):
        return ("%d" % (self._total))
    
    @property
    def passed(self):
        return ("%d" % (self._passed))
        
    @property
    def failed(self):
        return ("%d" % (self._failed))
        
    @property
    def error(self):
        return ("%d" % (self._error))
        
    @property
    def timeout(self):
        return ("%d" % (self._timeout))
     
    @property
    def problems(self):
        return ("%d" % ( self._total - self._passed ))
        
    @property
    def failedSubtask(self):
        return self._failedSubtask

    @property
    def elapsTime(self):
        return self._elapsTime
        
class BuildTask( Task ):    

    def getLogFileName( self ):
        return self.config.get( 'Build', 'BuildLog' )
     
    @property
    def logFileURL( self ):
        return "{reportDirectoryURL}/{logFile}".format(
                    reportDirectoryURL=self.config.reportDirectoryURL,
                    logFile=self.logFileName)

    @property
    def gitLogFileURL( self ):
        return "{reportDirectoryURL}/git_2days.log".format(
                    reportDirectoryURL=self.config.reportDirectoryURL)
                 

    @property
    def logFileFileSystem( self ):
        return "{reportDirectoryFileSystem}/{logFile}".format(
                    reportDirectoryFileSystem=self.config.reportDirectoryFileSystem,
                    logFile=self.config.get( 'Build', 'BuildLog' ))

    @property
    def gitLogFileSystem( self ):
        return "{reportDirectoryFileSystem}/git_2days.log".format(
                    reportDirectoryFileSystem=self.config.reportDirectoryFileSystem)

    @property
    def exclusionLogFileFileSystem( self ):
        return "{reportDirectoryFileSystem}/{logFile}".format(
                    reportDirectoryFileSystem=self.config.reportDirectoryFileSystem,
                    logFile=self.config.get( 'Build', 'GlobalExclusionLog' ))


    def processResult( self ):
        self._status = self._result = 'FAILED'
        print("Build log: " + self.logFileFileSystem)
        if not os.path.exists( self.logFileFileSystem ): 
            self._status = self._result = 'UNAVAILABLE'
            return
        
        logLines = open( self.logFileFileSystem ).readlines()

        i = 8
        result = re.compile('\s*Build succeed\s*$')
        elaps = re.compile('\s*Elaps:(.*)$')
        cmake = re.compile('\s*CMake:(.*)$')
        build = re.compile('\s*Build:(.*)$')
        package = re.compile('\s*Package:(.*)$')
        for line in reversed(logLines):
            m = result.match( line )
            if m:
                self._status = self._result = 'PASSED'
                continue 
                
            m = elaps.match( line )
            if m:
                self._elapsTime.append("Altogether:" + m.group(1))
                continue 
                
            m = cmake.match( line )
            if m:
                self._elapsTime.append(line)
                continue 
                
            m = build.match( line )
            if m:
                self._elapsTime.append(line)
                continue 
                
            m = package.match( line )
            if m:
                self._elapsTime.append(line)
                continue 
          
            i -= 1

            if i == 0: break 
            
        # The build.log processed from back, therefore all ties are
        # in reverse order, Restore the original sequence
        self._elapsTime.reverse()
        
        if self._result == 'FAILED':
            errline = re.compile('\s([Ee]rror[:]*|[Ff]ailed|!checking|http[s]?:)\s.*$')
            for line in logLines:
                line = line.rstrip()
                m = errline.search( line )
                if m and ('/docs/' not in line):
                    self._errorMsg += line +'<br>\n'
                    self._total += 1

        p_branch = re.compile('\s*git branch:\s*(.*)\s*$')
        p_date   = re.compile('\s*Date:\s*(.*)$')
        p_commit = re.compile('\s*commit\s*(.*)$')
        p_numOfCommits = re.compile('\s*numberOfCommitsInLast24Hours:\s*(.*)$')
        self._gitBranch = ''
        self._gitBranchName = 'Missing'
        gitBranchInfo = ''
        self._gitBranchDate = ''
        self._gitBranchCommit = ''
        self._gitBranchNumOfCommits = 0
        line = ''
        try:
            gitLog =  open( self.gitLogFileSystem )
            for line in gitLog.readlines( ):
                m = p_branch.match( line )
                if m:
                    self._gitBranchName = m.group(1).strip()
                    continue 

                m = p_date.match( line )
                if m:
                    self._gitBranchDate = m.group(1) 
                    continue

                m = p_commit.match( line )
                if m:
                    self._gitBranchCommit = m.group(1)
                    continue
                
                m = p_numOfCommits.match( line )
                if m:
                    try:
                        self._gitBranchNumOfCommits = int(m.group(1))
                    except Exception as e:
                        print("Something wrong with git branch number of commits '%s'" % (m.group(1)) )
                        print(e)
                        pass
                    
                    continue
        except:
            print("Exception in git log file processing:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            print("line: %s" % (line))
            print("Exception in user code:")
            print('-'*60)
            traceback.print_exc(file=sys.stdout)
            print('-'*60)

        if self._gitBranchDate != '':
            self._gitBranchDate = self._gitBranchDate.replace(' +0000','').strip() 
            gitBranchInfo += self._gitBranchDate

        if self._gitBranchCommit != '':
            if gitBranchInfo != '':
                gitBranchInfo += ', '

            gitBranchInfo +=  'sha:'+self._gitBranchCommit

        self._gitBranch += self._gitBranchName +' (' + gitBranchInfo + ')'

        if os.path.exists( self.exclusionLogFileFileSystem):
            p_regressExcl = re.compile('\s*Regression:\s*(.*)$')
            p_buildExcl = re.compile('\s*Build:\s*(.*)$')
            p_docsExcl = re.compile('\s*Documentation:\s*(.*)$')
            p_unitTestExcl = re.compile('\s*Unittests:\s*(.*)$')
            p_mlTestExcl = re.compile('\s*MLtests:\s*(.*)$')

            print("Global exclusion:")
            for line in open( self.exclusionLogFileFileSystem).readlines( ):
                print("\t%s" % (line.strip()))
                m = p_regressExcl.match( line )
                if m:
                    globalExclusion = m.group(1).replace('--ef','').replace(',',', ').replace('-e','')
                    if len(globalExclusion) != 0:
                        if len(self._globalExclusion) > 0:
                            self._globalExclusion += ', '
                        self._globalExclusion += globalExclusion
                        if 'Regression' not in self._globalExclusions:
                            self._globalExclusions['Regression'] = ''

                        self._globalExclusions['Regression'] += re.sub("\s\s+", " ", globalExclusion)
                        
                m = p_unitTestExcl.match( line )
                if m:
                    globalExclusion = m.group(1).replace('(','').replace(')','').strip(' ').replace(' ', ', ')                    
                    if len(globalExclusion) != 0:
                        if len(self._globalExclusion) > 0:
                            self._globalExclusion += ', '
                        self._globalExclusion += globalExclusion
                        if 'Unittest' not in self._globalExclusions:
                            self._globalExclusions['Unittest'] = ''

                        self._globalExclusions['Unittest'] += re.sub("\s\s+", " ", globalExclusion)
                        
                m = p_buildExcl.match( line )
                if m:
                    globalExclusion = m.group(1).replace('-DSUPPRESS_','').replace(':BOOL','').replace('=ON', '').strip().replace(' ', ', ')
                    if len(globalExclusion) != 0:
                        if len(self._globalExclusion) > 0:
                            self._globalExclusion += ', '
                        self._globalExclusion += globalExclusion
                        if 'Build' not in self._globalExclusions:
                            self._globalExclusions['Build'] = ''

                        self._globalExclusions['Build'] += re.sub("\s\s+", " ", globalExclusion)

                m = p_docsExcl.match( line )
                if m:
                    docExclusion = m.group(1)
                    if 'No' in docExclusion:
                        if len(self._globalExclusion) > 0:
                            self._globalExclusion += ', '
                        self._globalExclusion += 'Documentation'
                        
                        if 'Documentation' not in self._globalExclusions:
                            self._globalExclusions['Documentation'] = ''

                        self._globalExclusions['Documentation'] += 'not built'

                m = p_mlTestExcl.match(line)
                if m:
                    globalExclusion = m.group(1).replace('--ef','').replace(',',', ').replace('-e','').strip()
                    if len(globalExclusion) != 0:
                        if len(self._globalExclusion) > 0:
                            self._globalExclusion += ', '
                        self._globalExclusion += globalExclusion
                        if 'MLtest' not in self._globalExclusions:
                            self._globalExclusions['MLtest'] = ''

                        self._globalExclusions['MLtest'] += re.sub("\s\s+", " ", globalExclusion)

        if self._globalExclusion == '':
                self._globalExclusion = '(None)'


class TestTask( Task ):    

    @property
    def logFileDirectory( self ):
        return "{reportDirectoryFileSystem}/test".format(
                    reportDirectoryFileSystem=self.config.reportDirectoryFileSystem )

    def getLogFileName( self ):    
        nameInLower = self.name.lower()
        logFile = ""
        if ('unittest' in nameInLower) or ('wutooltest' in nameInLower):
            if os.path.exists( self.logFileDirectory + "/" + nameInLower + ".summary" ): 
                logFile = nameInLower + ".summary"
                return logFile
        if os.path.exists( self.logFileDirectory + "/" + nameInLower + ".log" ): 
            logFile = nameInLower + ".log"
        else:
            curDir = os.getcwd()

            os.chdir( self.logFileDirectory )
            files = glob.glob( nameInLower + \
                    ".[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9].log" )
            if files: 
                sortedFiles = sorted( files, key=str.lower, reverse=True )
                logFile = sortedFiles[0]
            else:
                files = glob.glob( nameInLower + ".summary")
                if files: 
                    sortedFiles = sorted( files, key=str.lower, reverse=True )
                    logFile = sortedFiles[0]
                    
            os.chdir( curDir )

        return logFile


    @property
    def logFileURL( self ):
        return "{reportDirectoryURL}/test/{logFile}".format(
                    reportDirectoryURL=self.config.reportDirectoryURL,
                    logFile=self.getLogFileName())
                 

    @property
    def logFileFileSystem( self ):
        return "{reportDirectoryFileSystem}/{logFile}".format(
                    reportDirectoryFileSystem=self.logFileDirectory,
                    logFile=self.getLogFileName( ))

    @property
    def summaryFile( self ):
        nameInLower = self._name.lower()
        return "{reportDirectoryFileSystem}/test/{name}.summary".format(
                    reportDirectoryFileSystem=self.config.reportDirectoryFileSystem,
                    name=nameInLower )

    def processResult( self ):
        if not os.path.exists( self.summaryFile ): 
            self._status = self._result = 'UNKNOWN'
            return
       
        p = re.compile('\s*TestResult:(.*)\s*$')
        p1 = re.compile('(.*otal:.*)\s*$')
        p2 = re.compile('.*otal:([0-9]+)\s*passed:([0-9]+)\s*failed:([0-9]+)\s*elaps[e]?[d]?:(.*)$')
        p2b = re.compile('^(.*)\:.*otal:([0-9]+)\s*passed:([0-9]+)\s*failed:([0-9]+)\s*elaps[e]?[d]?:(.*)$')

        p3b = re.compile('.*otal:([0-9]+)\s*passed:([0-9]+)\s*failed:([0-9]+)\s*errors:([0-9]+)\s*timeout:([0-9]+)\s*elaps:(.*)$')

        lines = open( self.summaryFile ).readlines()
        if 'Setup' == self._name:
            line = lines[0]
            lines = line.split(',')
            
        for line in lines:
            line = line.strip()
            if len(line) == 0 :
                continue
            m = p.match( line )
            if m == None:
                m = p1.match( line )
            if m:
                res = m.group(1)
                if 'wutool' in res:
                    res = res.replace('wutoolTest(','').replace('):', '  ')
                    if self._failed == 0:
                        self._status = 'PASSED'

                    m2 = p3b.match( res )
                    if m2:
                        try:
                            res = res.replace("elaps:" + m2.group(6), '')
                            self._elapsTime.append(m2.group(6))

                        except Exception as e:
                            print("Something wrong with wutool elaps: '%s'" % (res) )
                            print(e)
                            pass


                        if m2.group(1) !=  m2.group(2):
                            self._result += SpanMaker.makeSpan("red", res)
                            self._status = 'FAILED'
                            self._errorMsg += res + "<br>\n"
                            self._total   = self._total + int(m2.group(1))
                            self._passed  = self._passed + int(m2.group(2))
                            self._failed  = self._failed + int(m2.group(3))
                            self._error   = self._error  + int(m2.group(4))
                            self._timeout = self._timeout + int(m2.group(5))
                        else:
                            self._result += SpanMaker.makeSpan("green", res)
                        
                elif 'unittest' in res:
                    res = res.replace('unittest:','')

                    self._status = 'PASSED'
                    m2 = p3b.match( res )

                    if m2:
                        try:
                            res = res.replace("elaps:" + m2.group(6), '')
                            self._elapsTime.append(m2.group(6))

                        except Exception as e:
                            print("Something wrong with unittest elaps: '%s'" % (res) )
                            print(e)
                            pass

                        if m2.group(1) !=  m2.group(2):
                            self._result = SpanMaker.makeSpan("red", res)
                            self._status = 'FAILED'
                            self._errorMsg += 'Unittests:<br>\n'
                            self._total   = int(m2.group(1))
                            self._passed  = int(m2.group(2))
                            self._failed  = int(m2.group(3))
                            self._error   = int(m2.group(4))
                            self._timeout = int(m2.group(5))
                        else:
                            self._result = SpanMaker.makeSpan("green", res)
                
                elif ('Setup' == self._name) or ('MLtests' == self._name):
                    if self._failed == 0:
                        self._status = 'PASSED'
                    m2 = p2b.match( res )
                    
                    if m2 :
                        try:
                          self._elapsTime.append(m2.group(5))
                          res = res.replace("elapsed:" + m2.group(5), '').replace("elaps:" + m2.group(5), '')

                        except Exception as e:
                            print("Something wrong with setup elaps: '%s'" % (res) )
                            print(e)
                            pass

                        if m2.group(2) != m2.group(3):
                            self._result += SpanMaker.makeSpan("red", res)
                            self._status  = 'FAILED'
                            self._total   = self._total  + int(m2.group(2))
                            self._passed  = self._passed + int(m2.group(3))
                            self._failed  = self._failed + int(m2.group(4))
                            self._failedSubtask.append(m2.group(1))
                        else:
                            self._result += SpanMaker.makeSpan("green", res)

                   
                else:
                    # It is an Hthor, Thor or Roxie regression result
                    self._status = 'PASSED'
                    m2 = p2.match( res )
                    if m2:

                        try:
                            self._elapsTime.append(m2.group(4))
                            res = res.replace( "elapsed:" + m2.group(4), '').replace( "elaps:" + m2.group(4), '')
                        except:
                            pass
        
                        if m2.group(1) != m2.group(2):
                            self._result += SpanMaker.makeSpan("red", res)
                            self._status = 'FAILED'
                            self._total = int(m2.group(1))
                            self._passed = int(m2.group(2))
                            self._failed = int(m2.group(3))
                        else:
                            self._result = SpanMaker.makeSpan("green", res)


            elif self._status == 'FAILED':
                self._errorMsg += line +'<br>\n'
        
        if len(self.errorMsg) > 0:
            self._status = 'FAILED'
        pass
       
class BuildNotification( object ):

    def __init__( self, config ):
        self.config = config 
        self.hasBuild = True
        self.summary = ''
        self.status = ''
        self.results = []
        self.tasks = [ 'Install', 'Unittests', 'Wutooltests', 'MLtests', 'Setup', 'Hthor', 'Thor', 'Roxie', 'Uninstall' ]
        self.msg = MIMEMultipart('alternative')
        self.msgHTML = ''
        self.msgText = ''
        self.logFiles=[]
        self.buildTaskIndex = 0
        self.errorMsg = ''
        self.testEngineErrMsg = ''
        self.buildErrorMsg = ''
        self.logReport = {}
           

    def appendWithDelimiter(self, target,  text,  delimiter = ', '):
        retVal = ''
        if len(target) > 0:
            retVal += delimiter 
            
        retVal += text
        return retVal
        
    def processResults( self ):
        buildTask = BuildTask( 'Build', self.config ) 
        self.results.append( buildTask )
        buildTask.processResult()
        self.status = 'PASSED'
        if buildTask.status == "PASSED":
            for taskName in self.tasks:
                task = TestTask( taskName, self.config ) 
                task.processResult()
                self.results.append( task )
                if task.status != "PASSED": self.status = 'PARTIAL'
        else: 
            self.summary = 'Build Failed'
            self.status = 'FAILED'
            self.buildErrorMsg = buildTask.errorMsg
          
        if debug:   
            for task in self.results:
                print( "\nName: " + task.name )
                print( "Status: " + task.status )
                print( "Result: " + task.result )
                print( "Log: " + task.logFileURL )

    def headRender( self ):

        self.msg['From'] = self.config.get( 'Email', 'Sender' )
        
        if self.results[self.buildTaskIndex].gitBranchNumOfCommits == 0:
            self.msg['To'] = self.config.get( 'Email', 'Receivers' ) 
        else:
            self.msg['To'] = self.config.get( 'Email', 'ReceiversWhenNewCommit' ) 

        print("Build Result " + self.status)
        print("From " + self.msg['From'])
        print("To " + self.msg['To'])
        self.msgHTML  = "<html>\n"
        self.msgHTML += "<head></head>\n"
        self.msgHTML += "<body>\n"
        self.msgHTML += "<H3>HPCC Community Platform Nightly Build Report:</H3>\n"
        self.msgHTML += "<table>\n" 
        self.msgHTML += "<tr><td>Build date:</td><td><b>" + self.config.buildDate + " @" + self.config.buildTime + "</b></td></tr>\n" 
        self.msgHTML += "<tr><td>Build system:</td><td>" + self.config.get('Build', 'BuildSystem') + "</td></tr>\n"
        self.msgHTML += "<tr><td>Hardware:</td><td>" + self.config.get('OBT', 'ObtSystemHw').replace('"', '') + "</td></tr>\n"
        self.msgHTML += "<tr><td>IP Address:</td><td>" + self.config.hostAddress + " (" + self.config.reportObtSystem + ")</td></tr>\n" 
        self.msgHTML += "<tr><td align=\"right\">Build on git branch:</td><td><b>" + self.results[self.buildTaskIndex].gitBranchName + "</b></td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">Date:</td><td>" + self.results[self.buildTaskIndex].gitBranchDate + "</td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">SHA:</td><td>" + self.results[self.buildTaskIndex].gitBranchCommitHtml + "</td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">Number of commits (24h):</td><td>" + ("%d" % self.results[self.buildTaskIndex].gitBranchNumOfCommits) + "</td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">Build type:</td><td><b>" + self.config.buildType + "</b></td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">Number of Thor slaves:</td><td><b>" + self.config.thorSlaves + "</b></td></tr>\n"
        self.msgHTML += "<tr><td align=\"right\">Number of channels per Thor slave:</td><td><b>" + self.config.thorChannelsPerSlave + "</b></td></tr>\n"

        self.msgHTML += "<tr><td align=\"right\">Exclusion:</td><td> </td></tr>\n"
        exclusionSequence = ['Build', 'Documentation', 'Unittest', 'MLtest', 'Regression' ]
        for exclusion in exclusionSequence:
            if exclusion in self.results[self.buildTaskIndex].globalExclusions:
                self.msgHTML += "<tr><td align=\"right\">" + exclusion + ":</td><td>" + self.results[self.buildTaskIndex].globalExclusions[exclusion] + "</td></tr>\n"
                
        self.msgHTML += "</table><br>\n"
        
        self.logReport['buildDate'] = self.config.buildDate.replace('-', '.')
        self.logReport['buildTime'] = self.config.buildTime
        self.logReport['gitBranchName'] = self.results[self.buildTaskIndex].gitBranchName.replace('candidate-', '')
        self.logReport['status'] = ''
        self.logReport['gitBranchDate']= self.results[self.buildTaskIndex].gitBranchDate
        self.logReport['gitBranchCommit'] = self.results[self.buildTaskIndex].gitBranchCommit[0:8].upper()
        self.logReport['buildType'] = self.config.buildType[0:1]
        self.logReport['reportObtSystem'] = self.config.reportObtSystem
        self.logReport['thorConfig'] = 'T: ' +  self.config.thorSlaves + 's/' + self.config.thorChannelsPerSlave + 'c'
        
        pass

    def endRender( self ):
        self.msgHTML += "</body>\n"
        self.msgHTML += "</html>\n"
        # TO-DO store this HTML into a file in self.config.reportDirectoryFileSystem as "report.html"
        try:
            reportFileName = self.config.reportDirectoryFileSystem + '/report.html'
            reportFile = open(reportFileName,  "w")
            reportFile.write(self.msgHTML)
            reportFile.close()
        except Exception as e:
            print("Something wrong with HTML report file (%s) generation: %s" % (reportFileName, repr(e)) )
            print(e)
            pass

    def taskRender( self ):
        self.msgHTML += "<table width=\"1100\" cellspacing=\"0\" cellpadding=\"5\" border=\"1\" bordercolor=\"#828282\">\n"

        self.msgHTML += "<TR style=\"background-color:#CEE3F6\"><TH>Task</TH><TH>Status</TH><TH>Elaps</TH><TH>Log</TH>\n"
    
        subjectSuffix = ''
        subjectStatus = ''
        subjectError = ''

        for task in self.results:
            if debug:
                print("Task name:" +task.name)
                print("\tTask result:" + task.result)

            result = task.result
            p = re.compile('(.*)otal:([0-9]+) passed:([0-9]+) failed:([0-9]+)\s*$')

            if ( task.status == "PASSED" ):
                result = SpanMaker.makeSpan("green", task.result)
            elif ( task.result == "FAILED" or task.status == "FAILED"):
                if task.name in ['Setup']:
                    result = task.result
                    for subTask in task.failedSubtask:
                        logFileName = task.logFileFileSystem.replace('.summary', '_') + subTask 
                        files = glob.glob(logFileName+'.*.log')
                        if files:
                            self.logFiles.append(files[0])

                elif task.name in ['Wutooltests']:
                    result = task.result
                    self.logFiles.append(task.logFileFileSystem)
                    
                elif task.name in ['Build']:
                    result = task.result
                elif task.name in ['MLtests']:
                    logFileName = task.logFileFileSystem.replace('mltests.summary', 'ml-') 
                    files = glob.glob(logFileName+'*.log')
                    if files:
                        for f in sorted(files):
                            self.logFiles.append(f)

                else:
                    result = SpanMaker.makeSpan("red", task.result)
                    self.logFiles.append(task.logFileFileSystem)
                    
                subjectSuffix += self.appendWithDelimiter(subjectSuffix, task.problems +' ' + task.name )
                subjectError += self.appendWithDelimiter(subjectError, task.name )
                
                self.logReport['status'] += self.appendWithDelimiter(self.logReport['status'], task.problems + task.name[0:1].upper())
                
                if len(task.errorMsg) > 0:
                    if task.errorMsg.startswith('[Error]'):
                        self.testEngineErrMsg += task.errorMsg.replace('<br>\n','') + "<br>\n"
                    elif task.name not in ['Build']:
                        self.errorMsg += task.errorMsg + "<br>\n"
            elif ( ( task.result == "UNKNOWN" ) or ( task.result == "UNAVAILABLE" ) ):
                
                subjectSuffix += self.appendWithDelimiter(subjectSuffix,  task.result +' ' + task.name )
                subjectError += self.appendWithDelimiter(subjectError, task.name )
                
                self.logReport['status'] += self.appendWithDelimiter(self.logReport['status'], task.result[0:4].lower() + task.name[0:1].upper())
                
                result = SpanMaker.makeSpan("orange", task.result)
                if len(task.errorMsg) > 0:
                    if task.errorMsg.startswith('[Error]'):
                        self.testEngineErrMsg += task.errorMsg.replace('<br>\n','') + "<br>\n"
                    else:
                        self.errorMsg += task.errorMsg + "<br>\n"
            elif (task.name == 'Unittests'):
                # TODO It would be nice to color coding the results like other tests
                result = task.result.replace('unittest:', '')
                if task.status == 'FAILED':
                    self.errorMsg += task.errorMsg + "<br>\n"
                    subjectSuffix += self.appendWithDelimiter(subjectSuffix, task.problems +' ' + task.name);
                    subjectError += self.appendWithDelimiter(subjectError, task.name )
                    
            elif task.name == 'Wutooltests':
                # TODO It would be nice to color coding the results like other tests
                result = task.result
                if task.status == 'FAILED':
                    self.errorMsg += task.errorMsg + "<br>\n"
                    subjectSuffix += self.appendWithDelimiter(subjectSuffix, task.problems +' ' + task.name);
                    subjectError += self.appendWithDelimiter(subjectError, task.name )
                    
            elif(task.name == 'MLtests'):
                # TODO It would be nice to color coding the results like other tests
                result = task.result.replace('mltests:', '')
                if task.status == 'FAILED':
                    self.logFiles.append(task.logFileFileSystem)
                    subjectSuffix += self.appendWithDelimiter(subjectSuffix, task.problems +' ' + task.name)
                    subjectError += self.appendWithDelimiter(subjectError, task.name )
            else: 
                unprocessed_result = result
                result = ""
                for str in unprocessed_result.split(','):
                    str = str.strip()
                    m = p.match( str )
                    if m:
                        passedNum = m.group(3)
                        failedNum = m.group(4)
                        if( int(passedNum) > 0 ):  
                            passedNum = SpanMaker.makeSpan("green", passedNum)
                 
                        if ( int(failedNum) > 0 ):
                            if task.name == "Setup":
                                target = m.group(1).split(':')[0]
                                subTaskName = "setup_"+target
                                
                                subjectSuffix += self.appendWithDelimiter(subjectSuffix, failedNum+' ' + target + " setup")
                                subjectError += self.appendWithDelimiter(subjectError, target + " setup")
                                
                                subTask = TestTask( subTaskName , self.config )
                                self.logFiles.append(subTask.logFileFileSystem)
                            else:
                                subjectSuffix += self.appendWithDelimiter(subjectSuffix, failedNum + ' ' + task.name)
                                subjectError += self.appendWithDelimiter(subjectError, task.name)
                                self.logFiles.append(task.logFileFileSystem)

                            failedNum = SpanMaker.makeSpan("red", failedNum)

                        elif ( int(m.group(2)) > 0 ) and ( m.group(1) == m.group(2) ):  
                            failedNum = SpanMaker.makeSpan("green", failedNum)
                        if result: 
                            result = result + "<br/>"
                        result += m.group(1) + "otal:" + m.group(2) + " passed:" + passedNum + " failed:" + failedNum


            self.msgHTML += "<TR align=\"center\">\n"
            if debug:
                print("\tResult:" + result)

            self.msgHTML += "<TD>" + task.name + "</TD><TD>" + result + "</TD>\n"

            #
            # For elaps times
            #
            try:
               if task.name in ['Build', 'Wutooltests', 'Unittests', 'MLtests', 'Setup', 'Hthor', 'Thor', 'Roxie'] and len(task.elapsTime):
                   self.msgHTML += "<TD align=\"right\">" 
                   for elaps in task.elapsTime:
                       self.msgHTML += elaps +"<br>\n"
               else:
                   self.msgHTML += "<TD align=\"center\"> No data"

            except:
                print("Exception in add elaps times:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                print("Exception in user code:")
                print('-'*60)
                traceback.print_exc(file=sys.stdout)
                print('-'*60)

                self.msgHTML += "<TD align=\"center\"> No data"

            self.msgHTML += "</TD>\n"

            # For log files
            self.msgHTML += "<TD>" 
            if( task.name == "Build" ):
                
                self.msgHTML += "<a href=\"" + task.gitLogFileURL + "\" target=\"_blank\">git_log, </a>"
                self.msgHTML += "<a href=\"" + task.logFileURL + "\" target=\"_blank\">" + task.logFileName + "</a>"
            elif( task.name == "Setup" ):
                subTasks = [ 'setup_hthor', 'setup_thor', 'setup_roxie' ]
                for st in subTasks:
                    subTask = TestTask( st, self.config )
                    self.msgHTML += "<a href=\"" + subTask.logFileURL + "\" target=\"_blank\">" + subTask.logFileName + "</a><br/>"
            elif( task.name == "MLtests" ):
                logFileName = task.logFileFileSystem.replace('mltests.summary', 'ml-') 
                files = glob.glob(logFileName+'*.log')
                if files:
                    for f in sorted(files):
                        basename = os.path.basename(f)
                        subTaskName = basename.split('.')[0]
                        subTask = TestTask(subTaskName, self.config )
                        self.msgHTML += "<a href=\"" + subTask.logFileURL + basename + "\" target=\"_blank\">" + basename.replace('ml-','') + "</a><br/>"
            else:
                self.msgHTML += "<a href=\"" + task.logFileURL + "\" target=\"_blank\">" + task.logFileName + "</a>"
            self.msgHTML += "</TD>\n"

            self.msgHTML += "</TR>\n"

        if self.status == "PASSED":
            subjectStatus = self.status 
            self.logReport['status'] = self.status
        else:
            subjectStatus = "FAILED: "

        subjectSuffix = subjectSuffix.replace('\t',' ')
        

        self.msg['Subject'] = self.results[self.buildTaskIndex].gitBranchName[0].upper() + self.results[self.buildTaskIndex].gitBranchName[1:] + ' ' + subjectStatus + subjectError + ". HPCC " + self.config.reportObtSystemEnv + " OBT " + self.config.buildType +" result on branch " + self.config.buildDate.replace(' ', '_').replace(':','-')

        self.msgHTML += "</table><br>"
        
        if len(self.testEngineErrMsg) > 0:
            self.msgHTML += "<H3>Regression Test Engine errors</H3>\n"
            self.msgHTML += "<pre>" + self.testEngineErrMsg + "</pre><hr>\n"
        
        if len(self.buildErrorMsg) > 0:
            self.msgHTML += "<H3>Build errors</H3>\n"
            self.msgHTML += self.buildErrorMsg + "<hr>\n"
    
        if len(self.errorMsg) > 0:
            self.msgHTML += "<H3>Internal test errors</H3>\n"
            self.msgHTML += self.errorMsg + "<hr>\n"
       
        logArchiveLink = self.config.reportDirectoryURL + "/log-archive" 

        if RegressionLogProcessor:
            # Use it if sucessfully imported
            rlp = RegressionLogProcessor()
            print("ZAPpath:" + self.config.reportDirectoryURL + "/test/ZAP")
            rlp.setLogArchivePath(self.config.reportDirectoryURL + "/test/ZAP")
            for file in self.logFiles:
                try:
                    print ("Process "+file)
                    rlp.ProcessFile(file)
                    rlp.ProcessResults()
                    self.msgHTML += '\n'.join(rlp.GetHtmlResult())
                    rlp.SaveResult()
                except:
                    pass
                finally:
                    pass
            

        if self.config.reportObtSystem == 'OBT-2':
            self.msgHTML += "<ul><li><a href=\"" + logArchiveLink + "\" target=\"_blank\">Nightly Build Log Archive</a></li></ul>\n"
     
            self.msgHTML += "<br><hr>\n"
            self.msgHTML += "Links to results in old OBT system (Wiki pages)<br>\n"
            self.msgHTML += "<ul>\n"
            self.msgHTML += "<li><a href=\"http://10.176.152.123/wiki/index.php/HPCC_Nightly_Builds\" target=\"_blank\">Nightly Builds Web Page</a></li>\n"
            self.msgHTML += "<li><a href=\"http://10.176.152.123/data2/nightly_builds/HPCC/5.0/\" target=\"_blank\">Nightly Builds Archive</a></li>\n"
            self.msgHTML += "<li><a href=\"" + self.config.archiveDirectoryURL +"\" target=\"_blank\">HPCC Builds Archive</a></li>\n"
            self.msgHTML += "</ul>\n"

        else:
            self.msgHTML += "<ul>\n"
            self.msgHTML += "<li><a href=\"" + logArchiveLink + "\" target=\"_blank\">Nightly Build Log Archive</a></li>\n"
            self.msgHTML += "<li><a href=\"" + self.config.archiveDirectoryURL + "\" target=\"_blank\">HPCC Builds Archive</a></li>\n"
            self.msgHTML += "</ul>\n"

    def send( self ): 
        self.msg.attach( MIMEText( self.msgHTML, 'html' ))  
        server = config.get( 'Email', 'SMTPServer' )
        fromaddr = config.get( 'Email', 'Sender' )
        
        toList = self.msg['To'].split( ',' )
       
        try:
            if server == "smtp.ntlworld.com":
                # My current dev env only supports SMTP on SSL
                smtpObj = smtplib.SMTP_SSL( server, 465 )
            else:
                smtpObj = smtplib.SMTP( server, 25 )
            
            smtpObj.set_debuglevel(0)
            smtpObj.sendmail( fromaddr, toList, self.msg.as_string() )
            #print( self.msg.as_string() )
        except smtplib.SMTPException:
            print( "Error: unable to send email" )
       
    def storeLogRecord(self):
        sequence = ['buildDate', 'buildTime', 'gitBranchName', 'thorConfig', 'status', 'gitBranchDate', 'gitBranchCommit', 'buildType']
        
        bTimeStr = self.logReport['gitBranchDate']
        if ('+' in bTimeStr) or ('-' in bTimeStr):
            # Remove time differece at the end of the time string
            bTimeStr = bTimeStr.rsplit(' ', 1)[0]
        try:
            #Convert it to timedate
            bTime = datetime.strptime(bTimeStr, "%a %b %d %H:%M:%S %Y")
        
            # Format it to YYYY.MM.DD HH:MM
            self.logReport['gitBranchDate'] = bTime.strftime("%Y.%m.%d %H:%M")
        except:
            print("Exception in git branch date transform:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            print("git branch date: %s" % (self.logReport['gitBranchDate']))
            print("Exception in user code:")
            print('-'*60)
            traceback.print_exc(file=sys.stdout)
            print('-'*60)
            if bTimeStr == ''or self.logReport['gitBranchDate'] == '' :
                self.logReport['gitBranchDate']  = self.config._buildDate+' ' + self.config._buildTime
                print( "Generate gitBranchDate from config values:'%s'" % (self.logReport['gitBranchDate']  ) )
            
        try:
            logRecordFile = open(self.logReport['reportObtSystem']+'.txt',  "a" )
            
            for item in sequence:
                try:
                    logRecordFile.write(self.logReport[item]+'\t')
                except KeyError:
                    print("Key error Item: '%s' (len: %d)" % (item,  len(item)))
                    logRecordFile.write('%s:N/A\t' % (item) )
                    
            logRecordFile.write('\n')
        
        except:
            print("Exception in storeLogRecord():" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
            print("Exception in user code:")
            print('-'*60)
            traceback.print_exc(file=sys.stdout)
            print('-'*60)
        
        finally:
            logRecordFile.close()
        
if __name__ == "__main__":

    usage = "usage: %prog [options]"
    parser = OptionParser(usage=usage)
    parser.add_option("-d", "--date", dest="dateString",  default = None,  type="string", 
                      help="Date to generate report Default is '' (empty) for today. Use 'yy-mm-dd' or 'yyyy-mm-dd' to get result on specified days.", metavar="DATE_FOR_QUERY")
                      
    parser.add_option("-t", "--time", dest="timeString",  default = None,  type="string", 
                      help="Time to generate report Default is '' (empty) for current time. Use 'hh-mm-ss' 'hh-mm' to get result on specified time.", metavar="TIME_FOR_QUERY")

    parser.add_option("-v", "--verbose", dest="verbose", default=False, action="store_true", 
                      help="Show more info. Default is False"
                      , metavar="VERBOSE")
                    
    parser.add_option("--debug", dest="debug", default=False, action="store_true", 
                      help="Show debug info. Default is False"
                      , metavar="DEBUG")

    (options, args) = parser.parse_args()
    
    config = BuildNotificationConfig(options)
    
    try:
        bn = BuildNotification(config)
        bn.processResults()
        bn.headRender()
        bn.taskRender()
        bn.endRender()
        bn.send()
        bn.storeLogRecord()
    except:
        print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
        print("Exception in user code:")
        print('-'*60)
        traceback.print_exc(file=sys.stdout)
        print('-'*60)
    print("End of Regression report generation.")
    pass

