#!/bin/sh

# rsync [with delete] from local directory to NFS share
# NFS share is mounted on local host
# arg 1 is source directory
# arg 2 is destination directory on NFS share
# -------------------------------------------------------
# Note: root's public ssh key needs to be on destination !
# ---------------------------------------------------------

source_path=$1
source_path_logformat=$(echo ${source_path} | sed 's/\//_/g')
destination_path=$2
start_time=$(date +%s)
hostname=$(hostname)
logdate=$(date +%m.%d.%Y_%H.%M)
progname=$(basename $0| sed 's/^9//')
readonly log_path=/var/log/${progname}
readonly logfile=${log_path}/${logdate}${source_path_logformat}.log
readonly days_to_keep_logs=60

#cannot use these:
# -A, --acls    preserve ACLs (implies --perms)
# -X, --xattrs  preserve extended attributes
readonly rsync_options="-avHS --delete --exclude=.snapshot --exclude=crash --exclude=stats --exclude=.git"

who_cares="
your@e-mail \
"
readonly loggerinfo="logger -t "${progname}" Info:"
readonly loggerwarning="logger -t "${progname}" Warning:"
readonly loggerproblem="logger -t "${progname}" Problem:"

${loggerinfo} ==== Start at $(date +'%Y-%m-%dT%H-%M-%S_%Z') ===

err() {
        echo ; echo "Problem: $*" ; echo
        ${loggerproblem} "$*"
        echo "$*" | mail -s "Problem from ${hostname}:${progname}" ${who_cares}
        ${loggerinfo} ======== Finish at $(date +'%Y-%m-%dT%H-%M-%S_%Z') ====
        exit 1
}

# create log path if it doesn't exist
if ! [ -d "${log_path}" ]; then
  mkdir "${log_path}"
fi

if [ $# -ne 2 ]; then
  err "Number of arguments must be two, source and destination path"
fi

# check if arg is file or directory
check_source_destination(){
  [[ -e "${source_path}" ]] || err "Source ${source_path} desn't exist"   
  [[ -e "${destination_path}" ]] || err "Destination ${destination_path} desn't exist"
  [[ -d "${destination_path}" ]] || err "${destination_path} is not valid destination directory "  
}

# removing old logs
old_log_removal(){
test -d ${log_path} || mkdir -p ${log_path}
echo "Removing old logs:"
echo "-------------------"
find ${log_path} \
  -type f \
  -name "*.log" \
  -mtime +${days_to_keep_logs} \
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

########### MAIN #############
(
old_log_removal
check_source_destination
echo "Start rsync from ${hostname} : ${source_path} to ${destination_path}"
echo "-------------------------------------------------------------------------"
rsync ${rsync_options} /${source_path} /${destination_path} || \
err "There is problem with rsync ..."
echo ; echo " $(completed_time ${start_time}) "
${loggerinfo} ======== Finish at $(date +'%Y-%m-%dT%H-%M-%S_%Z') ====
) > ${logfile} 2>&1


