#!/bin/bash

# Run this script with the following variables exported
#BACKUP_LOC="/mnt/some/backup/location" GOTIFY_TOKEN=xxxxxx GOTIFY_SERVER=https://gotify.fqdn

PMS_DIR="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server"
LOGFILE="/var/log/pms-backup.log"
TMP_DIR="/var/lib/plexmediaserver"
PMS_LIST=("Media" "Metadata" "Plug-ins" "Plug-in Support" "Preferences.xml")
MSG_URL="$GOTIFY_SERVER/message?token=$GOTIFY_TOKEN"

function sendMsg {
    # 1 = msg, 2 = priority
    MSG_TITLE="Plex Backup Script"
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

sendMsg "Starting Plex Backup" "1"

# check for pms directories
if [ ! -d "$PMS_DIR" ]; then
    sendMsg "Can't find Plex Media Server directory, exiting..." "3"
    exit 1
fi

# check for backup location mounted
if [ -z "$(mount -l | grep $BACKUP_LOC)" ]; then
    sendMsg "Backup location probably not mounted, exiting..." "3"
    exit 1
fi

# check if we can stop services to perform backup task
# check if services is running
if [[ "$(systemctl is-active --quiet plexmediaserver)" -ne 0 ]]; then
    sendMsg "Plex is not running, exiting..." "3"
    exit 1
fi

## Get plex token from Preferences.xml
# switch dir
pushd "$PMS_DIR"
PMS_TOKEN="$(sed -nr 's/.+PlexOnlineToken="(\S*)".+/\1/p' Preferences.xml)"

if [ -z "$PMS_TOKEN" ]; then
    sendMsg "Can't obtain token, exiting..." "3"
    exit 1
fi
# switch back dir
popd

## curl endpoint
CURL_CMD="curl -s http://$(hostname -f):32400/status/sessions?X-Plex-Token=$PMS_TOKEN"

### if size="0", no one is watching, if greater than 0 then something is playing.
while
    if [ "$(eval $CURL_CMD | sed -nr 's/.+size="([0-9]+)".+/\1/p')" -gt 0 ]; then
        sendMsg "There's Activity, sleeping for 30 seconds..." "1"
        sleep 30
    else
        sendMsg "There's No Activity, continuing on..." "1"
        break
    fi
do true; done

# stop plex
sendMsg "Stopping Plex Media Server" "1"
systemctl stop plexmediaserver

# switching to a directory where I should have enough space
pushd "$PMS_DIR"

BK_PREFIX="pms-backup-$(date '+%Y-%m-%d-%H%M%S')"
# tar components (loop)
for i in "${PMS_LIST[@]}"; do
    sendMsg "Backing up $i ..." "1"
    
    # add conditional filename change for directory with space
    if [ "$i" == "Plug-in Support" ]; then
        FILENAME="$TMP_DIR/$BK_PREFIX-Plug-in_Support.tar.gz"
    else
        FILENAME="$TMP_DIR/$BK_PREFIX-$i.tar.gz"
        
    fi
    # make archive
    # uncomment below for verbose flag
    #tar -czvf "$FILENAME" "$i"
    # comment out if using the verbose flag above
    tar -czf "$FILENAME" "$i"
    
    if [ -d "$BACKUP_LOC" ]; then
        mv "$FILENAME" "$BACKUP_LOC/"
    else
        sendMsg "Issue with Mount Location ${BACKUP_LOC}, skipping moving ${FILENAME}" "3"
    fi
    
done

popd
sendMsg "Backup Completed" "1"

# start pms service
sendMsg "Restarting Plex Media Server" "1"
systemctl start plexmediaserver
sleep 10

# checking to ensure running
if [[ "$(systemctl is-active --quiet plexmediaserver)" -ne 0 ]]; then
    sendMsg "Plex is not running, startup might have gone wrong" "3"
    exit 1
fi