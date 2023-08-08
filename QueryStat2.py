#!/usr/bin/env python3

#
# Query and store Perfromance Test suite results by clusters and store them into 
# perfstat-<cluster>-<date>-<version>.csv files
#

import json
import urllib.request, urllib.error
import re
from datetime import datetime,  timedelta
from optparse import OptionParser
import glob
import sys
import inspect
import os
import traceback
import configparser
import time

class HThorPerfResultConfig():
   
    def __init__(self, iniFile = ''):
        self.config = configparser.ConfigParser()
        self.config.optionxform = str
        self.engine = 'hthor'
       
        self.initHThorConfig()

    def get( self, section, key ):
        try:
            return self.config.get( section, key )
        except: 
            return None 
            
    def set(self, section,  key,  value):
        try:
            self.config.set( section, key, value )
            
        except configparser.NoSectionError:
            self.config.add_section(section)
            self.config.set( section, key, value )
        except:
            
            pass

    def initHThorConfig(self):
        
        self.config.add_section('OBT')
        self.config.set('OBT', 'ObtSystem', '${OBT_SYSTEM}')
        
        self.config.add_section('Environment')
        self.config.set('Environment', 'ObtSystemEnv',  '${OBT_SYSTEM_ENV}')
        self.config.set('Environment', 'ObtSystemHw',   'CPU/Cores: ${NUMBER_OF_CPUS}, RAM: ${MEMORY} GB')
        self.config.set('Environment', 'BuildSystemID', '${SYSTEM_ID}')
        
        self.config.add_section('Hardware')
        self.config.set('Hardware', 'Cores', '${NUMBER_OF_CPUS}')
        self.config.set('Hardware', 'CoreSpeed_MHz', '${SPEED_OF_CPUS}')
        self.config.set('Hardware', 'BOGOMIPS', '${BOGO_MIPS_OF_CPUS}')
        self.config.set('Hardware', 'RAM_GB', '${MEMORY}')
        
        self.config.add_section('Build')
        self.config.set('Build', 'BuildBranch', '${BRANCH_ID}')
        self.config.set('Build', 'BuildType',   '${BUILD_TYPE}')
        self.config.set('Build', 'CommitId',    '${COMMIT_ID}')
        
        self.config.add_section('Engine')
        self.config.set('Engine', 'Engine',          self.engine )
        self.config.set('Engine', 'EngineMemSizeGB', '${PERF_HTHOR_MEMSIZE_GB}')
        
        self.config.add_section('Performance')
        self.config.set('Performance', 'Timeout',              '${PERF_TIMEOUT}')
        self.config.set('Performance', 'SetupParallelQueries', '${PERF_SETUP_PARALLEL_QUERIES}')
        self.config.set('Performance', 'TestParallelQueries',  '${PERF_TEST_PARALLEL_QUERIES}')
        self.config.set('Performance', 'ExcludeClass',         '${PERF_EXCLUDE_CLASS}')
        self.config.set('Performance', 'QueryList',            '${PERF_QUERY_LIST}')
        self.config.set('Performance', 'FlushDiskCache',       '${PERF_FLUSH_DISK_CACHE}')
        self.config.set('Performance', 'RunCount',             '${PERF_RUNCOUNT}')
        self.config.set('Performance', 'CalcTrendParams',      '${PERF_CALCTREND_PARAMS}')
        
        self.config.add_section('Result')

    def saveConfig(self,  iniFile = ''):
        self.resolve()
        if iniFile == '':
            iniFile = self.engine+'_result.cfg'
            
        if not iniFile.endswith('.cfg'):
            iniFile += '.cfg'
            
        with open(iniFile, 'w') as f:
            self.config.write(f)
            
    def resolve(self):
        print("---------------------------------------------")
        print(("%s" % (self.engine)))
        for section in self.config.sections():
            print(("\t%s" % (section)))
            for option in self.config.options(section):
                value = self.config.get(section, option)
                print(("\t\toriginal: %s = %s" % (option, value)))
                # TO-DO
                # Find all "word" starting with '$' and optionally enclosed with '{' and '}' in the value 
                SetEnvPattern = re.compile("(\$\{?\w+\}?)")
                SetEnvMatchList = re.findall(SetEnvPattern, value)
