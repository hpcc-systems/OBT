#!/usr/bin/env python3

import os
import sys
import inspect
import traceback
import smtplib
import configparser
import datetime

from email.mime.multipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders

msgText = MIMEMultipart() 

class BuildNotificationConfig( object ):

   def __init__(self, buildDate = '', iniFile = 'sendemail.ini'):
       self._buildDate = buildDate 
       self.config = configparser.ConfigParser()
       self.config.read( iniFile )

   def get( self, section, key ):
      try:
         return self.config.get( section, key )
      except: 
         return None 
         
def createMsg(config):
    curDir = os.getcwd()

    tests = config.get( 'Performance', 'TestList' ) .split(',')
    msgText['From'] = config.get( 'Email', 'Sender')
    msgText['To']     = config.get( 'Email', 'Receivers')
    msgText['Subject'] = "Performance Test Result on "+datetime.date.today().strftime("%Y-%m-%d")
    
    msgText.attach( MIMEText('Hello\n\n\nHere are the performance test results for:\n  - ' + '\n  - '.join(tests) + '\n cluster(s).\n\nRegards\nPerformace Test\n'))

    for test in tests:
        file = test + "-performance-test.log" 
        print(file)
    try:
            temp = open(file).readlines( )
            part = MIMEBase('application', 'octet-stream')
            part.set_payload( '\n'.join(temp))
            Encoders.encode_base64(part)
            part.add_header('Content-Disposition', 'attachment; filename="%s"' % file)
            msgText.attach(part)
    except:
            print(("Unexpected error:" + str(sys.exc_info()[0]) + " (line: " + str(inspect.stack()[0][2]) + ")" ))
            traceback.print_stack()
            pass
    finally:
        pass

    os.chdir( curDir ) 

    pass

def send(config): 
       fromaddr= config.get( 'Email', 'Sender' )
       toList = config.get( 'Email', 'Receivers' ).split(',')
       server = config.get( 'Email', 'SMTPServer' )

       try:
            smtpObj = smtplib.SMTP( server, 25 )
            smtpObj.set_debuglevel(99)
            smtpObj.sendmail( fromaddr, toList, msgText.as_string() )
       except smtplib.SMTPException:
           print( "Error: unable to send email" )
       
       smtpObj.quit()

if __name__ == "__main__":
        traceback.print_stack()
        config = BuildNotificationConfig() 
        createMsg(config)
        send(config)

