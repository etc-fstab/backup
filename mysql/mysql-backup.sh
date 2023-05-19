#!/bin/sh

progname=`/bin/basename $0`
loggerinfo="logger -t "${progname}" Info:"
loggerwarning="logger -t "${progname}" Warning:"
loggerproblem="logger -t "${progname}" Problem:"

${loggerinfo} ======== Start at `date +'%Y-%m-%dT%H-%M-%S_%Z'` =====

START_TIME=`date +%s`
HOSTNAME=`hostname -s`
LOGDATE=`date +%m.%d.%Y_%H:%M`
SCRIPT_NAME=`basename $0| sed 's/^9//'`
LOG_PATH=/var/log/${SCRIPT_NAME}
LOGFILE=${LOG_PATH}/${SCRIPT_NAME}.${LOGDATE}.log
DAYS_TO_KEEP_LOGS=10
DAYS_TO_KEEP_DUMPS=10
WHO_CARES="\
some-email@domain.com \
"
SUFFIX=`date +%Y-%m-%d_%H:%M`
# mysql password should be taken from /root/.my.cnf
HOME=/root
HOSTNAME=`hostname`
USER=root
HOME=/root
LOGNAME=root

readonly DBHOST="localhost"
# performance_schema is virtual db, no need to backup
# https://dev.mysql.com/doc/refman/5.5/en/performance-schema.html
readonly DBS=`mysql -h${DBHOST} -e"show databases" | awk -F\| '!/^Database$/&&!/---/{print $1}' | grep -v performance_schema`

BACKUPDIR="/some-backup-location"

### checkLogPath
checkLogPath(){
test -d ${LOG_PATH} || mkdir -p ${LOG_PATH}
echo "
Removing old logs :
`find /var/log/${SCRIPT_NAME}/ -type f  -name "*.log" -mtime +${DAYS_TO_KEEP_LOGS} -print`
"
find /var/log/${SCRIPT_NAME}/ \
  -type f \
  -name "*.log" \
  -mtime +${DAYS_TO_KEEP_LOGS} \
  -exec rm -rf {} \;
}

### cleanOldDumps
cleanOldDumps(){
for data_base in ${DBS}
do
echo "
Removing old dumps for database ${data_base}:
`find ${BACKUPDIR}/${data_base} -type f -name "*-mysql-*.gz" -mtime +${DAYS_TO_KEEP_DUMPS} -print`
"
find ${BACKUPDIR}/${data_base} \
  -type f \
  -name "*-mysql-*.gz" \
  -mtime +${DAYS_TO_KEEP_DUMPS} \
  -exec rm -rf {} \;
done
}

### echoElapsedTime, by John from Oracle
echoElapsedTime(){

# Function needs to be passed the started time `date +%s` as $1
if [ -z "$1" ] ; then
   echo "
  Output of \`date +%s\` needs to be passed as \$1 to echoElapsedTime.
  Nothing passed as \$1.
   "
   exit 1
fi
if ! [ "$1" -ge 0 -o "$1" -lt 0 ] >/dev/null 2>&1 ; then
     echo "
  What was passed as \$1: \"$1\" doesn't seem to be a suitable integer.
  Output of \`date +%s\` needs to be passed as \$1 to echoElapsedTime.
     "
     exit 1
fi
date +%s| awk -vstart_sec=$1 \
  '{tot_e_secs=($1-start_sec);
     e_hrs=int(tot_e_secs/3600);
     e_mins=int((tot_e_secs%3600)/60);
     e_secs=int(tot_e_secs%60);
     #printf "%12s %2s %6s %2s %8s %2s %7s\n",
     printf "%14s %2s %1s %2s %1s %2s %1s\n",
     #"Time elapsed:",e_hrs,"hours,",e_mins,"minutes,",e_secs,"seconds"
     "COMPLETED IN:",e_hrs,"h ",e_mins,"m ",e_secs,"s"
     #"COMPLETED IN:",e_hrs,"h,",e_mins,"m,",e_secs,"s"
   }'
}

### MAIN ###
(

checkLogPath

for data_base in ${DBS}
do
  dump_name=""
  test -d ${BACKUPDIR}/${data_base} || mkdir -p ${BACKUPDIR}/${data_base}
  dump_name=${SUFFIX}-mysql-${data_base}.gz
  echo DUMPING database ${data_base} into file ${dump_name}
  mysqldump -h${DBHOST} --single-transaction --events --opt ${data_base} | \
    gzip --best > ${BACKUPDIR}/${data_base}/${dump_name}
done

backups_done=`find ${BACKUPDIR} -name "${SUFFIX}-mysql-*.gz"`
if [ -z "${backups_done}" ] ; then
   echo "${HOSTNAME} problem with backup ${SCRIPT_NAME}"| \
     mail -s "${HOSTNAME} problem with backup ${SCRIPT_NAME}" \
     ${WHO_CARES}
   exit 1
fi

cleanOldDumps

echo " `echoElapsedTime ${START_TIME}` "
) > ${LOGFILE} 2>&1
${loggerinfo} ======== Finish at `date +'%Y-%m-%dT%H-%M-%S_%Z'` ======
exit 0


