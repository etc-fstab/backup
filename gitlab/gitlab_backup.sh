#!/bin/bash
#
# GitLab backup
# -----------------------------------------------
# NOTE: our gitlab is Omnibus one, not via source !
# -----------------------------------------------
# https://about.gitlab.com/installation/#centos-7
# https://docs.gitlab.com/omnibus/
#

START_TIME=`date +%s`
HOSTNAME=`hostname -s`
LOGDATE=`date +%m.%d.%Y_%H:%M`
progname=`basename $0| sed 's/^9//'`
readonly GITLABCONF=/etc/gitlab
readonly BACKUP_PATH=/git/backups
readonly LOG_PATH=/var/log/gitlab-backup
readonly LOGFILE=$LOG_PATH/${progname}.${LOGDATE}.log

# gitlab conf is 7 days backup retention
# see /etc/gitlab/gitlab.rb
# gitlab_rails['backup_keep_time'] = 604800 (in sec)
readonly DAYS_TO_KEEP_LOGS=7
readonly DAYS_TO_KEEP_CONFBACKUPS=7

who_cares="
your@e-mail \
"

readonly loggerinfo="logger -t "${progname}" Info:"
readonly loggerwarning="logger -t "${progname}" Warning:"
readonly loggerproblem="logger -t "${progname}" Problem:"

${loggerinfo} ==== Start at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ===

err() {
        echo ; echo "Problem: $*" ; echo
        ${loggerproblem} "$*"
        echo "$*" | mail -s "Problem from ${HOSTNAME}:${progname}" ${who_cares}
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

# NOTE: gitlab backup retention is configured within gitlab, nothing via script

# removing old configuration backup
old_confbackup_removal(){
echo "Removing old GitLab configuration backups:"
echo "-----------------------------------------"
find ${BACKUP_PATH} \
  -type f \
  -name "etc-gitlab_*.tar" \
  -mtime +${DAYS_TO_KEEP_CONFBACKUPS} \
  -exec rm -rvf {} \;
}

# calculate execution time, from one John 
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
old_confbackup_removal
echo Performing GitLab backup
echo "----------------------------"
/bin/gitlab-rake gitlab:backup:create STRATEGY=copy SKIP=repositories \
 || err "There is problem with GitLab backup, investigate"
echo Archiving GitLab config files
echo "----------------------------"
tar -cvf ${BACKUP_PATH}/$(date "+etc-gitlab_%m.%d.%Y_%H_%M.tar") ${GITLABCONF}
echo ; echo " `completed_time $START_TIME` "
) > $LOGFILE 2>&1

${loggerinfo} ===== Finish at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ====

exit 0


