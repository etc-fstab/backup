#!/bin/env bash

# backup a disk image of a VM in standalone Dom0
# this is not OS (boot) image, but some other local disk for a VM
# argument 1 = /full/path/disk.img
# argument 2 = retention in counts
# argumet 3 = backup path, likely /import/something
# -----------------------------------------------------

PROGNAME=`basename $0`
readonly loggerinfo="logger -t "${PROGNAME}" Info:"
readonly loggerwarning="logger -t "${PROGNAME}" Warning:"
readonly loggerproblem="logger -t "${PROGNAME}" Problem:"
who_cares="
name-1@domain.com \
name-2@domain.com \
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
  Usage: ${PROGNAME} </full/path/disk_image> <counts to keep> <backup path>
  "
  exit 1
}

# must be three arguments
if [ $# -ne 3 ]; then
 usage
fi

# impots and their checks
full_path_disk_image=$1
disk_image=`basename ${full_path_disk_image}`
counts=$2
bkpath=$3

LOGDATE=`date +'%Y%m%d-%H%M'`
LOG_PATH="/var/log/`basename ${PROGNAME}`"
[ -d /var/log/`basename ${PROGNAME}` ] || mkdir /var/log/`basename ${PROGNAME}`
LOGFILE=${LOG_PATH}/${disk_image}_${LOGDATE}.log
#

get_snapshot() {
    echo ; echo "Getting snapshot of ${full_path_disk_image}"
    reflink ${full_path_disk_image} ${full_path_disk_image}-SNAPSHOT-${LOGDATE} || \
    err "Can't get snapshot (using reflink) of ${full_path_disk_image}"
    echo "Snapshot ${full_path_disk_image}-SNAPSHOT-${LOGDATE} is created."
}

backup_snapshot() {
    echo ; echo "Backup snapshot ${full_path_disk_image}-SNAPSHOT-${LOGDATE}"
    echo "Backup is ${bkpath}/${disk_image}-FULLBACKUP-${LOGDATE}"
    rsync -h --progress --verbose --stats \
    ${full_path_disk_image}-SNAPSHOT-${LOGDATE} \
    ${bkpath}/${disk_image}-FULLBACKUP-${LOGDATE} || \
    err "Can't backup snapshot to ${bkpath}/${disk_image}-FULLBACKUP-${LOGDATE}"
}

rm_snapshot() {
    echo ; echo "Removing snapshot ${full_path_disk_image}-SNAPSHOT-${LOGDATE}"
    rm -f ${full_path_disk_image}-SNAPSHOT-${LOGDATE} || \
    err "Can't remove snapshot ${full_path_disk_image}-SNAPSHOT-${LOGDATE}"
}

retire_older_img_backups() {
    echo
    # find current number of images
    bkp_number=`find ${bkpath} -type f -name "*-FULLBACKUP-*" | wc -l` || \
    err "Can't find current number of image backups"
        if [ ${bkp_number} -gt ${counts} ]; then
            echo "Removing image backups older than latest ${counts}"
            # how many images to delete
            num_to_delete=`(echo "scale=0; ${bkp_number}-${counts}" | bc -l)` || \
            err "Can't find how many images to delete"
            # list of images to delete
            bkp_to_delete=`find ${bkpath} -type f -name "*-FULLBACKUP-*" | sort -nr | tail -${num_to_delete}` || \
            err "Can't generate list of images to be deleted"
            echo ; echo "Image backups to remove: ${bkp_to_delete}" ; echo
            for image in ${bkp_to_delete}
               do
                  rm -f ${image} || err "Can't remove image ${image}"
                  echo "Removed image: ${image}"
               done
        else
            echo "There is no older image backup to be removed"
        fi
}


##### MAIN  #####
(
[[ -e ${full_path_disk_image} ]] || err "Disk image ${full_path_disk_image} is not a file."
[[ ${counts} = [[:digit:]]* ]] || err "Retention must be in counts, as integer."
[[ -d ${bkpath} ]] || err "Backup path ${bkpath} is not directory."

get_snapshot
backup_snapshot
rm_snapshot
retire_older_img_backups

) >> ${LOGFILE} 2>&1

exit 0