#                print(SetEnvMatchList)
                
                # For each "word"
                for word in SetEnvMatchList:
                    #   Remove '$' and '{' '}' if they are exist
                    newWord = word.replace('$','').replace('{','').replace('}','')
                
                    #   Find a variable named by value in the ENV and get the real value
                    if newWord in os.environ:
                        newWord = os.environ[newWord]
                        #   Replace the original "word" with the real value
                        value = value.replace(word, newWord)
                        if (' ' in value) and (not value.startswith('"')):
                            value = '"' + value + '"'
                    else:
                        # To remove original reference
                        #value = value.replace(word, "%s not defined in the environment" % (word) )
                        value = value.replace(word, "")
                        
                # Set the updated/resolved value back to the config.
                self.config.set(section, option, value)
                print(("\t\tresolved: %s = %s" % (option, value)))
        pass

class ThorPerfResultConfig( HThorPerfResultConfig ):
    
    def __init__(self):
        HThorPerfResultConfig.__init__(self)
        self.engine = 'thor'
        self.initThorConfig()

    def initThorConfig(self):
        self.config.set('Engine', 'Engine', self.engine )
        self.config.set('Engine', 'EngineMemSizeGB', '${PERF_THOR_MEMSIZE_GB}')
        self.config.set('Engine', 'ThorSlaves', '${PERF_THOR_NUMBER_OF_SLAVES}')
    
class RoxiePerfResultConfig( HThorPerfResultConfig ):
    
    def __init__(self):
        HThorPerfResultConfig.__init__(self)
        self.engine = 'roxie'

        # If a child class uses same method name as it parent and its parent execute is from init, then
        # the result is the child method will be called from the parent init
        # calling same name the initConfig() caused exception in the child because the child only wanted to update 
        # the config created in parent, but didn't based on the parent init called the child's initConfig().
        # Now I renamed all initConfig() tho class related one like initRoxieConfig() and everything is fine
        self.initRoxieConfig()


    def initRoxieConfig(self):
        self.config.set('Engine', 'Engine', self.engine )
        self.config.set('Engine', 'EngineMemSizeGB', '${PERF_ROXIE_MEMSIZE_GB}')



