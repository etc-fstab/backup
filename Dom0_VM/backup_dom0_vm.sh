#!/bin/env bash

# backup a VM in standalone Dom0, 
# argument 1 = VM
# argument 2 = retention in counts
# argumet 3 = backup path, likely /import/something
# Conditions:
# VM disk image must be Dom0:/OVS/${vm}/${vm}.img
# VM cfg must be Dom0:/OVS/${vm}/${vm}.cfg
# -----------------------------------------------------

PROGNAME=`basename $0`
LOGDATE=`date +'%Y%m%d-%H%M'`
#LOGDATE=`date +%Y-%m-%d_%H_%M`
LOG_PATH="/var/log/`basename ${PROGNAME}`"
[ -d /var/log/`basename ${PROGNAME}` ] || mkdir /var/log/`basename ${PROGNAME}`
LOGFILE=${LOG_PATH}/${LOGDATE}.log
#
readonly loggerinfo="logger -t "${PROGNAME}" Info:"
readonly loggerwarning="logger -t "${PROGNAME}" Warning:"
readonly loggerproblem="logger -t "${PROGNAME}" Problem:"
#
who_cares="
your@e-mail \
"

err() {
   echo ; echo "Problem: $*" ; echo
   ${loggerproblem} "$*"
   echo "$*" | mail -s "Problem from `hostname`:${PROGNAME}" ${who_cares}
   exit 1
}

usage() {
  clear
  echo "
  Usage: ${PROGNAME}   

  Conditions:
  VM disk image must be Dom0:/OVS/<VM>/<VM>.img
  VM cfg must be Dom0:/OVS/<VM>/<VM>.cfg
  "
  exit 1
}

# must be three arguments
if [ $# -ne 3 ]; then
 usage 
fi

# impots and their checks
vm=$1
counts=$2
bkpath=$3

chk_vm() {
    /usr/sbin/xm list ${vm}  >/dev/null
    [[ $? -ne 0 ]] && err "VM ${vm} doesn't exist."
}

get_snapshot() {
    echo ; echo "Getting snapshot (using reflink) of /OVS/${vm}/${vm}.img"
    reflink /OVS/${vm}/${vm}.img  /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE} || \
    err "Can't get snapshot (using reflink) of /OVS/${vm}/${vm}.img"
    echo "Snapshot is /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE}"
}

backup_snapshot() {
    echo ; echo "Backup snapshot /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE}"
    echo "Backup is ${bkpath}/${vm}.img-FULLBACKUP-${LOGDATE}"
    rsync -h --progress --verbose --stats \
    /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE} \
    ${bkpath}/${vm}.img-FULLBACKUP-${LOGDATE} || \
    err "Can't backup snapshot to ${bkpath}/${vm}.img-FULLBACKUP-${LOGDATE}"
}

rm_snapshot() {
    echo ; echo "Removing snapshot /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE}"
    rm -f /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE} || \
    err "Can't remove snapshot /OVS/${vm}/${vm}.img-SNAPSHOT-${LOGDATE}"
}

retire_older_backups() {
    echo 
    # find current number of images
    bkp_number=`find ${bkpath} -type f -name "*.img-FULLBACKUP*" | wc -l` || \
    err "Can't find current number of backups"
        if [ ${bkp_number} -gt ${counts} ]; then
            echo "Removing backups older than latest ${counts}"
            # how many images to delete
            num_to_delete=`(echo "scale=0; ${bkp_number}-${counts}" | bc -l)` || \
            err "Can't find how many images to delete"
            # list of images to delete
            bkp_to_delete=`find ${bkpath} -type f -name "*.img-FULLBACKUP*" | sort -nr | tail -${num_to_delete}` || \
            err "Can't generate list of images to be deleted"
            echo ; echo "Backups to remove: ${bkp_to_delete}" ; echo
            for image in ${bkp_to_delete}
               do
                  rm -f ${image} || err "Can't remove ${image}"
                  echo "Removed: ${image}"
               done
        else
            echo "There is no older backup to be removed"
        fi
}

##### MAIN  #####
(
chk_vm   # check presence of VM in Dom0
[[ ${counts} = [[:digit:]]* ]] || err "Retention must be in counts, as integer."
[[ -d ${bkpath} ]] || err "Backup path ${bkpath} is not directory."

get_snapshot
backup_snapshot
rm_snapshot
retire_older_backups

) >> ${LOGFILE} 2>&1

exit 0


