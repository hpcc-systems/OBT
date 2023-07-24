#!/usr/bin/env python3

import sys
import linecache
from datetime import date, timedelta

def PrintException(msg = ''):
    exc_type, exc_obj, tb = sys.exc_info()
    f = tb.tb_frame
    lineno = tb.tb_lineno
    filename = f.f_code.co_filename
    linecache.checkcache(filename)
    line = linecache.getline(filename, lineno, f.f_globals)
    print('EXCEPTION IN (%s, LINE %s CODE:"%s"): %s' % ( filename, lineno, line.strip(), msg))
    
def printHistory(rtch):
    print('---------------------------------------')
    print(rtch.getHistoryTable())
    print('---------------------------------------\n')
    print(rtch.getHistoryHtml())
    print('---------------------------------------')
    

class ReportedTestCasesHistory(object):
    
    types = { 'Bad':'B',  'Ugly':'U', 'Ugly and Bad':'BU', 'Good':'G', 'Neutral':'N' }
    states = {'True':'Known',  'False':'Active'}
    cellColors = { 'Known'  : { 'B': '#80ff80', 'U':'#80ff80', 'BU' : '#80ff80', 'G' : '#80ff80', 'N': '#ffffff'},
                   'Active' : { 'B': '#ff8080', 'U':'#ffff80', 'BU' : '#ff8080', 'G' : '#80ff80', 'N': '#ffffff'}
                 }

    def __init__(self,  inFileName, numberOfDaysUsed = 7,  verbose = False):
        self.inFileName = inFileName
        self.history = {}
        self.testNames = []
        self.historyTable = []
        self.historyTableHeader = []
        self.historyTableHtml = ''
        
        self.numberOfDaysUsed = numberOfDaysUsed
        self.today = date.today()
        self.oldestDay = self.today
        if self.numberOfDaysUsed == -1:
            delta = timedelta(0)
        else:
            delta = timedelta(self.numberOfDaysUsed)
        self.borderDay = self.today - delta
        self.newestDay = self.borderDay

        self.statsHistory = { 'testNum' : 0, 'Bad': 0,  'Ugly': 0, 'Ugly and Bad': 0, 'Good': 0, 'Neutral' : 0, 'Known': 0, 'Active': 0}
        self.stats = { 'testNum' : 0, 'Bad': 0,  'Ugly': 0, 'Ugly and Bad': 0, 'Good': 0, 'Neutral' : 0, 'Known': 0, 'Active': 0}
    
        self.verbose = verbose
        pass
      
    def dateIsInRange(self,  inDate):
        if self.numberOfDaysUsed == -1:
            # use all of them
            return True
            
        year = int(inDate[0:4])
        month = int(inDate[5:7])
        day = int(inDate[8:])
        checkDate = date(year,  month,  day)
        today = date.today()
        delta = timedelta(self.numberOfDaysUsed)
        borderDay = today - delta
        retVal = checkDate > borderDay
        if retVal:
            if checkDate < self.oldestDay:
                self.oldestDay = checkDate
            elif checkDate > self.newestDay:
                self.newestDay = checkDate;
        pass
        return retVal
        
    def wrapText(self, text, sep = '-', maxlen = 50, html = True):
        wrapTestName = text
        if len(text) > maxlen:
            testNameItems = text.split(sep)
            wrapTestName = ''
            partSize = 0
            for index in range (len(testNameItems)):
                partSize += len(testNameItems[index])
                wrapTestName += testNameItems[index] + sep
                if partSize > maxlen:
                    partSize = 0
                    if html:
                        wrapTestName += '<br>'                        
                    wrapTestName += '\n'
                    
        return wrapTestName.strip(sep)
                    
    def grouped(self, iterable, n):
        "s -> (s0,s1,s2,...sn-1), (sn,sn+1,sn+2,...s2n-1), (s2n,s2n+1,s2n+2,...s3n-1), ..."
        return zip(*[iter(iterable)]*n)
         
    def readFile(self):
        file = None
        try:
            file = open(self.inFileName, 'r')
            lineno = 0
            for line in file:
                lineno += 1
                line = line.strip().strip('\'').replace('\n', '')
                if len(line) == 0:
                    continue
                items = line.split(',')
                
                if not self.dateIsInRange(items[0]):
                    continue
                    
                currentDate = items[0]
                if currentDate not in self.history:
                    self.history[currentDate] = {}
                    
                for name, target, type, status in self.grouped(items[1:], 4):
                    #print "%s, %s, %s, %s" % (name, target, type, status)
                    # Collect the tests by the date and target to distinct 
                    # if same test becomes problematic on different target 
                    if name not in self.history[currentDate]:
                        self.history[currentDate][name] = {}
                        
                    if target not in self.history[currentDate][name]:
                        self.history[currentDate][name][target]={'type':type, 'status': status }
                        
                    # Create uniq test id from test name and target
                    id = name + '#' + target
                    if id not in self.testNames:
                        self.testNames.append(id)
        except Exception as e:
            PrintException(repr(e))
        finally:
            if file != None:
                file.close()
        
        lastDay = str(self.newestDay)
        if lastDay in self.history:
            for test in self.history[lastDay]:
                for target in self.history[lastDay][test]:
                    type = self.history[lastDay][test][target]['type']
                    self.statsHistory[type] += 1
                    status = self.history[lastDay][test][target]['status']
                    if status == 'True':
                        self.statsHistory['Known'] += 1
                    else:
                        self.statsHistory['Active'] += 1
                    self.statsHistory['testNum'] += 1
                    
        self.testNames = sorted(self.testNames)
        if self.verbose:
            print(self.testNames)
            for actDate in sorted(self.history):
                print (actDate)
                print(sorted(self.history[actDate]))
            
            print("Oldest day: %s, newest days : %s" % (str(self.oldestDay), str(self.newestDay)) )
        
    def buildHistoryTable(self,  imagePath = None):
        if self.numberOfDaysUsed == -1:
            dayNumStr = 'all available (' + str(len(self.history)) + ')'
        else:
            dayNumStr = 'the last ' + str(len(self.history))
            
        if imagePath != None and not imagePath.endswith('/'):
            imagePath += '/'
               
        historyTableHtml = '<TABLE border=\"1\" bordercolor=\"#828282\">\n'
        historyTableHtml += '  <TR style=\"background-color:#CEE3F6\">\n'
        historyTableHtml += '    <TH>No</TH>\n'
        historyTableHtml += '    <TH>Testname</TH>\n'
        
        self.historyTableHeader = 'testname, '
        for actDate in sorted(self.history):
            self.historyTableHeader += actDate + ', '
            historyTableHtml += '    <TH align=\"center\">' + actDate + '</TH>\n'
            
        historyTableHtml += '  </TR>\n'
        
        for id in self.testNames:
            (test,  target) = id.split('#')
            historyTableLine = test + ', '
            
            historyTableRowHtml = '  <TR>\n'
            historyTableRowHtml += '    <TD align="right">'+ str(self.stats['testNum']+1) + '. </TD>\n'
            if imagePath == None:
                historyTableRowHtml += '    <TD>'  + self.wrapText(test, '-') + '</TD>\n'
            else:
                historyTableRowHtml += '    <TD><a href=\"' + imagePath + target + '/' + test + '-' + target + '-' + str(self.newestDay).replace('-','')[2:] + '.png\" target=\"_blank\">'+ self.wrapText(test, '-') + '</a></TD>\n'
                    
            for actDate in sorted(self.history):
                if (test in self.history[actDate]) and (target in self.history[actDate][test]):
                    type = self.types[self.history[actDate][test][target]['type']]
                    state = self.states[self.history[actDate][test][target]['status']]
                    historyTableCellValue = (("%2s/%1s/%s") % ( type, state, target ))
                    historyTableLine += historyTableCellValue + ', '
                    historyTableCellColor = self.cellColors[state][type]
                    historyTableRowHtml += '    <TD align=\"center\" bgcolor=\"' + historyTableCellColor + '\">' + historyTableCellValue + '</TD>\n'
                else:
                    historyTableCellValue = (("%2s/%1s/%s") % (  "-", "-", "-" ))
                    historyTableLine += historyTableCellValue + ', '
                    historyTableCellColor = '#ffffff'
                    historyTableRowHtml += '    <TD align=\"center\" bgcolor=\"' + historyTableCellColor + '\">' + historyTableCellValue + '</TD>\n'
                    
            historyTableRowHtml += '  </TR>\n'
            self.historyTable.append(historyTableLine)
            historyTableHtml += historyTableRowHtml
            # Process the last day
            type = '''
            state = '''
            try:
                type = self.history[actDate][test][target]['type']
                self.stats[type] += 1
                state = self.states[self.history[actDate][test][target]['status']]
                self.stats[state] +=1
            except Exception as e:
                self.stats['Neutral'] += 1
                PrintException(repr(e)+" On %s the test: %s did not reported in engine: %s." % (actDate, test, target ))
                pass
               
            self.stats['testNum'] += 1
            
        self.historyTable.append('\nLegend:')
        self.historyTable.append('"U": Ugly, "B": Bad, "BU": Bad and Ugly, "A": Active problem, "K": Known problem, "-/-/-": Not seen before or eliminated problem\n')
        
        historyTableHtml += '</TABLE><BR>\n'
        
        testNumStr = str(self.stats['testNum'])
        historyTableTitleHtml = '<H3>Changed  test cases (' + testNumStr + ') history from '+ dayNumStr +' days</H3>\n'
        historyTableTitleHtml += '<b>Today there are ' + str(self.stats['Good']) + ' good, ' + str(self.stats['Bad']) + ' bad, ' + str(self.stats['Ugly']) +' ugly, ' + str(self.stats['Ugly and Bad']) + ' bad & ugly and ' + str(self.stats['Neutral']) +' neutral results.</b>\n'
        historyTableTitleHtml += '<b>' + str(self.statsHistory['Known']) + ' known issues </b><BR><BR>\n'
        if imagePath != None:
            historyTableTitleHtml += '<b>Click on the test case name to see related diagram (VPN connection needed)</b><BR>\n'
        
        self.historyTableHtml = historyTableTitleHtml + historyTableHtml
        self.historyTableHtml += '<B>Legend:</B><BR>\n'
        self.historyTableHtml += '<UL>\n'
        self.historyTableHtml += '  <LI>"B": Bad</LI>\n'
        self.historyTableHtml += '  <LI>"U": Ugly</LI>\n'
        self.historyTableHtml += '  <LI>"BU": Bad and Ugly</LI>\n'
        self.historyTableHtml += '  <LI>"G": Good - improved</LI>\n'
        self.historyTableHtml += '  <LI>"A": Active problem</LI>\n'
        self.historyTableHtml += '  <LI>"K": Known problem</LI>\n'
        self.historyTableHtml += '  <LI>"-/-/-": Not seen before or eliminated problem</LI>\n'
        self.historyTableHtml += '</UL><BR>\n'
        
        if self.verbose:
            print("\n")
            print(self.historyTableHeader)
            print(self.historyTable)
        pass
        
    def getHistoryTable(self):
        retVal = self.historyTableHeader + '\n'
        retVal += "\n".join(self.historyTable)
        return retVal
        pass
        
    def getHistoryHtml(self):
        return self.historyTableHtml
        pass
        
    def getStats(self):
        return self.stats
        pass
        
    def updateHistoryFile(self, newDate, newRecord,  forceRebuild=False):
        # Only append allowed
        year = int(newDate[0:4])
        month = int(newDate[5:7])
        day = int(newDate[8:])
        checkDate = date(year,  month,  day)
        try:
            lines = open(self.inFileName, 'r').readlines()
            lastDateStr = lines[-1][0:10]
            lastDateYear = int(lastDateStr[0:4])
            lastDateMonth = int(lastDateStr[5:7])
            lastDateDay = int(lastDateStr[8:])
            lastDate = date(lastDateYear,  lastDateMonth,  lastDateDay)
        except:
            lines = []
            lastDate = checkDate + timedelta(days = -1)
            
        updated = False

        if checkDate > lastDate:
            lines.append(newDate+',' + newRecord)
            updated = True
        elif checkDate == lastDate:
            lines[-1] = newDate+',' + newRecord
            updated = True
        
        if updated:
            file = open(self.inFileName, 'w')
            for line in lines:
                if len(line)>2:
                    file.write(line.strip('\n') + '\n')
            file.close()
            
        if forceRebuild:
            # re-read data
            self.readFile()
            self.buildHistoryTable()
        pass
