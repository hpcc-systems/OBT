#!/usr/bin/env python3

import os
import sys
import time
import glob
import re
import inspect
import traceback
from datetime import datetime

class RegressionLogProcessor(object):
 
    report=[]

    def __init__(self,  curDir = None,  suite = 'Regression'):
        self.faultedTestCase = {}
        self.logDates = []
        self.knownProblems = {}
        self.htmlReport=[]
        self.timeoutedTests=[]
        if curDir:
            self.scriptPath = curDir
        else:
            self.scriptPath = os.path.dirname(__file__)
            self.scriptPath = os.path.realpath(self.scriptPath)

        self.suite = suite
        self.knownProblemFileName = str(os.path.join(self.scriptPath, suite+"KnownProblems.csv"))
        self.timeoutedTestName = str(os.path.join(self.scriptPath, suite+"TimeoutedTests.csv"))
        self.fileProcessingExceptions = str(os.path.join(self.scriptPath, suite+"FileProcessingExceptions.txt"))
        
        self.logArchivePath = None
        pass
        
    def setLogArchivePath(self,  path):
        self.logArchivePath = path
        
    def LogException(self,  target, filename,  lineno,  msg):
        try:
            outFile = open(self.fileProcessingExceptions,  "a+")
            outFile.write("target:"+target+"\nfile:"+filename+"\nline:"+str(lineno)+"\n" )
            outFile.write("msg:"+msg+"\n")
            outFile.write("------------------------------------------------------------------------\n\n")
            outFile.close()
        except:
            pass
        
    def splitAndStrip(self, text):
        itemsTemp = text.split(':')
        # Strip all elements of a string list
        return (list(map(str.strip, itemsTemp)))
        
    def ProcessFile(self, filename):
        self.idIndex = {}
        self.testCases= []
        self.maxTestNameLen=0
        self.report=[]
        self.htmlReport=[]
        self.target=''
        self.targetPrefix = 'Regression test'
        if not filename.endswith('.log'):
            return
            
        if 'mltest' in filename:
            self.logDate = datetime.today().strftime("%y-%m-%d")
            self.targetPrefix = 'ML test'
        else:
            items = filename.split('.')
            self.logDate=items[len(items) - 2][0:8]
        self.weekDay=datetime.strptime(self.logDate, "%y-%m-%d").strftime('%A')
        self.logDateDay = '-'+self.weekDay
        self.logDates.append(self.logDate)
        file = open(filename, 'r')
        lineno = 0
        # Log file segments
        isHeader=True
        isTestList=False
        isResultList=False
        isOutput=False
        isError=False
        isEpilog = False
        error = []
        for line in file:
            try:
                lineno += 1
                line = line.strip().strip('\'').replace('\n', '')
                if len(line) == 0:
                    continue
                    
                # Some magic because in HPCC-18755 I added a testname with version info to 'Pass', to 'Fail' and other log items
                # The problem is the version string can contains same characters as I used to separate elements of the log line,
                # like '.' and ':'. So with his change I separate the version part (if it exists), replece '.' to ':' in other parts, 
                # then asemble the logline back. 
                match = re.search("(.*version:)(.* \))(.*)",  line)
                if ('version' in line) and match:
                    # More magic to save '.' in the version info (like separator in IP address) replace it with '_'
                    # It will be restore later.
                    line = match.group(1).replace('.',':') + match.group(2).replace(' ','').replace('.','_') + match.group(3).replace('.',':')
                    pass
                else:
                    line = line.replace('.', ':')
                 
                if isOutput and line.startswith('--- '):
                    isOutput = False
                    isError = True
                    error = []
                
                if isHeader:
                    items = self.splitAndStrip(line)
                    if "Suite" in line:
                        self.target= items[1]
                        continue
                        
                    elif "Queries"in line:
                        self.numOfTests = items[1]
                        isHeader = False
                        isTestList=True
                        continue
                elif isTestList:
                    items = self.splitAndStrip(line)
                    if 'Results' in items[0]:
                        continue
                    if line.startswith('------'):
                        isTestList = False
                        isResultList = True
                        continue
                    if re.match("[0-9]+",  items[0]):
                        index=int(items[0])
                        if index == 0:
                            continue
                    else:
                        continue
                        
                    if index > len(self.testCases):
                        self.testCases.append({})
                    if items[1].startswith('Test'):
                        testName = items[2].strip()
                        if 'version' in line:
                            testName += '(' + items[4]
                        testNameLen = len(testName)
                        if testNameLen > self.maxTestNameLen:
                            self.maxTestNameLen = testNameLen
                        items[1] = items[1].strip()
                        prev = index - 1
                        self.testCases[prev][items[1]]=testName
                        id = hash(testName)
                        self.testCases[prev]['id']=id
                        self.idIndex[id] = prev
                    elif ('Pass' in items[1]) or ('Fail' in items[1]):
                        results = items[1].lstrip(' ').replace('No WUID','No_WUID').replace('(', '').replace('sec)', '').replace(' - ', ' ').split(' ')
                        self.testCases[prev]['Result']=results[0]
                        if len(items) <= 2:
                            # Backward compatibility
                            results = items[1].lstrip(' ').replace('ecl - ','').replace('No WUID','No_WUID').replace('(', '').replace('sec)', '').split(' ')
                            self.testCases[prev]['Wuid']=results[1]
                            self.testCases[prev]['Elapstime']=results[2]
                            
                        else:
                            if 'version' in items[2]:
                                results = items[3].lstrip(' ').replace('ecl - ','').replace('No WUID','No_WUID').replace('(', '').replace('sec)', '').replace(')-', ' ').split(' ')
                                self.testCases[prev]['Wuid']=results[2]
                                if len(results) > 3:
                                    self.testCases[prev]['Elapstime']=results[3]
                                else:
                                    self.testCases[prev]['Elapstime']='0'
                            else:
                                results = items[2].lstrip(' ').replace('ecl - ','').replace('ecl ','No_WUID').replace('No WUID','No_WUID').replace('(', '').replace('sec)', '').split(' ')
                                self.testCases[prev]['Wuid']=results[0]
                                self.testCases[prev]['Elapstime']=results[1]
                                self.testCases[prev]['ZAPfile'] = 'No_ZAP'
                            if 'Fail' in results[0]:
                                pass
                    elif 'Zipped' in items[1]:
                        zaps = line.split('/')
                        zapFileName = zaps[len(zaps)-1].split(':')[0] + '.zip'
                        self.testCases[prev]['ZAPfile'] = zapFileName
                        pass
                    elif len(items) >= 3 and 'URL' in items[1]:
                        items = line.split(' ')
                        self.testCases[prev][items[1]]=items[2]
                    elif len(items) == 2 and 'URL N/A' in items[1]:
                        items = line.split(' ')
                        self.testCases[prev][items[1]]=items[2]
                    elif 'Create Stack Trace' in line:
                        # Perhaps it would be nice to report it somehow
                        pass
                    else:
                        items = line.split(' ')
                        self.testCases[prev][items[1]]=items[2]
                 
                    pass
                elif isResultList:
                    results = self.splitAndStrip(line)
                    if 'Passing' in results[0]:
                        numberOfPassed = results[1]
                        continue
                    elif 'Failure' in results[0]:
                        numberOfFailed = results[1]
                        continue
                    elif line.startswith('Output:'):
                        isResultList = False
                        isOutput=True
                        output=[]
                        continue
                        pass
                    elif line.startswith('Error:'):
                        isResultList = False
                        isOutput=False
                        isError=True
                        error=[]
                        continue
                        pass
                        
                elif isOutput:
                    if line.startswith('Log: /'):
                        isOutput = False 
                        if numberOfFailed > 0:
                            isError= True
                        else:
                            isEpilog = True
                        error = []
                    elif line.startswith('Error:'):
                        # store if any output left.
                        if len(output) > 0:
                            output[0] = output[0].replace('.',  ':')
                            items = output[0].split(':')
                            if len(items) >= 3:
                                if 'version' in output[0]:
                                    testName = items[2].strip() +'('+items[4].strip()
                                elif items[0].startswith('Output of'):
                                    testName = items[0].replace('Output of ', '').strip()
                                else:
                                    testName = items[2].strip()
                                testNameLen = len(testName)
                                id = hash(testName)
                                index = self.idIndex[id]
                                self.testCases[index]['Output'] = output
                                output = []
                             
                        isOutput =False
                        if numberOfFailed > 0:
                            isError= True
                        else:
                            isEpilog = True
                        error = []
                        continue
                    elif re.match("[0-9]+\. Test",  line):

                        if len(output) > 0:
                            output[0] = output[0].replace('.',  ':')
                            items = output[0].split(':')
                            if 'version' in output[0]:
                                testName = items[2].strip() +'('+items[4].strip()
                            else:
                                testName = items[2].strip()
                            testNameLen = len(testName)
                            id = hash(testName)
                            index = self.idIndex[id]
                            self.testCases[index]['Output'] = output
                            output = []
                    output.append(line)
                    pass
                
                elif isError:
                    if line.startswith('------'):
                        if len(error) > 0:
                            error[0] = error[0].replace('.',  ':')
                            items = error[0].split(':')
                            testName = items[2].strip()
                            
                            if 'version' in error[0]:
                                testName += '(' + items[4].strip()
                            testNameLen = len(testName)
                            id = hash(testName)
                            index = self.idIndex[id]
                            # Magic to restore '.' in the version info (like separator in IP address)
                            error[0] = error[0].replace('_','.')
                            self.testCases[index]['Error'] = error
                            error = []
                        isError= False
                        isEpilog = True
                        continue
                    elif re.match("[0-9]+: Test",  line):
                        pass

                        if len(error) > 0:
                            error[0] = error[0].replace('.',  ':')
                            items = error[0].split(':')
                            if 'version' in error[0]:
                                testName = items[2].strip() +'('+items[4].strip()
                            else:
                                testName = items[2].strip()
                            testNameLen = len(testName)
                            id = hash(testName)
                            index = self.idIndex[id]
                            # Magic to restore '.' in the version info (like separator in IP address)
                            error[0] = error[0].replace('_','.')
                            self.testCases[index]['Error'] = error
                            error = []
                    error.append(line)
                    pass
                  
                elif isEpilog:
                    if line.startswith('------'):
                        isEpilog = False
                        isElapsTime= True
                        continue
                        
                    items = line.split(' ')
                    logPath = items[1].strip()
                    pass
                 
                elif isElapsTime:
                    if line.startswith('------'):
                        isElapsTime = False
                        continue
                        
                    items = line.replace('sec ', '').replace('(', '').replace(')','').replace('  ', ' ').split(' ')
                    elapsTimeInSec=int(items[2])
                    elapsTimeStr= items[3]
                    pass
                    
                pass
            except IndexError:
                if len(error) > 0:
                    msg = 'Index Error\n'+'\n'.join(error[1:len(error)]).replace("'",  "")
                    self.LogException( self.target, filename,  lineno,  msg)
                    error=[]
                if isError and line.startswith('------'):
                    isError= False
                    isEpilog = True
                    msg = 'Index Error\nMissed end of error block'
                    self.LogException( self.target, filename,  lineno,  msg)
                pass
            except KeyError:
                msg = 'Key error\n'+str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")"
                msg += ("%s" % ( traceback.print_stack() ))
                self.LogException( self.target, filename,  lineno,  msg)
                pass
            except UnboundLocalError:
                msg = 'UnboundLocalError \n'+str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")"
                msg += ("%s" % ( traceback.print_stack() ))
                self.LogException( self.target, filename,  lineno,  msg)
                pass
            except:
                msg = 'Except\nHmmmm...'+str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")"
                msg += ("%s" % ( traceback.print_stack() ))
                self.LogException( self.target, filename,  lineno,  msg)
            finally:
                pass
                    
        file.close()
        print("End of process.")
    
    
    def ProcessResults(self,  show=False):
        Problems = {}
        def getProblemId(problem,  code,  message,  index):
            problem = problem.rstrip('>')
            code = code.split('>')[1]
            message = message.replace('msg>', '')
            problemId = hash(problem+code)
            if not problemId in Problems:
                Problems[problemId]={'Problem':problem,  'Code':code,  'Result':[]}
            Problems[problemId]['Result'].append({'Index':(index),  'Message':message})
                
            return problemId
                
        def ProcessResult(index,  result):
            lastLine = result[len(result)-1]
            if '<Exception><Code>' in lastLine:
                items = lastLine.lstrip('+').split('<')
                items[6] = items[6].replace('Message','msg')
                problemId = getProblemId(items[1], items[2],  items[6],  index)
                pass
            elif '<Exception><Source>' in lastLine:
                items = lastLine.lstrip('+').split('<')
                items[4] = items[4].replace('Message','msg')
                problemId = getProblemId(items[1], items[2],  items[4],  index)
                pass
            else:
                problemId = None
                diffError=False
                lineIndex = 0
                isEclccReport = False
                eclccMsg = ''
                for line in result:
                    if ('(Warning' in line) and not ('eclcc' in line):
                        items = line.lstrip('+').split('<')
                        items[6] = items[6].replace('Message','msg')
                        problemId = getProblemId(items[1], items[2],  items[6],  index)
                        break
                    elif 'eclcc' in line:
                        isEclccReport = True
                        pass
                    elif isEclccReport and ( ('): warning ' in line) or ('): error ' in line )):
                        eclccMsg += '\n'+line
                        pass
                    elif line.startswith('+Error ') or line.startswith('Error '):
                        items = line.lstrip('+').replace(' (',  ':').replace(')', '').split(':')
                        lineIndex += 1
                        while ( not('exception' in result[lineIndex].lower()) and not('error' in result[lineIndex].lower()) \
                                    and not('abort' in result[lineIndex].lower()) and not('eclcc' in result[lineIndex].lower()) \
                                    and (lineIndex < len(result)-1)):
                            lineIndex += 1
                        msg = items[2] + '\n'.join(result[lineIndex:len(result)]).replace("'",  "")
                        problemId = getProblemId(items[0]+'>', 'code>'+items[1],  'msg>'+msg,  index)
                        break
                    elif line.startswith('+<Exception><Code>') or line.startswith('\'<Exception><Code>'):
                        items = line.lstrip('+').lstrip('\'').split('<')
                        if '/Message>' in items:
                            msgIndex = items.index('/Message>') - 1
                            msg = items[msgIndex].replace('Message','msg')
                        else:
                            msg = 'msg>' + '<'.join(items)
                            
                        problemId = getProblemId(items[1], items[2],  msg,  index)
                        pass
                    elif line.startswith('+<Exception><Source>') or line.startswith('\'<Exception><Source>'):
                        items = line.lstrip('+').lstrip('\'').split('<')
                        items[4] = items[4].replace('Message','msg')
                        problemId = getProblemId(items[1], items[2],  items[4],  index)
                    elif line.startswith('+<Exception>'):
                        pass                        
                    elif line.startswith('+') and not line.startswith('+++'):
                        diffError=True
                        break
                    elif line.startswith('Aborted'):
                        items = line.replace('(','>').replace(')','').split('>')
                        items[1] = items[1].replace('Message','msg')
                        problemId = getProblemId(items[0], "code>-2",  items[1],  index)
                    lineIndex += 1
                    
                if problemId == None:
                    if diffError:
                        # Other problem, e.g.: key doesn't match
                        problemId = getProblemId('Other problem(s)', 'Code>0',  "msg>Result doesn't match to key file",  index)
                    
                    elif isEclccReport:
                        # eclcc reported problem, e.g.: warning
                        problemId = getProblemId('Eclcc problem', 'Code>1',  "msg>" + eclccMsg,  index)
                        
                    elif 'Error' in self.testCases[index]:
                        # We have no info about what happened
                        problemId = getProblemId('Other problem(s)', 'Code>-1',  "msg>Failed without any further info",  index)
            pass
            
        def ReportResult():
            if len(Problems) > 0:
                header= self.targetPrefix + " " + self.target +" failures by category:"
                if show:
                    print(header)
                self.report.append(header)
                self.htmlReport.append('<h3>'+header+'</h3>')
                for problem in Problems:
                    subHeader = Problems[problem]['Problem'] + " code: " + Problems[problem]['Code']
                    self.htmlReport.append('<ul><li><b>'+subHeader+' ( ' + str(len(Problems[problem]['Result']))+' item(s) )</b>')
                    self.htmlReport.append('<table cellspacing="0" cellpadding="2" border="1" bordercolor="#828282">')
                    self.htmlReport.append('<tr style="background-color:#CEE3F6" align="center" ><th>Test case</th><th>Error message</th><th>WUID (link to ZAP file)</th><th>Age day(s)</th><tr>')
                    if show:
                        print("\t" + subHeader)
                    self.report.append("\t"+subHeader+' ( ' + str(len(Problems[problem]['Result']))+' item(s) )')
                    for res in Problems[problem]['Result']:
                        index = res['Index']
                        testId = index + 1;
                        test = self.testCases[index]
                        testName = test['Test']
                        if testName+'-'+self.target in self.knownProblems:
                            today=datetime.strptime(self.logDate, "%y-%m-%d")
                            firstReport= datetime.strptime(self.knownProblems[testName+'-'+self.target]['Date'], "%y-%m-%d")
                            ageDay = (today-firstReport).days
                            age = str(ageDay)
                        else:
                            age = 'New'
                        item = str(testId) +'. ' + testName.ljust(self.maxTestNameLen, ' ') +': ' + res['Message'] + "(WUID: " + test['Wuid'] +")"
                        
                        if 'timeout' in res['Message'].lower():
                            self.timeoutedTests.append(testName) 
                            
                        if show:
                            print("\t\t" + item)
                        self.report.append("\t\t"+item)
                        _msg = res['Message'].replace('\n', '<br>\n')
                        
                        if self.logArchivePath != None:
                            htmlRow =  '<tr><td>' + ("%d. ") % (testId) + test['Test']+'</td><td>' + _msg+'</td><td>'
                            if 'No_ZAP' in test['ZAPfile']:
                                htmlRow += 'No ZAP file generated.' +'</td>'
                            else:
                                htmlRow += '<a href="' + self.logArchivePath + '/' + test['ZAPfile'] + '" target="_blank" >' + test['Wuid'] +'</a></td>'
                            htmlRow += '<td align="center">'+age+'</td></tr>'
                        else:
                            htmlRow = '<tr><td>'+("%d. ") % (testId) + test['Test']+'</td><td>' + _msg+'</td><td>' + test['Wuid'] +'</td><td align="center">'+age+'</td></tr>'
                            
                        self.htmlReport.append(htmlRow)

                        if not testName in self.faultedTestCase:
                                self.faultedTestCase[testName]={}
                        self.faultedTestCase[testName][self.logDate]= {'Target':self.target, 'Problem':Problems[problem]['Problem'],  'Code':Problems[problem]['Code'],  'Msg':res['Message'] }
                        
                    self.htmlReport.append('</table></li><br></ul>')
                    pass
                self.htmlReport.append('<br>')

        print("Start ProcessResults()...")
          
        for index in range(0,  len(self.testCases)):
            test = self.testCases[index]
            if ('Output' in test) or ('Error' in test):
                if 'Output' in test:
                    res = test['Output']
                elif 'Error' in test:
                    res = test['Error']
                ProcessResult(index,  res)
            pass

        # Read the problems if we have them
        self.knownProblems = {}
        try:
            inFile = open(self.knownProblemFileName, "r")
            lineno = 0
            for line in inFile:
                lineno += 1
                items = line.replace('\n','').split(',')
                self.knownProblems[items[0]+'-'+items[4]]={'Test': items[0], 'Date':items[1],  'Problem':items[2],  'Code':items[3],  'Target':items[4]}
        except IOError:
            pass
        except:
            inFile.close()
        finally:
            pass
                         
        ReportResult()
        self.UpdateKnownProblems()
        self.CreateTimeoutedTestList()
        print("End ProcessResults().")

    def GetResult(self):
        return self.report
        
    def SaveResult(self):
        if len(self.report) > 1:
            self.reportFileName = str(os.path.join(self.scriptPath, self.suite+"-"+self.target+"-ErrorReport.txt"))
            outFile = open(self.reportFileName,  "w")
            for line in self.report:
                outFile.write(line+"\n")
            outFile.close()
            
        testCases=[]
        if len(self.testCases) > 0:
            testTimesFileName = str(os.path.join(self.scriptPath, self.suite+'-'+self.target+"-sorted-elapstimes.csv"))
            for test in self.testCases:
                try:
                    testCases.append([test['Test'], int(test['Elapstime'])])
                except ValueError:
                    testCases.append([test['Test'], 0])
                    
                    print("Exception in add elaps time for '%s' (test['Elapstime']='%s') : %s (line: %s)" % (test['Test'], test['Elapstime'], str(sys.exc_info()[0]), str(inspect.stack()[0][2])))
                    print("Exception in user code:")
                    print('-'*60)
                    traceback.print_exc(file=sys.stdout)
                    print('-'*60)
                
            testCases = sorted(testCases,  key=lambda x: x[1],  reverse = True)
            outFile = open(testTimesFileName,  "w")
            for test in testCases:
                outFile.write(test[0]+';'+str(test[1])+"\n")
            outFile.close()
        
    def GetHtmlResult(self):
        return self.htmlReport
    
    def GetFaultedTestCases(self):
        return self.faultedTestCase
    
    def SaveFaultedTestCases(self):
        curTime = time.strftime("%y-%m-%d")
        fileName = "PerformanceSuiteFaultedTestCases-"+curTime+".csv"
        outFile = open(fileName,  "w")
        for test in self.faultedTestCase:
            for logDate in self.logDates:
                line = test
                if logDate in self.faultedTestCase[test]:
                    if logDate in self.faultedTestCase[test]:
                        item = self.faultedTestCase[test][logDate]
                        line += ','+item['Target']+','+ logDate +','+datetime.strptime(logDate, "%y-%m-%d").strftime('%A') +','+item['Problem']+','+item['Code']+','+item['Msg']
                    else:
                        line += ', , , , , , '
                    line += '\n'
                    outFile.write(line)
        outFile.close()
            
        fileName = "PerformanceSuiteFaultedTestCasesByDate-"+curTime+".csv"
        outFile = open(fileName,  "w")
        line = 'Test case'
        for logDate in self.logDates:
            line += ','+logDate+'-'+datetime.strptime(logDate, "%y-%m-%d").strftime('%A')
        outFile.write(line+'\n')    
        
        for test in self.faultedTestCase:
            line = test
            for logDate in self.logDates:
                if logDate in self.faultedTestCase[test]:
                    item = self.faultedTestCase[test][logDate]
                    line += ', 1'
                else:
                    line += ', 0'
            line += '\n'
            outFile.write(line)
        outFile.close()
        
    def UpdateKnownProblems(self):   
        knownProblems = {}
        for test in self.knownProblems:
            if test.endswith('-'+self.target):
                if self.knownProblems[test]['Test'] in self.faultedTestCase:
                    knownProblems[test] = self.knownProblems[test]
            else:
                knownProblems[test] = self.knownProblems[test]
        self.knownProblems = knownProblems
            

        # Add any new
        for test in self.faultedTestCase:
            if self.logDate in self.faultedTestCase[test]:
                if not test+'-'+self.faultedTestCase[test][self.logDate]['Target'] in self.knownProblems:

                    self.knownProblems[test+'-'+self.faultedTestCase[test][self.logDate]['Target']]={'Test': test, 'Date':self.logDate,  'Problem':self.faultedTestCase[test][self.logDate]['Problem'],  'Code':self.faultedTestCase[test][self.logDate]['Code'],  'Target':self.faultedTestCase[test][self.logDate]['Target']}
        
        outFile = open(self.knownProblemFileName,  "w")
        for test in self.knownProblems:
            line = self.knownProblems[test]['Test']+','+self.knownProblems[test]['Date']+','+self.knownProblems[test]['Problem']+','+self.knownProblems[test]['Code']+','+self.knownProblems[test]['Target']
            line += '\n'
            outFile.write(line)
        outFile.close()
        
    def CreateTimeoutedTestList(self):
        outFile = open(self.timeoutedTestName,  "w")
        for test in self.timeoutedTests:
            line = test + '\n'
            outFile.write(line)
        outFile.close()
