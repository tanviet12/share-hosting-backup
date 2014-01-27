#!/bin/bash
# Configuration
HOST=$1
DES_DIR="/directory_backup/$HOST"
RSYNC="/usr/bin/rsync"
CYCLE_BACKUP=1
LAST_DAY_BACKUP=`date -d "$CYCLE_BACKUP day ago" +'%Y-%m-%d'`
KEEP_BK=7
TODAY="$(date +"%Y-%m-%d")"

if [ -z $1 ] || [ -z $2 ];then

        echo `date` : Stop due HOST or cpanel files variable does not exist >> /var/log/backup/$TODAY-$HOST.log
        exit 0
fi

# Initialise only
mkdir -p $DES_DIR
mkdir -p /var/log/backup/

# Check load
[ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo `date` : Hight load... sleep 300s >> /var/log/backup/$TODAY-$HOST.log

# Remove old backup
list_bk_folder=`ls -l $DES_DIR | grep root | grep -v ./ | awk '{print$9}'`
array_bk_folder=( $list_bk_folder );

for (( i=0;i< ${#array_bk_folder[@]}; i++ ))

do
        stat11=`stat -c %Y $DES_DIR/${array_bk_folder[$i]}`
        array_bk_stat[$i]=$stat11
done
for ((i=0;i< ${#array_bk_stat[@]};i++))
do
        stat1=${array_bk_stat[$i]}
        for (( j=1; j < ${#array_bk_stat[@]}; j++ ))
        do
                stat2=${array_bk_stat[$j]}
                if [ $((stat1)) -lt $((stat2)) ];
                then
                         tempstring=$stat1
                         stat1=$stat2
                         stat2=$tempstring
                         array_bk_stat[$i]=$stat1
                         array_bk_stat[$j]=$stat2
                fi
        done

done

let "DELETE_BK=${#array_bk_stat[@]}-$KEEP_BK+1"

for ((i=0;i<$DELETE_BK;i++))

do
        for ((j=0;j<${#array_bk_stat[@]};j++))

        do
                stat1=`stat -c %Y $DES_DIR/${array_bk_folder[$i]}`
                stat2=${array_bk_stat[$j]}

                if [ $((stat2)) -eq $((stat1)) ];
                then
                        cd $DES_DIR
                        rm -rf ${array_bk_folder[$i]} && echo `date` : Remove ${array_bk_folder[$i]} backup directory completed >> /var/log/backup/$TODAY-$HOST.log|| echo `date` : Failed to remove ${array_bk_folder[$i]} backup directory >> /var/log/backup/$TODAY-$HOST.log
                        break
                fi
        done
done


# Copy backup script to target server
$RSYNC -a ./backup_agents/ $HOST:/root/backup/

# Check accounts hosting before backup
# ssh root@$HOST /root/backup/check_before_bk.sh

# Backup MySQL first
echo `date` : Begin backup MySQL >> /var/log/backup/$TODAY-$HOST.log
ssh root@$HOST /root/backup/backup_db.sh
echo `date` : End backup MySQL >> /var/log/backup/$TODAY-$HOST.log

#users_backlist=`ssh $HOST cat /var/cpanel/tmp/bk_users_backlist.txt`
#array_users_backlist=( $users_backlist )

# Backup config file and source website
echo `date` : Begin backup config file and source website >> /var/log/backup/$TODAY-$HOST.log

[ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "Hight load... sleep 300s " >> /var/log/$TODAY-$HOST.log

if [ -d $DES_DIR/$LAST_DAY_BACKUP ] ; then
	 cp -al $DES_DIR/$LAST_DAY_BACKUP $DES_DIR/$TODAY && echo Copy source last backup complete >> /var/log/$TODAY-$HOST.log || echo Failed copy source last backup >> /var/log/$TODAY-$HOST.log
fi

for FILE in `/bin/cat $2`; do
        # Initialise only
        DIR=`echo $FILE | sed 's|^/||; s|[^/]*$||'` &&  mkdir -p $DES_DIR/$TODAY/$DIR

        if [ $FILE = "/home/" ]; then
                # It's a good idea to break /home into small chunks
                for SUBDIR in `ssh $HOST ls /var/cpanel/users/ | grep -v "/"`; do
                        [ `ssh $HOST cat /proc/loadavg |awk -F. {'print $1'}` -gt 20 ] && sleep 300
#                       case "${array_users_backlist[@]}" in  *"$SUBDIR"*) echo `date` : Skiping $HOST:$FILE$SUBDIR due to large size/inode >> /var/log/backup/$TODAY-$HOST.log && continue ;; esac
                        $RSYNC -a -H --delete --exclude="/tmp/" --exclude="backup-*.gz" --exclude="error_log" -e ssh $HOST:$FILE$SUBDIR/ $DES_DIR/$TODAY/$FILE$SUBDIR/ && echo `date` : Success backup $HOST:$FILE$SUBDIR >> /var/log/backup/$TODAY-$HOST.log || echo `date` : Failed backup $HOST:$FILE$SUBDIR >> /var/log/backup/$TODAY-$HOST.log
                                                                                                                                                                                        done
        else                                                                                                                                                                            $RSYNC -a -H --delete --exclude="bandwidth/*.rrd" -e ssh $HOST:$FILE $DES_DIR/$TODAY/$FILE && echo `date` : Success backup $HOST:$FILE >> /var/log/backup/$TODAY-$HOST.log || echo `date` : Failed backup $HOST:$FILE >> /var/log/backup/$TODAY-$HOST.log
        fi
done

echo `date` : End backup config file and source website >> /var/log/backup/$TODAY-$HOST.log

# Send log backup to support@abc.com

# Send log backup source code  to support@abc.com
echo "Backup source code result for $HOST on $TODAY" > /tmp/msg.txt
SUBJECT="Backup source code result for $HOST on $TODAY"
ATTACH="/var/log/backup/$TODAY-$HOST.log"

/usr/local/bin/mutt -s "$SUBJECT" support@abc.com -a $ATTACH < /tmp/msg.txt