#
#-------------------------------------------
# Main

if __name__ == '__main__':
    print("Start...")

    path = '.'
    fileName = "PerformanceIssues-test.csv"

    # Test with explicit muber of days
    rtch = ReportedTestCasesHistory(fileName,  5,  True)
    rtch.readFile()
    rtch.buildHistoryTable('http://10.241.40.12/common/nightly_builds/HPCC/master/2018-07-23/CentOS_Linux_7/CE/platform/test/diagrams')
    printHistory(rtch)
    
    # Test with use all days data
#    rtch = ReportedTestCasesHistory(fileName,  -1)
#    rtch.readFile()
#    rtch.buildHistoryTable()
#    print('---------------------------------------')
#    print(rtch.getHistoryHtml())
#    print('---------------------------------------')

    # Test with default number (7) of days data
    rtch = ReportedTestCasesHistory(fileName)
    rtch.readFile()
    rtch.buildHistoryTable()
    printHistory(rtch)
    
    # Add a new record
#    newDate= "2018-07-26"
#    newRecord = "02bh_dup3sort,thor,Bad,False,02cb_multisort16local,thor,Bad,False,02ea_smallsorts-algo('parquicksort'),roxie,Bad,False,02eb_smallsorts2-algo('parquicksort')-numrows(2000),roxie,Bad,False,04ad_join1l,thor,Bad,False,04cd_join64l,thor,Ugly,False,04cf_join64s,thor,Ugly,False,04dd_join4kl,thor,Ugly,True,04ef_joinl1s,thor,Bad,False,07ba_keyedjoin321a,thor,Bad,False,07ca_keyedjoinlimit_no,thor,Bad,False,11dc_localsmartjoin_nosort_sp,thor,Bad,False"
#    rtch.updateHistoryFile(newDate, newRecord)
#    
#    print('---------------------------------------')
#    print(rtch.getHistoryTable())
#    print('---------------------------------------')
#    print(rtch.getHistoryHtml())
#    print('---------------------------------------')
    
    print("End")
    