#
#-------------------------------------------
# Main
if __name__ == '__main__':
    print("Start...")

    suite = 'Regression'
    mode = 8
    files = []
    path = './Perftest/'
    if mode == 1:
        path = './Perftest2/'
        suite = 'Performance'
    elif mode == 2:
        path = '/home/ati/shared/OBT-perf-logs/roxie/'
        suite = 'Performance'
    elif mode == 3:
        path = './Regression/'
    elif mode == 4:
        path = './Chris/'
    elif mode == 5:
        path = '/home/ati/HPCCSystems-regression/log/'

    elif mode == 6:
        path = '/home/ati/shared/OBT-build-bin/HPCCSystems-log-archive/Extracts/log/'
    elif mode == 7:
        path = '/home/ati/shared/Chris\' results/candidate-5.2.0rc3remote4node/'
    elif mode == 8:
        path = '/home/ati/tmount/data2/nightly_builds/HPCC/master/2017-11-22/CentOS_release_6_9/CE/platform/test/'
        files = [
                    path+'thor.17-11-22-01-45-05.log'
                ]
    elif mode == 9:
        files = [
                    path+'hthor.15-12-08-02-27-19.log',
                    path+'thor.15-12-08-05-59-47.log',
                    path+'roxie.17-11-22-01-52-49.log'
                ]
                
    if len(files) == 0:
        files = glob.glob(path+'*.log')
        
    files.sort()
    filenames =[]
    for file in files:
        if  not '-exclusion' in file:
            filenames.append(file)
            
    rlp = RegressionLogProcessor(None,  suite)

    for filename in filenames:
        fullPath = filename
        print("Logfile: "+fullPath)
        rlp.ProcessFile(fullPath)
        rlp.setLogArchivePath(path +  "test/ZAP")
        rlp.ProcessResults(True)
        result=rlp.GetResult()
        rlp.SaveResult()
        result=rlp.GetHtmlResult()
        print(result)
        pass

    result = rlp.GetFaultedTestCases()
    pass
    rlp.SaveFaultedTestCases()
    print("End.")    
