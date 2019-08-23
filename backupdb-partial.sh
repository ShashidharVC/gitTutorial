#!/bin/sh

dbname="jivoxdb"
MYSQL_HOME="/usr/"
MYSQL_LOGIN="-uroot -pn1celyd1ced"
MYSQL_OPTION="--master-data=2"

APPSERVER_ROOT=/var/www/html/jivox

LOGDIR=/mnt3/tmp
LOGPATH=/mnt3/tmp/jvxbackup.log
BACKUPDIR=`date +%m%d%y.%H%M`
BACKUPDIRPATH=/mnt3/tmp/jvxbackup.$BACKUPDIR

if [ "$EUID" -ne 0 ]
then
	echo "The backup utility must be run as root user"
	echo "Exiting"
	exit 1
fi

echo ""
echo "Starting DB backup --- please wait"
echo ""

LOGPATH
MV_CMD="/bin/cp -rf"

exitOnFailure()
{
        echo "ERROR: backup failed. Please see the logs for more"
        echo "information in $LOGPATH file"
	echo ""
        exit
}

exitOnSuccess()
{
        echo "Success: The backup is complete"
        echo "Backup directory name: $BACKUPDIRPATH"
        echo "Log file name: $LOGPATH"
	echo ""
        exit 
}

printUsage()
{
	echo ""
	echo "Usage : backupdb [-b backup_path] [-h]"
	echo "       [-b backup_path]  The backup directory is created under backup_path"
	echo "       [-h]            Print usage message"
	echo ""
}

backup_mysql()
{
	echo "Starting dump of Jivox DB"
#	$MYSQL_HOME/bin/mysqldump $MYSQL_LOGIN $dbname adPartnerCredentialTable adTable advertiserTable affiliateTable billingAddressTable bookingTable campaignApprovalTable campaignChargePolicyTable campaignTable campaignTagsTable catalogTable categoryTable contentTable conversionRecordTable currentDailyChargeTable deviceTable exchangeRateTable extCampaignTable externalAdTable jivoxGeoCities jivoxGeoCountries jivoxGeoRegions listingCampaignTable siteChargePolicyTable siteEventAttributeTable siteEventTable siteNodeTable siteTable targetProfileTable transactionTable userProfileTable userTable webCampaignTable viralCampaignTable adCompositorTable >$BACKUPDIRPATH/mysql.dmp 2>&1
	$MYSQL_HOME/bin/mysqldump $MYSQL_LOGIN $MYSQL_OPTION $dbname --ignore-table=$dbname.adImpressionTable --ignore-table=$dbname.adEventTable --ignore-table=$dbname.adEventTable_06_2011 --ignore-table=$dbname.adEventTable_07_2011 >$BACKUPDIRPATH/mysql.dmp 2>&1
	if [ $? -ne 0 ]
	then
		echo "Backup failed. Check the log at $LOGPATH"
		echo ""
		return 1
	fi
 	echo "Done."
# 	echo "Done." >>$LOGPATH 2>&1

	cd $BACKUPDIRPATH
	gzip ./mysql.dmp
	/usr/local/bin/aws s3 cp mysql.dmp.gz s3://jivoxdbbackup/$BACKUPDIR-mysql-dmp.gz
	#sh /home/jivox/s3sync/s3copyBackup.sh $BACKUPDIR-mysql-dmp.gz $BACKUPDIRPATH/mysql.dmp.gz
}

return_status=0
if [ $# -ne 0 ]
then
        while getopts hb: c
        do
                case $c in
                        b)
				BACKUPDIRPATH=`$ECHO $OPTARG | sed -e 's/\/$//'`/$BACKUPDIR
				echo -e  $BACKUPDIRPATH
				return_status=0
				;;
			*)
				printUsage
				exit
			;;
	   	esac
	done;

	if [ $return_status -eq 5 ]
	then
		printUsage
		exit
	fi
fi


if [ $return_status -eq 0 ]
then

	## 
	## checking all the arguments passed and setting the BACKUPDIR and LOGPATH values
	##
	if [ -d $LOGDIR ]
	then
		return_status=0
	else
		mkdir -p $LOGDIR > /dev/null
		if [ $? -ne 0 ]
		then 
			echo "could not create the logdir $LOGDIR"
			echo ""
			exitOnFailure
		fi
	fi

	if [ -f $LOGPATH ]
	then
		return_status=0
	else
		echo -e  "" > $LOGPATH
		if [ $? -ne 0 ]
		then 
			echo "could not create the log path $LOGPATH"
			echo ""
			exitOnFailure
		fi
	fi

	echo -e  "" > $LOGPATH
	if [ -d $BACKUPDIRPATH ]
	then
		return_status=0
	else
		mkdir -p $BACKUPDIRPATH > /dev/null
		if [ $? -ne 0 ]
		then 
			echo "could not create the backup dir $BACKUPDIRPATH"
			echo ""
			exitOnFailure
		fi
	fi

	backup_mysql
	if [ $? -eq 1 ]
	then 
		exitOnFailure
	else
		rm -rf $BACKUPDIRPATH
		exitOnSuccess
	fi
else
	exitOnFailure
fi
