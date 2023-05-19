#!/bin/python3.5 
# --------------
# This script uses ovm-bkp tool for backup of VM hosted in OVMM cluster
# --------------

import os
import logging, logging.handlers
import time
from time import gmtime, strftime, sleep
import datetime
import socket
import sys
import subprocess
import getpass
import pwd
import argparse 
import smtplib
from email.mime.text import MIMEText

# logging destination
PROGRAM = os.path.basename(sys.argv[0])   # name of this script
LOG_PATH = ("/var/log/" + PROGRAM)        # put together "/var/log/"
if not os.path.exists(LOG_PATH):          # create LOG_PATH if doesn't exists
    os.makedirs(LOG_PATH)
    os.chown(LOG_PATH,-1,10)       # root(-1 means no change):staff linux group
    os.chmod(LOG_PATH,0o775)               # drwxrwxr-x

parser = argparse.ArgumentParser(
         description="Backup OVMM VM") 
parser.add_argument("-v", "--vm", help="VM to backup", required=True)
args = parser.parse_args()
vm=args.vm


# --- Define logging
LOG_FILE = (LOG_PATH + "/" + datetime.datetime.now().strftime("%m-%d-%Y_%Hh%Mm%Ss"))
# create logger (interface that script uses for logging)
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
# create file handler (define log destination)
handler = logging.handlers.TimedRotatingFileHandler(LOG_FILE, when='MIDNIGHT', backupCount=50, utc=False) 
# create formatter (define layout of logs)
formatter = logging.Formatter('%(asctime)s:%(levelname)s: %(message)s')
handler.setFormatter(formatter)
# add handler to logger
logger.addHandler(handler)

logger.debug("")
logger.debug("START AT : " + strftime("%a, %d %b %Y %H:%M:%S", gmtime()))


i_am=getpass.getuser()
if i_am != "root":
    logger.debug("Only Root can run this")
    sys.exit("Only Root can run this")

def email_err(body):
    """
    Send email with an error
    """
    message = MIMEText(body)
    message['Subject'] = socket.gethostname() + ": problem with ovmm vm backup"
    fromaddr = 'from@someone'
    toaddr = 'to@someone'

    try:
        logger.debug("Sending email with " + body)
        email_object = smtplib.SMTP(host="some-smtp-host")
        email_object.sendmail(fromaddr, toaddr, message.as_string())
    except SMTPException as err:
        logger.debug("SMTPException {0}" .format(err) + " Can't send email")
        sys.exit("SMTPException {0}" .format(err) + " Can't send email")

def is_vm_configured():
    """
    Check if VM is configured ,
    it has to be configured first with info like retention and target repo
    """
    logger.debug("Checking if " + vm + " has backup configuration.")
    try:
        subprocess.check_call(['/opt/ovm-bkp/bin/ovm-listbackup.sh', '{0}' .format(vm)], stdout=subprocess.DEVNULL) #output to /dev/null
        #subprocess.check_call(['/opt/ovm-bkp/bin/ovm-listbackup.sh', '%s' % vm], stdout=subprocess.DEVNULL) #python2
        logger.debug("OK: The VM " + vm + " has backup configuration, continues.")
    except:
        logger.debug("WARNING: The VM " + vm + " does not have backup configuration.")
        email_err("WARNING: The VM " + vm + " does not have backup configuration.")
        sys.exit("WARNING: The VM " + vm + " does not have backup configuration.")

def start_backup():
    """
    Start backup, using: 
    /opt/ovm-bkp/bin/ovm-backup.sh vm-name FULL n
    """
    logger.debug("Starting full backup of " + vm )
    try:
        subprocess.check_call(['/opt/ovm-bkp/bin/ovm-backup.sh {0} FULL n' .format(vm)], shell=True, stdout=subprocess.DEVNULL) 
        #subprocess.check_call(['/opt/ovm-bkp/bin/ovm-backup.sh', '{0}', 'FULL', 'n' .format(vm)], shell=True, stdout=subprocess.DEVNULL) 
        logger.debug("OK: backup of " + vm + " was successful, logs are in /opt/ovm-bkp/logs/")
    except:
        logger.debug("WARNING: backup of " + vm + " has failed.")
        email_err("WARNING: backup of " + vm + " has failed.")
        sys.exit("WARNING: backup of " + vm + " has failed.")

def list_backup():
    """
    List backup of VM, and show in logs
    """
    logger.debug("Listing backups of " + vm )
    try:
        with open(LOG_FILE, "a") as logfile:
            subprocess.Popen(['/opt/ovm-bkp/bin/ovm-listbackup.sh', '{0}' .format(vm)], stdout=logfile) 
    except:
        logger.debug("WARNING: can't list backup of " + vm)
        email_err("WARNING: can't list backup of " + vm)
        sys.exit("WARNING: can't list backup of " + vm)


if __name__ == '__main__':

    is_vm_configured() 
    start_backup()
    list_backup()
    time.sleep(15) # wait 15sec for bkp listing to finish

    logger.debug("FINISH AT : " + strftime("%a, %d %b %Y %H:%M:%S", gmtime()))

sys.exit(0)


