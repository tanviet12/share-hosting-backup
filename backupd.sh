#!/bin/bash

# This script backup for hosting cPanel/WHM

# Configuration
HOSTS="x.x.x.x y.y.y.y"

today="$(date +"%Y-%m-%d")"

cd /root/123host/backup
echo -e "\n\n========================$(date)=======================\n\n" >> log.txt

for ip in $HOSTS; do
        while [ $(jobs | wc -l) -ge 3 ]
        do
               sleep 180
        done

        echo "==========Backup for $ip started at $(date "+%c") ==========" >> log.txt
        (./rsync.pull.backup.sh $ip cpanel.files && echo "==========Backup for $ip ended at $(date "+%c")==========" >> log.txt)&
done
