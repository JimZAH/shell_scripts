# James Colderwood OCT 2020
# This script should be called by a non root user. Once called this script will replicate incremental snapshots to a local disk.
# Remember you must manually run the first snapshot send/recv before using this script.
# Questions, james@colderwood.net
#!/bin/bash
FIRST=0 # WARNING!!!!! ONLY set this to 1 if this is the first ever run! DEFAULT 0
SNAPSHOTS=("some" "jail" "backups") # What snapshots do we want to send?
LOCAL_FLAGS="-i" # Local send flags, leave empty for none
LOCAL_POOL="data/"
BACKUP_FLAGS="-F" # Remote recv flags, leave empty for none
BACKUP_POOL="hddbackup/"
ENABLED=1 # 1= Enabled, 2= Dryrun, 0= Disabled
LOG=1 # 1= Enabled, 2= Log to active console, 0= Disabled
ROOT_OVERIDE=1 # Allow script to run as root. 1= Enabled, 0= Disabled

###########################################################################
########################Don't change the below vars########################
###########################################################################

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d  +%Y-%m-%d)
ZFS="/sbin/zfs" # Where is the zfs binary?
SSH="/usr/bin/ssh"
CURRENT_SNAP="@zfs-auto-snap_daily-$TODAY-00h07"
OLD_SNAP="@zfs-auto-snap_daily-$YESTERDAY-00h07"
F_RUN=0

function check_FIRST {
  if [ "$FIRST" == 1 ]; then
    echo "Please confirm you are running these backups for the first time. Type YES to continue"
    read answer
    if [ "$answer" != "YES" ]; then
      echo "Sorry, You need to confirm you'd like to proceed!!"
    else
      echo "Thank you, I'll run the backup for the first time. You have 10 seconds to cancel"
      sleep 10
      F_RUN=1 # OMG HERE WE GO
    fi
  fi
}

function log {
  case "$LOG" in
    1)
    logger "ZFS_Replicate: $1"
    ;;
    2)
    echo "ZFS_Replicate: $1"
    ;;
    *)
    ;;
  esac
}

function check_ROOT {
  if [ "$EUID" == 0 ] && [ "$ROOT_OVERIDE" == 0 ]; then
    log "FATAL -> Sorry, you're running as root. ROOT_OVERIDE is set to $ROOT_OVERIDE"
    exit 2
  fi
  }

function check_POOL {
  for s in ${SNAPSHOTS[@]}; do
    $ZFS list $LOCAL_POOL$s &> /dev/null
    if [ $? != 0 ]; then
      log "ERROR -> The POOL $LOCAL_POOL$s does not exist! Please fix before continuing"
      exit 3
    else
      log "INFO -> Found $LOCAL_POOL$s"
    fi
  done
}

function send_snapshots {
  if [ "$ENABLED" == 2 ]; then
    log "WARNING -> Dry run requested!"
    echo "I would be running the following commands...: "
  for s in ${SNAPSHOTS[@]}; do
    if [ "$F_RUN" == 1 ]; then
      echo "$ZFS send $LOCAL_POOL$s$CURRENT_SNAP | $ZFS recv $BACKUP_FLAGS $BACKUP_POOL$s"
    else
      echo "$ZFS send $LOCAL_FLAGS $LOCAL_POOL$s$OLD_SNAP $LOCAL_POOL$s$CURRENT_SNAP | $ZFS recv $BACKUP_FLAGS $BACKUP_POOL$s"
    fi
  done
  elif [ "$ENABLED" == 1 ]; then
    log "INFO -> Replication starting"
    for s in ${SNAPSHOTS[@]}; do
      log "INFO -> Sending $s"
      if [ "$F_RUN" == 1 ]; then
        $ZFS send $LOCAL_POOL$s$CURRENT_SNAP | $ZFS recv $BACKUP_FLAGS $BACKUP_POOL$s
      else
        $ZFS send $LOCAL_FLAGS $LOCAL_POOL$s$OLD_SNAP $LOCAL_POOL$s$CURRENT_SNAP | $ZFS recv $BACKUP_FLAGS $BACKUP_POOL$s
      fi
      if [ $? != 0 ]; then # Grab the exit code of ZFS
        log "ERROR -> I was unable to send $s to POOL: $BACKUP_POOL EXIT CODE: $?"
      else
        log "INFO -> $s was successfully sent to $BACKUP_POOL"
      fi
    done
  fi
}

check_FIRST
check_ROOT
check_POOL
send_snapshots
