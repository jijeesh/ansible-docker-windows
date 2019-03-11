#!/usr/bin/env bash

#
# Shell script to automate the backup of Microsoft SQL Server vNEXT backups on Linux.
# Written by Bobby Allen <ballen@bobbyallen.me>, 26/04/2017
#
# Download this script and put into your servers' /usr/bin directory (or symlink) then make it executable (chmod +x)
#
# Usage example (backup databases into /var/backups, keep backups for 5 days, connect to server "localhost" with the account "sa" and a password of "P455w0RD"):
# mssqlbackup "/var/dbbackups" 5 "localhost"  "sa"  "P455w0rD"
#
# If you wanted to automate backups, here is a cron job example (create a new file under /etc/cron.d eg. '/etc/cron.d/mssql-backups' and copy into the following line) -This will backup all your databases daily at 00:15 to /var/backups and keep backups for 30 days:
# 15 0 * * * root /usr/bin/mssqlbackup "/var/dbbackups" 30 "localhost" "sa" "<YourPasswordHere>"
#

# Set some default values
MSSQL_HOST="localhost"
BACKUP_DIR="/var/backups"
BACKUP_DAYS=7 # You can test by changing file dates using: touch -d "8 days ago" mssql_20160504-1542.gz
MSSQL_USER="sa"
MSSQL_PASS="yourStrong(!)Password"
MSSQL_EXEC="/opt/mssql-tools/bin/sqlcmd"
DATE=`date +%Y%m%d-%H%M%S` # YYYYMMDD-HHMMSS

# Set Backup Parameters
if [[ ! $1 == "" ]]
then
        BACKUP_DIR=$1
fi
if [[ ! $2 == "" ]]
then
        BACKUP_DAYS=$2
fi
if [[ ! $3 == "" ]]
then
        MSSQL_HOST=$3
fi
if [[ ! $4 == "" ]]
then
        MSSQL_USER=$4
fi
if [[ ! $5 == "" ]]
then
        MSSQL_PASS=$5
fi

echo ""
echo "Starting MSSQL backup with the following conditions:"
echo ""
echo "  Backup to: ${BACKUP_DIR}"
echo "  Backup timestamp: ${DATE}"
echo "  Keep backups for ${BACKUP_DAYS} days"
echo ""
echo "  MSSQL Server: ${MSSQL_HOST}"
echo "  MSSQL User: ${MSSQL_USER}"
echo "  MSSQL Password: **HIDDEN**"
echo ""

# If the backup directory does not exist, we will create it..
if [[ ! -d $BACKUP_DIR ]]
then
        echo ""
        echo "Backup directory does not exist, creating it..."
        mkdir -p $BACKUP_DIR
        echo ""
fi

# Disable error messages.
exec 2> /dev/null

# Connect to MSSQL and get all databases to backup...
DATABASES=`$MSSQL_EXEC -S "$MSSQL_HOST" -U "$MSSQL_USER" -P "$MSSQL_PASS" -Q "SELECT Name from sys.Databases" | grep -Ev "(-|Name|master|tempdb|model|msdb|affected\)$|\s\n|^$)"`

# Iterate over all of our databases and back them up one by one...
echo "Starting backups..."
for DBNAME in $DATABASES; do
        echo -n " - Backing up database \"${DBNAME}\"... "
        $MSSQL_EXEC -H "$MSSQL_HOST" -U "$MSSQL_USER" -P "$MSSQL_PASS" -Q "BACKUP DATABASE [${DBNAME}] TO  DISK = '${BACKUP_DIR}/${DBNAME}_${DATE}.bak' WITH NOFORMAT, NOINIT, NAME = '${DBNAME}-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
        echo "Done!"
done
echo "Backups complete!"
echo ""

# Re-enable error messages.
exec 2> /dev/tty

# Now delete files older than X days
find $BACKUP_DIR/* -mtime +$BACKUP_DAYS -exec rm {} \;