class WriteStatsToFile(object):

    jobname = "*-161128-*"
    jobNameSuffix = ""
    
    #host = "http://10.241.40.12:8010/WsWorkunits/WUQuery.json?PageSize=1000&Sortby=Jobname"  # *-161128-*
    host = "10.241.40.8"
    port = "8010"
    #url = "http://" + host + ":" + port + "/WsWorkunits/WUQuery.json?PageSize=25000&Sortby=Jobname"  # *-161128-*    
    url = "http://" + host + ":" + port + "/WsWorkunits"
    compileTimeDetailsDepth=1   #valid values = 0,1,2
    compileTimeQuery="http://<ESP_IP>:<ESP_PORT>/WsWorkunits/WUDetails.json?WUID=<WUID>&ScopeFilter.MaxDepth=1&ScopeFilter.Scopes=compile&ScopeFilter.PropertyFilters.WUPropertyFilter.itemcount=0&NestedFilter.Depth=<NESTED_DEPTH>&NestedFilter.ScopeTypes=&PropertiesToReturn.Properties=TimeElapsed&PropertiesToReturn.ExtraProperties.WUExtraProperties.itemcount=0&PropertyOptions.IncludeName=on&PropertyOptions.IncludeName=1&PropertyOptions.IncludeRawValue=on"
    def __init__(self, options):
        
        self.destPath = options.path
        if not os.path.exists(self.destPath):
            os.mkdir(self.destPath)
            
        if not self.destPath.endswith('/'):
            self.destPath += '/'
            
        self.dateStr = []
        for item in options.dateStrings:
            self.dateStr += item.replace('\'','').split(',')
        if len(self.dateStr) == 0:
             self.dateStr.append(datetime.today().strftime("%y%m%d"))
             
        #self.dateStr = options.dateStrings
        self.verbose = options.verbose
        self.host = options.host
        self.port = options.port
        #self.url = "http://" + self.host + ":" + self.port + "/WsWorkunits/WUQuery.json?PageSize=2500&Sortby=Jobname"  # *-161128-*
        self.url = "http://" + self.host + ":" + self.port + "/WsWorkunits"
        self.obtSystem = options.obtSystem
        self.buildBranch = options.buildBranch
        
        # To query use: "http://" + self.host + ":" + self.port + "/WsSMC/Activity.json"
        # "ActivityResponse": {"Build": "community_7.12.0-1Debug[community_7.12.0-1-dirty]"}
        self.buildType = options.buildType
            
        #global compileTimeQuery
        self.compileTimeQuery = WriteStatsToFile.compileTimeQuery.replace('<ESP_IP>',  self.host).replace('<ESP_PORT>',  self.port)
        
        if options.jobNameSuffix != "":
            if not options.jobNameSuffix.startswith('-'):
                if not options.jobNameSuffix.startswith('#'):
                    self.jobNameSuffix = '%23' + options.jobNameSuffix
                else:
                    self.jobNameSuffix = options.jobNameSuffix.replace('#','%23')
                
                self.jobNameSuffix = '-' + self.jobNameSuffix
            elif options.jobNameSuffix.startswith('-#'):
                self.jobNameSuffix = options.jobNameSuffix.replace('#','%23')
            else:
                self.jobNameSuffix = '-%23' + options.jobNameSuffix[1:]
            pass
        
        self.dateTransform = False
        self.newDate = ""
        if options.dateTransform != "":
            self.dateTransform = True
            # Remove '-' from the date and get it length
            newDate = options.dateTransform.replace('-','')
            dlen = len(newDate)
            if dlen == 6:
                # 'yymmdd' form
                self.newDate = newDate
            elif dlen == 8:
                # 'yyyymmdd' form
                self.newDate = newDate[2:]
            else:
                # Invalid date, date transform not allowed
                self.dateTransform = False
                print(("Invalid date: '%s' for transform, ignored." % (options.dateTransform)))
            
            if self.dateTransform:
                print(("Using date: '%s' -> '%s' to transform date stamp in jobname(s) and to store result file." % (options.dateTransform, self.newDate)))
            
            pass
        self.allWorkunits = options.allWorkunits
        self.addHeader = options.addHeader
        self.compileTimeDetailsDepth = options.compileTimeDetailsDepth
        self.timeStamp = options.timeStamp
        self.timeStampStr =  datetime.today().strftime("%H%M%S")  # "HHMMSS"
        
        self.clusters = ('hthor', 'thor', 'roxie' )
        self.resultConfigClass = { 'hthor': HThorPerfResultConfig(), 'thor' : ThorPerfResultConfig(),  'roxie' : RoxiePerfResultConfig() }
        if self.buildBranch == None:
            self.queryHpccVersion()
        else:
            self.hpccVersionStr = self.buildBranch
        
        print("self.destPath                : '" + self.destPath + "'")
        print("self.host                    : '" + self.host + "'")
        print("self.url                     : '" + self.url + "'")
        print("self.allWorkunits            : '" + str(self.allWorkunits) + "'")
        print("self.dateStr                 : '" + str(self.dateStr) + "'")
        print("self.timeStamp               : '" + str(self.timeStamp) + "'")
        print("self.timeStampStr            : '" + str(self.timeStampStr) + "'")
        print("self.verbose                 : '" + str(self.verbose) + "'")
        print("self.addHeader               : '" + str(self.addHeader) + "'")
        print("self.compileTimeDetailsDepth : " + str(self.compileTimeDetailsDepth))
        print("hpccVersion                  : " + self.hpccVersionStr + "'" )
        pass
        
    def myPrint(self, Msg, *Args):
        if self.verbose:
            format=''.join(['%s']*(len(Args)+1)) 
            print((format % tuple([Msg]+list(map(str,Args))) ))
            
    def run(self):
        # TODO Add '*' to date string to query all missing datafiles from today backward
        # Get the list of existing datafiles, determine today dat and check if it is exist. f not add the date to teh array
        # then do same with day before date and so on.
        
        if len(self.dateStr) > 1:
            for dateStr in self.dateStr:
                for cluster in self.clusters:
                    self.queryStats(cluster,  dateStr)
        elif '*' == self.dateStr[0]:
            existFiles = {}
            files = glob.glob(self.destPath+'perfstat-*.csv')
            files.sort()
            for fileName in files:
                print(("File name: " + fileName))
                nameItems = fileName.replace('./', '').replace('.csv', '').split('-')
                if len(nameItems) < 3:
                    print("Wrong file name!")
                    continue
                cluster = nameItems[1]
                date = nameItems[2]

                if date not in existFiles:
                    existFiles[date] = set()
                
                existFiles[date].add(cluster)
            today = datetime.today()
            dayStr = today.strftime("%y%m%d")
            stepBack = True
            stepBackCounter = 11
            
            while stepBack and (stepBackCounter > 0):
                print(("Day: " + dayStr))
                if dayStr not in existFiles:
                    existFiles[dayStr] = set()
                    for cluster in self.clusters:
                        if self.queryStats(cluster, dayStr):
                            #add this day and cluster to existFiles
                            existFiles[dayStr].add(cluster)
                            stepBack = True
                        else:
                            stepBack = False
                elif (dayStr in existFiles) and len(existFiles[dayStr]) < 3:
                    for cluster in self.clusters:
                        if cluster not in existFiles[dayStr]:
                            if self.queryStats(cluster, dayStr):
                                #add this day and cluster to existFiles
                                existFiles[dayStr].add(cluster)
                            else:
                                pass
                    stepBack = True
                else:
                    stepBack = False
                    pass
                if stepBack:
                    today += timedelta(days=-1)
                    dayStr = today.strftime("%y%m%d")
                    stepBackCounter -= 1
            pass
        else:
            dateStr = self.dateStr[0]
            for cluster in self.clusters:
                self.queryStats(cluster, dateStr)
        
    def checkJobname(self, wuid, jobname):
        jobname = jobname.lower()
        shortJobname = ''
        # Ensure the version parameters always alphabetically ordered if exist
        items = jobname.split('-')
        itemsLen = len(items)
        if itemsLen > 3:
            itemsVersion = sorted(items[1:itemsLen-2])
            #             ECL source name              Sorted version params          
            shortJobname = '-'.join(items[0:1]) + '-' + '-'.join(itemsVersion)
            
            if self.dateTransform :
                items[itemsLen-2] = self.newDate
            #  Date and time
            jobname = shortJobname + '-' + '-'.join(items[itemsLen-2:itemsLen])
            #  Add time to distinguish different result on same day
            shortJobname += '-' + items[itemsLen-1]
        if itemsLen == 3:
            # Old jobname it contains only the ECL name, date and time
            # Check if there are any verson parameters and if yes add it/them into the jobname
            # wuQuery = self.host +'/WsWorkunits/WUInfo.json?Wuid='+wuid
            #wuQuery = "http://" + self.host + ":" + self.port + "/WsWorkunits/WUInfo.json?Wuid="+wuid
            wuQuery = self.url +"/WUInfo.json?Wuid="+wuid
            resp = None
            try:
                response_stream = urllib.request.urlopen(wuQuery)
                json_response = response_stream.read()
                resp = json.loads(json_response)
                response_stream.close()
            except:
                print("Network error in checkJobname('%s', '%s')" % (wuid, jobname))
                print("BadStatusLine exception with '%s'" % (wuQuery))
                # ESP server on the other side is crashed and it needs some time to recover.
                time.sleep(20)
                pass
                
            if resp != None:
                debugValues = resp['WUInfoResponse']['Workunit']['DebugValues']['DebugValue']
                versionInfo = ''
                versionsFromDebug = []
                for debugValue in debugValues:
                    if debugValue['Name'].startswith('eclcc-d'):
                        value = '-'+ debugValue['Name'].replace('eclcc-d', '').split('-')[0]
                        versionsFromDebug.append(value + '('+debugValue['Value']+')')

                if len(versionsFromDebug) > 0: 
                    versionInfo = ''.join(sorted(versionsFromDebug))
                    # Regression test based extra parameter, can cause problem to create diagram. Remove
                    versionInfo = versionInfo.replace("-hpccbasedir('/opt/HPCCSystems/')", "")
                    shortJobname = items[0] + versionInfo
                    
                    if self.dateTransform :
                        items[itemsLen-2] = self.newDate
                        
                    jobname = shortJobname + '-' + items[itemsLen-2] + '-' + items[itemsLen-1]
                    #  Add time to distinguish different result on same day
                    shortJobname += '-' + items[itemsLen-1]
                    pass
                else:
                    shortJobname = items[0] + '-' + items[itemsLen-1]
            else:
                shortJobname = items[0] + '-' + items[itemsLen-1]
            pass
        return (shortJobname,  jobname)
        
    def convertTimeStringToSec(self,  timeString):
        # len(valueItems) == 1 -> seconds only
        # value = valueItems[len-1] * multipliers[3]
        # len(valueItems) == 2 -> minutes and seconds
        # value = valueItems[len-1] * multipliers[3] + valueItems[len-2] * multipliers[2]
        # len(valueItems) == 3 -> hours, minutes and seconds
        # value = valueItems[len-1] * multipliers[3] + valueItems[len-2] * multipliers[2] + valueItems[len-3] * multipliers[1]
        # len(valueItems) == 4 -> days, hours, minutes and seconds
        # value = valueItems[len-1] * multipliers[3] + valueItems[len-2] * multipliers[2] + valueItems[len-3] * multipliers[1] + valueItems[len-4] * multipliers[0]
        
        valueItems = timeString.split(':')
        value = 0
        multipliers= [3600*24, 3600, 60, 1]
        multipliersIndex = 3
        i = len(valueItems)-1
        while i >= 0 :
            value += float(valueItems[i]) * multipliers[multipliersIndex]
            i -= 1
            multipliersIndex -= 1
        
        return value
        
    def queryHpccVersion(self):
        # http://10.241.40.6:8010/WsWorkunits/WUCheckFeatures.json
        #url = "http://" + self.host + ":" + self.port + "/WsWorkunits/WUCheckFeatures.json"
        url =  self.url + "/WUCheckFeatures.json"
        state = 'OK'
        try:
            response_stream = urllib.request.urlopen(url)
            json_response = response_stream.read()
            resp = json.loads(json_response)
            if 'WUCheckFeaturesResponse' in resp:
                self.hpccMajor = resp['WUCheckFeaturesResponse']['BuildVersionMajor']
                self.hpccMinor = resp['WUCheckFeaturesResponse']['BuildVersionMinor']
                self.hpccPoint = resp['WUCheckFeaturesResponse']['BuildVersionPoint']
                self.hpccVersionStr = str(self.hpccMajor) + '.' + str(self.hpccMinor) + '.' + str(self.hpccPoint)
            else:
                print("Can't get the HPCC version, exit")
                exit
            pass
        except KeyError as ke:
            state = "Key error:"+ke.str()
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except urllib.error.HTTPError as ex:
            state = "HTTP Error: "+ str(ex.reason)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except urllib.error.URLError as ex:
            state = "URL Error: "+ str(ex.reason) + " (perhaps service down on host)."
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except Exception as ex:
            state = "Unable to query "+ str(ex.reason)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        finally:
            print(("State:" + state))
            if state != 'OK':
                exit()
            print("End.")
            
    def queryCompileTime(self,  wuid):
        def getTime(json_object, name):
            return [obj for obj in json_object if obj['name']==name][0]['rawValue']
            
        url = self.compileTimeQuery.replace('<WUID>',  wuid).replace('<NESTED_DEPTH>', str(self.compileTimeDetailsDepth))
        times = {}
        try:
                response_stream = urllib.request.urlopen(url)
                json_response = response_stream.read()
                resp = json.loads(json_response)
                response_stream.close()
                response_stream = None
                numOfScopes = len(resp["WUDetailsResponse"]["Scopes"]["Scope"])
                self.myPrint("\tNumber of scopes: %d" % (numOfScopes))
                for scope in range(numOfScopes):
                    # Some magic to make split easier                                                                                    separate subseq. cpp                         separate extensions
                    scopeName = resp["WUDetailsResponse"]["Scopes"]["Scope"][scope]["ScopeName"].replace('_', ':').replace(' ', '_').replace('.', ':*')
                    scopeItems = scopeName.split(':')
                    # Looking for the position of WUID in the scopeItems
                    w = [i for i in range(len(scopeItems)) if scopeItems[i][0] == "W" ]
                    if len(w) > 0:
                        # If found replace real WUID with '<wuid>
                        # if not found that means the scope name not C++ compiling item)
                        scopeItems[w[0]] = "<wuid>"
                        # Check the next item, is it subsequent cpp file name?
                        if scopeItems[w[0]+1][0] != '*':
                            # Yes, pading the number with '0' from left 
                            scopeItems[w[0]+1] = "%03d" % (int(scopeItems[w[0]+1]))
                        # Assembly the scopeName back
                        scopeName = '-'.join(scopeItems)
                        # Reverse the magic done before split. restore extensions, restore '_' before subsequent cpp file number
                        scopeName = scopeName.replace('-*', '.').replace('>-','>_')
                    
                    scopeTime = float(resp["WUDetailsResponse"]["Scopes"]["Scope"][scope]["Properties"]["Property"][0] ["RawValue"]) / 1000000000.0
                    self.myPrint("\t\tScope name: %s, time: %f sec" % (scopeName, scopeTime))
                    times[scopeName] = scopeTime
                        
        except Exception as ex:
            print(ex)
            pass

        return times
        
    def queryStats(self, cluster,  dateStr = ''):
        url = self.url + "/WUQuery.json?PageSize=25000&Sortby=Jobname&Cluster=" + cluster
        if 'roxie' == cluster:
            url += '*'
        today = datetime.today()
        if dateStr == '':
            dateStr = today.strftime("%y%m%d")
        else:
            dateStr = dateStr.replace('-', '')
            
        self.resultConfigClass[cluster].set('Result',  'Date',  dateStr)
        self.resultConfigClass[cluster].set('Result',  'Time',  self.timeStampStr )
        if self.obtSystem != None:
            self.resultConfigClass[cluster].set('OBT', 'ObtSystem',  self.obtSystem)
        
        if self.buildBranch != None:
            self.resultConfigClass[cluster].set('Build', 'BuildBranch', self.buildBranch)
        
        if self.buildType != None:
            self.resultConfigClass[cluster].set('Build', 'BuildType', self.buildType)
        
        if self.jobNameSuffix != '':
            queryJobname = "*" + self.jobNameSuffix + "-*"
        else:
            queryJobname = "*-" + dateStr + "-*"
            
        self.myPrint("queryJobname:" + queryJobname)
        url += "&Jobname=" + queryJobname
        print("query:" + url)
        
        self.resultConfigClass[cluster].set('Result',  'Query',  url)
        state = 'OK'
        wuCount = 0
        try:
            try:
                response_stream = urllib.request.urlopen(url)
                json_response = response_stream.read()
                resp = json.loads(json_response)
                response_stream.close()
                response_stream = None
            except Exception as ex:
                state = "HTTP Error: "+ str(ex.reason)
                print("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" )
                pass
                 
            if self.dateTransform :
                if self.timeStamp:
                    statFileName = self.destPath + "perfstat-" + cluster + "-" + self.newDate + "-"  + self.timeStampStr  + "-" + self.hpccVersionStr +".csv"
                else:
                    statFileName = self.destPath + "perfstat-" + cluster + "-" + self.newDate + "-" + self.hpccVersionStr +".csv"
            else:
                if self.timeStamp:
                    statFileName = self.destPath + "perfstat-" + cluster + "-" + dateStr + "-"  + self.timeStampStr  + "-" + self.hpccVersionStr +".csv"
                else:
                    statFileName = self.destPath + "perfstat-" + cluster + "-" + dateStr + "-" + self.hpccVersionStr +".csv"

            print("statFileName:" + statFileName)
            self.resultConfigClass[cluster].set('Result',  'DataFileName',  statFileName)
            
            if'Workunits' not in resp['WUQueryResponse']:
                state = "Workuint not found."
                return False
               
            stats= resp['WUQueryResponse']['Workunits']['ECLWorkunit']
            
            numOfWorkunits = len(stats)
            print("Number of workunits in result is: %d" % ( numOfWorkunits ))

            statFile = open(statFileName,  "w")
            workunitFilter =   {False : ['completed'], 
                                          True  : ['completed',  'compiled',  'failed', 'aborted' ]
                                        }
            rex = re.compile("^[0-9][0-9][a-z][a-z]")
 
            headerWritten = False
            index = 1
            
            for stat in stats:
                if (self.allWorkunits or rex.match(stat['Jobname'])) and (stat['State'] in workunitFilter[self.allWorkunits]):
                    (shortJobName,  jobName) = self.checkJobname(stat['Wuid'], stat['Jobname'])

                    self.myPrint("%5d\%d WUID: %s, job name: %s" % (index, numOfWorkunits, stat['Wuid'],  stat['Jobname']))
                    index += 1

                    clusterTime = self.convertTimeStringToSec(stat['TotalClusterTime'])
                    compileTimeHeaders = ''
                    compileTimeDetails = ''
                    compileTimeDetailsLog = ''
                    compileTimes = self.queryCompileTime(stat['Wuid'])
                    compileTimeValue = compileTimes['compile']
                    for key in sorted(compileTimes):
                        if key == 'compile':
                            #It is already handled
                            continue
                            
                        compileTimeHeaders += "," + key
                        compileTimeDetails += ",%f" % (compileTimes[key])
                        compileTimeDetailsLog += ", %s:%f" % (key, compileTimes[key])

                    if not headerWritten: 
                        self.resultConfigClass[cluster].set('Result',  'DataFileHeader', "jobName,clusterTime,compileTime%s" % (compileTimeHeaders))
                        headerWritten = True
                        if self.addHeader: 
                            statFile.write( "%s%s\n" % ("jobName,clusterTime,compileTime", compileTimeHeaders ))
                    
                    wuCount += 1

                    self.myPrint("\tJobname: %s, TotalClusterTime: %0.3f sec, TotalCompileTime: %0.3f sec %s" % (jobName,  clusterTime, compileTimeValue, compileTimeDetailsLog))
                    buff = "%s,%0.3f,%0.3f%s\n" % (jobName, clusterTime, compileTimeValue, compileTimeDetails)
                    print(buff)
                    statFile.write(buff )
                    
            if wuCount == 0:
                print("No matching workunit")

            statFile.close()
            # Remove old file (name without hpcc version) if exists
            oldstatFileName = self.destPath + "perfstat-" + cluster + "-" + dateStr + ".csv"
            if os.path.exists(oldstatFileName):
                print(("Remove old resultfile '%s'" % (oldstatFileName)))
                os.unlink(oldstatFileName)
               
    
        except KeyError as ke:
            state = "Key error:"+ke.str()
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except urllib.error.HTTPError as ex:
            state = "HTTP Error: "+ str(ex.reason)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except urllib.error.URLError as ex:
            state = "URL Error: "+ str(ex.reason) + " (perhaps service down on host)."
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except ZeroDivisionError as ex:
            state = "ZeroDivisionErr " + str(ex)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))
            
        except Exception as ex:
            state = "Unable to query "+ str(ex.reason)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))

        except UnboundLocalError as ex:
            state = "Unbound Local Error "+ str(ex.reason)
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))
            
        finally:
            print(("State:" + state))
            if wuCount == 0:
                return False
                
            if state != 'OK':
                exit()
            print(("Recieved Workunit count is: %d" %(wuCount)))
            
            self.resultConfigClass[cluster].set('Result',  'WorkunitCount',  str(wuCount))
            self.resultConfigClass[cluster].set('Result',  'Status',  state)
        
            self.resultConfigClass[cluster].saveConfig(statFileName.replace('.csv',''))
            
            print("End.\n\n")
        
        return True

