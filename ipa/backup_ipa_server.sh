#!/bin/bash

# IPA server backup

START_TIME=`date +%s`
HOSTNAME=`hostname -s`
LOGDATE=`date +%m.%d.%Y_%H:%M`
progname=`basename $0| sed 's/^9//'`
readonly BACKUP_PATH=/var/lib/ipa/backup
readonly LOG_PATH=/var/log/backup_ipa_server
readonly LOGFILE=$LOG_PATH/${progname}.${LOGDATE}.log
readonly DAYS_TO_KEEP_LOGS=30
readonly DAYS_TO_KEEP_BACKUPS=30
WHO_CARES="
your@e-mail \
"

readonly loggerinfo="logger -t "${progname}" Info:"
readonly loggerwarning="logger -t "${progname}" Warning:"
readonly loggerproblem="logger -t "${progname}" Problem:"

${loggerinfo} ==== Start at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ===

err() {
        echo ; echo "Problem: $*" ; echo
        ${loggerproblem} "$*"
        echo "$*" | mail -s "Problem ${HOSTNAME}:${progname}" ${WHO_CARES}
        ${loggerinfo} ======== Finish at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ====
        exit 1
}

# removing old logs
old_log_removal(){
test -d $LOG_PATH || mkdir -p $LOG_PATH
echo "Removing old logs:"
echo "-------------------"
find $LOG_PATH \
  -type f \
  -name "*.log" \
  -mtime +$DAYS_TO_KEEP_LOGS \
  -exec rm -rvf {} \;
}

# removing old backup directories, using -prune
old_backup_removal(){
echo "Removing old backups directories:"
echo "--------------------------------"
find $BACKUP_PATH \
  -type d \
  -name "ipa-data-*" -prune \
  -mtime +$DAYS_TO_KEEP_BACKUPS \
  -exec rm -rvf {} \;
}

completed_time(){
# Function needs to be passed the started time `date +%s` as $1
if [ -z "$1" ] ; then
   ${loggerproblem} "
  Output of \`date +%s\` needs to be passed as \$1 to completed_time.
  Nothing passed as \$1.
   "
  exit 1
fi
if ! [ "$1" -ge 0 -o "$1" -lt 0 ] >/dev/null 2>&1 ; then
     ${loggerproblem} "
  What was passed as \$1: \"$1\" doesn't seem to be a suitable integer.
  Output of \`date +%s\` needs to be passed as \$1 to completed_time.
     "
  exit 1
fi
date +%s| awk -vstart_sec=$1 \
  '{tot_e_secs=($1-start_sec);
     e_hrs=int(tot_e_secs/3600);
     e_mins=int((tot_e_secs%3600)/60);
     e_secs=int(tot_e_secs%60);
     printf "%14s %2s %1s %2s %1s %2s %1s\n",
     "COMPLETED IN:",e_hrs,"h ",e_mins,"m ",e_secs,"s"
   }'
}

## MAIN ####
(
old_log_removal
old_backup_removal
echo Performing IPA server backup 
echo "----------------------------" 
/sbin/ipa-backup --verbose --data --online || err "There is problem with ipa-backup, investigate"
echo ; echo " `completed_time $START_TIME` "
) > $LOGFILE 2>&1

${loggerinfo} ===== Finish at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ====

exit 0


