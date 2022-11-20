#!/bin/bash

LOGFILE="/var/log/pms-backup.log"
MSG_URL="$GOTIFY_SERVER/message?token=$GOTIFY_TOKEN"
# Delete old backup files older than x
DELETE_DAYS=2

function sendMsg {
    # 1 = msg, 2 = priority
    MSG_TITLE="Plex Backup Cleanup Script"
    MSG=$1
    MSG_PRIORITY=$2
    MSG_DATE="$(date '+%Y-%m-%d %T')"

    echo "$MSG_DATE $MSG" | tee -a $LOGFILE
    if [ $MSG_PRIORITY -gt 1 ]; then
        eval $(curl $MSG_URL -F "title=$MSG_TITLE" -F "message=$MSG" -F "priority=$MSG_PRIORITY")
    fi    
}

# create log file
touch $LOGFILE

sendMsg "Performing Plex Backup cleanup" "1"

# check for backup location mounted
if [ -z "$(mount -l | grep $BACKUP_LOC)" ]; then
    sendMsg "Backup location probably not mounted, exiting..." "3"
    exit 1
fi

# find files older than 2 days
# delete files
OLD_BACKUP_FILES=($(find $BACKUP_LOC -name pms-backup-*.tar.gz -mtime +$DELETE_DAYS))

for i in ${OLD_BACKUP_FILES[@]}; do
    sendMsg "Deleting Old Backup File $i" "1"
    rm -f "$i"
done

sendMsg "Completed Plex Backup cleanup" "1"