#
#-------------------------------------------
# Main

if __name__ == '__main__':
    print("Start...")
    
    usage = "usage: %prog [options]"
    parser = OptionParser(usage=usage)
    parser.add_option("-p", "--path", dest="path",  default = '.',  type="string", 
                      help="Target path to store performance data. Default is '.'", metavar="TARGET_PATH")
                      
    parser.add_option("-t", "--target", dest="host",  default = '127.0.0.1',  type="string", 
                      help="Target host to query workunit results. Default is '127.0.0.1'", metavar="HOST")
                      
    parser.add_option("-d", "--date", dest="dateStrings",  default = [],  type="string", action="append", 
                      help="Date(s) to query and stor performance test results. Default is '' (empty) for today. Use '181208,181209,181210,181211' to get result on specified days.", metavar="DATES_FOR_QUERY")
                      
    parser.add_option("-v", "--verbose", dest="verbose", default=False, action="store_true", 
                      help="Show more info. Default is False"
                      , metavar="VERBOSE")
                      
    parser.add_option("-j", "--jobnamesuffix",  dest="jobNameSuffix",  default = "",  type = "string" , 
                        help="Specify workunit job name suffix for query.",  metavar="JOBNAMESUFFIX")
                        
    parser.add_option("--dt", "--dateTransform",  dest="dateTransform",  default = "",  type = "string" , 
                        help="Change test(s) execution date to the given one in 'yymmdd', 'yyyymmdd' or parts separated with '-' like 'yy-mm-dd' format like '200625'. (Use it with conjuction with --jobNameSuffix to get results tested on an older commit.)", 
                        metavar="DATETRANSFOMR")
                        
    parser.add_option("--timestamp",  dest="timeStamp",  default=False, action="store_true", 
                        help="Add timestamp in 'HHMMSS' format to the target file names",  metavar="TIMESTAMP")
                        
    parser.add_option("-a","--allWorkunits",  dest="allWorkunits",  default=False, action="store_true", 
                        help="Query all workunits instead of the Performance test related set.",  metavar="ALLWORKUNITS")

    parser.add_option("--port",  dest="port",  default="8010", type="string",
                        help="Target port to query workunit results. Default is '8010'",  metavar="PORT")
                        
    parser.add_option("--obtSystem",  dest="obtSystem",  default=None, type="string",
                        help="OBT system identifier. Default is 'None'",  metavar="OBTSYSTEM")
                        
    parser.add_option("--buildBranch",  dest="buildBranch",  default=None, type="string",
                        help="Platform source branch. Default is 'None'",  metavar="BUILDBRANCH")
                        
    parser.add_option("--addHeader",  dest="addHeader",  default=False, action="store_true", 
                        help="Add record header/structure to CSV file.",  metavar="ADDHEADER")
                        
    parser.add_option("--compileTimeDetails",  dest="compileTimeDetailsDepth",  default=0, 
                        help="Set compile time detals. 0 (def) only compile time, 1 one level deeper, 2more compile details, but it can contains compile time from more than one c++ source, so the file header may only partially valid. It may extend the CSV file headers",  
                        metavar="COMPILETIMEDETAILSDEPTH")

    parser.add_option("--buildType",  dest="buildType",  default=None,  type="string", 
                        help="Platform build type. Default is None (until I found out how to query it.)",  
                        metavar="BUILDTYPE")
                        
    (options, args) = parser.parse_args()

    if options.path == None:
        parser.print_help()
        exit()
    
    #options.dateStrings = ['161128', '161129', '161130', '161201', '161202', '161203', '161204',  '' ]
    #options.dateStrings = ['161129', '161130', '161201', '161202', '161203', '161204',  '' ]
    #options.dateStrings = [ '161207' ]
    #options.dateStrings = [ '' ]
    #options.dateStrings = [ '*' ]
    
    try:
        wstf = WriteStatsToFile( options)
        wstf.run()
    except Exception as ex:
        print(("Exception: %s" % ( str(ex) ) ))
        print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))
        traceback.print_stack()
        
    print("End...")
     
