#!/bin/bash
# Script backup all database MySQL
# Author: Tan Viet - VinaHost

DES_DIR="/backup/data/database"
DB_PATH="/var/lib/mysql"
TODAY="$(date +"%Y-%m-%d")"
CYCLE_BACKUP=1
LAST_DAY_BACKUP=`date -d "$CYCLE_BACKUP day ago" +'%Y-%m-%d'`
KEEP_BK=7
mkdir -p /var/log/backup

#Remove old backup

list_bk_folder=`ls -l $DES_DIR | grep root | grep -v ./ | grep -v LATEST | awk '{print$9}'`
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
                        rm -rf ${array_bk_folder[$i]} && echo `date` Remove ${array_bk_folder[$i]} backup directory completed >> /var/log/backup/$TODAY.log|| echo `date` Failed to remove ${array_bk_folder[$i]} backup directory >> /var/log/backup/$TODAY.log
                        break
                fi
        done
done

#Backup all database MySQL

#mkdir -p $DES_DIR/$TODAY

#dblist=`mysqlshow --defaults-extra-file=/root/.my.cnf | sed 's/|//g' | sed '1,4d' | sed '/+------/ d' | sed 's/ //g' | grep -v eximstats`
dblist=`mysql --defaults-extra-file=/root/.my.cnf -Bse 'show databases' | grep -v eximstats`

array_db=( $dblist )

echo "" >> /var/log/backup/$TODAY.log

echo ==============BEGIN BACKUP DATABASE `date` ================== >> /var/log/backup/$TODAY.log

if [ -d $DES_DIR/$LAST_DAY_BACKUP ] ; then

   cp -al $DES_DIR/$LAST_DAY_BACKUP $DES_DIR/$TODAY && echo `date` Copy database last backup complete  >> /var/log/backup/$TODAY.log || echo `date` Failed copy database last backup >> /var/log/backup/$TODAY.log

else
        mkdir -p $DES_DIR/$TODAY && chmod 700 $DES_DIR/$TODAY
fi


for((i=0;i<${#array_db[@]};i++))

do
        dbname=${array_db[$i]}
	INNODB_FLAG=`ls -al $DB_PATH/$dbname/ | grep ibd | wc -l`
	
	#Dump for database use innodb storage engine
	if [ $INNODB_FLAG -gt 0 ]; then
                [ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "`date` Hight load... sleep 300s " >> /var/log/backup/$TODAY.log
       		 mysqldump --defaults-extra-file=/root/.my.cnf --single-transaction --complete-insert $dbname > $DES_DIR/$TODAY/$dbname.sql && echo `date` Success dump database $dbname use mysqldump >> /var/log/backup/$TODAY.log || echo `date` Failse dump database $dbname use mysqldump >> /var/log/backup/$TODAY.log
	
	#Hotcopy for database use myisam
	else
		[ `cat /proc/loadavg |awk -F. {'print $1'}` -gt 16 ] && sleep 300 && echo "`date` Hight load... sleep 300s " >> /var/log/backup/$TODAY.log
                /usr/bin/mysqlhotcopy --method='cp' -q --noindices --addtodest $dbname $DES_DIR/$TODAY && echo `date` : Success backup database $dbname use mysqlhotcopy  >> /var/log/backup/$TODAY.log || echo `date` : Failed backup database $dbname use mysqlhotcopy >> /var/log/backup/$TODAY.log

	fi
done

rm -rf $DES_DIR/LATEST && ln -sf $DES_DIR/$TODAY $DES_DIR/LATEST && echo `date` : Success create symlink $DES_DIR/$TODAY to $DES_DIR/LATEST file >> /var/log/backup/$TODAY.log || echo `date` : Failed create symlink $DES_DIR/$TODAY to $DES_DIR/LATEST file >> /var/log/backup/$TODAY.log

echo ==============END BACKUP DATABASE `date` ==================== >> /var/log/backup/$TODAY.log

# Send log to support@abc.com
HOSTNAME=`/bin/hostname`
echo "Backup database result for $HOSTNAME" on $TODAY > /tmp/msg.txt
SUBJECT="Backup database result for $HOSTNAME on $TODAY"
ATTACH="/var/log/backup/$TODAY.log"

mutt -v > /dev/null || yum install mutt -y

[ ! -f $ATTACH ] && echo "Backup database on $HOSTNAME not work!" > $ATTACH && echo "Backup database on $HOSTNAME not work!" > /tmp/msg.txt

mutt -s "$SUBJECT" support@abc.com -a $ATTACH < /tmp/msg.txt
