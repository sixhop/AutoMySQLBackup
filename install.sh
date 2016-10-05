#!/usr/bin/env bash
#

# return	true, if variable is set; else false
isSet() {
  if [[ ! ${!1} && ${!1-_} ]]; then return 1; else return 0; fi
}

activateIO() {
    touch "$1"
    exec 6>&1
    exec > "$1"
}
removeIO() {
  exec 1>&6 6>&-
}

upgrade_config_file () {
( # execute in subshell, so that sourced variables are only available inside ()
    source "$1"
    #declare -p
    local temp
    temp=$(mktemp /tmp/tmp.XXXXXX)
    (( $? != 0 )) && return 1
    activateIO "$temp"
    echo "#version=3.0_rc2"
    echo "# Uncomment to change the default values (shown after =)"
    echo "# WARNING:"
    echo "# This is not true for UMASK, CONFIG_prebackup and CONFIG_postbackup!!!"
    echo "#"
    echo "# Default values are stored in the script itself. Declarations in"
    echo "# /etc/automysqlbackup/automysqlbackup.conf will overwrite them. The"
    echo "# declarations in here will supersede all other."
    echo ""
    echo "# Edit \$PATH if mysql and mysqldump are not located in /usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin"
    echo "#PATH=\${PATH}:FULL_PATH_TO_YOUR_DIR_CONTAINING_MYSQL:FULL_PATH_TO_YOUR_DIR_CONTAINING_MYSQLDUMP"
    echo ""
    echo "# Basic Settings"
    echo ""
    echo "# Username to access the MySQL server e.g. dbuser"
    if isSet USERNAME; then
      printf '%s=%q\n' CONFIG_mysql_dump_username "${USERNAME-}"
    else
      echo "#CONFIG_mysql_dump_username='root'"
    fi
    echo ""
    echo "# Password to access the MySQL server e.g. password"
    if isSet PASSWORD; then
      printf '%s=%q\n' CONFIG_mysql_dump_password "${PASSWORD-}"
    else
      echo "#CONFIG_mysql_dump_password=''"
    fi
    echo ""
    echo "# Host name (or IP address) of MySQL server e.g localhost"
    if isSet DBHOST; then
      printf '%s=%q\n' CONFIG_mysql_dump_host "${DBHOST-}"
    else
      echo "#CONFIG_mysql_dump_host='localhost'"
    fi
    echo ""
    echo "# \"Friendly\" host name of MySQL server to be used in email log"
    echo "# if unset or empty (default) will use CONFIG_mysql_dump_host instead"
    if isSet CONFIG_mysql_dump_host_friendly; then
      printf '%s=%q\n' CONFIG_mysql_dump_host_friendly "${CONFIG_mysql_dump_host_friendly-}"
    else
      echo "#CONFIG_mysql_dump_host_friendly=''"
    fi
    echo ""
    echo "# Backup directory location e.g /backups"
    if isSet BACKUPDIR; then
      printf '%s=%q\n' CONFIG_backup_dir "${BACKUPDIR-}"
    else
      echo "#CONFIG_backup_dir='/var/backup/db'"
    fi
    echo ""
    echo "# This is practically a moot point, since there is a fallback to the compression"
    echo "# functions without multicore support in the case that the multicore versions aren't"
    echo "# present in the system. Of course, if you have the latter installed, but don't want"
    echo "# to use them, just choose no here."
    echo "# pigz -> gzip"
    echo "# pbzip2 -> bzip2"
    echo "#CONFIG_multicore='yes'"
    echo ""
    echo "# Number of threads (= occupied cores) you want to use. You should - for the sake"
    echo "# of the stability of your system - not choose more than (#number of cores - 1)."
    echo "# Especially if the script is run in background by cron and the rest of your system"
    echo "# has already heavy load, setting this too high, might crash your system. Assuming"
    echo "# all systems have at least some sort of HyperThreading, the default is 2 threads."
    echo "# If you wish to let pigz and pbzip2 autodetect or use their standards, set it to"
    echo "# 'auto'."
    echo "#CONFIG_multicore_threads=2"
    echo ""
    echo "# Databases to backup"
    echo ""
    echo "# List of databases for Daily/Weekly Backup e.g. ( 'DB1' 'DB2' 'DB3' ... )"
    echo "# set to (), i.e. empty, if you want to backup all databases"
    if isSet DBNAMES; then
      if [[ "x$DBNAMES" = "xall" ]]; then
	echo "#CONFIG_db_names=()"
      else
	declare -a CONFIG_db_names
	for i in $DBNAMES; do
	  CONFIG_db_names=( "${CONFIG_db_names[@]}" "$i" )
	done
	declare -p CONFIG_db_names | sed -e 's/\[[^]]*]=//g'
      fi
    else
      echo "#CONFIG_db_names=()"
    fi
    echo "# You can use"
    echo "#declare -a MDBNAMES=( \"\${DBNAMES[@]}\" 'added entry1' 'added entry2' ... )"
    echo "# INSTEAD to copy the contents of \$DBNAMES and add further entries (optional)."
    echo ""
    echo "# List of databases for Monthly Backups."
    echo "# set to (), i.e. empty, if you want to backup all databases"
    if isSet MDBNAMES; then
      if [[ "x$MDBNAMES" = "xall" ]]; then
	echo "#CONFIG_db_month_names=()"
      else
	declare -a CONFIG_db_month_names
	for i in $MDBNAMES; do
	  CONFIG_db_month_names=( "${CONFIG_db_month_names[@]}" "$i" )
	done
	declare -p CONFIG_db_month_names | sed -e 's/\[[^]]*]=//g'
      fi
    else
      echo "#CONFIG_db_month_names=()"
    fi
    echo ""
    echo "# List of DBNAMES to EXLUCDE if DBNAMES is empty, i.e. ()."
    if isSet DBEXCLUDE; then
      declare -a CONFIG_db_exclude
      for i in $DBEXCLUDE; do
	CONFIG_db_exclude=( "${CONFIG_db_exclude[@]}" "$i" )
      done
      declare -p CONFIG_db_exclude | sed -e 's/\[[^]]*]=//g'
    else
      echo "#CONFIG_db_exclude=( 'information_schema' )"
    fi
    echo ""
    echo "# List of tables to exclude, in the form db_name.table_name"
    echo "#CONFIG_table_exclude=()"
    echo ""
    echo ""
    echo "# Advanced Settings"
    echo ""
    echo "# Rotation Settings"
    echo ""
    echo "# Which day do you want monthly backups? (01 to 31)"
    echo "# If the chosen day is greater than the last day of the month, it will be done"
    echo "# on the last day of the month."
    echo "# Set to 0 to disable monthly backups."
    echo "#CONFIG_do_monthly=\"01\""
    echo ""
    echo "# Which day do you want weekly backups? (1 to 7 where 1 is Monday)"
    echo "# Set to 0 to disable weekly backups."
    if isSet DOWEEKLY; then
      printf '%s=%q\n' CONFIG_do_weekly "${DOWEEKLY-}"
    else
      echo "#CONFIG_do_weekly=\"5\""
    fi
    echo ""
    echo "# Set rotation of daily backups. VALUE*24hours"
    echo "# If you want to keep only today's backups, you could choose 1, i.e. everything older than 24hours will be removed."
    echo "#CONFIG_rotation_daily=6"
    echo ""
    echo "# Set rotation for weekly backups. VALUE*24hours"
    echo "#CONFIG_rotation_weekly=35"
    echo ""
    echo "# Set rotation for monthly backups. VALUE*24hours"
    echo "#CONFIG_rotation_monthly=150"
    echo ""
    echo ""
    echo "# Server Connection Settings"
    echo ""
    echo "# Set the port for the mysql connection"
    echo "#CONFIG_mysql_dump_port=3306"
    echo ""
    echo "# Compress communications between backup server and MySQL server?"
    if isSet COMMCOMP; then
      printf '%s=%q\n' CONFIG_mysql_dump_commcomp "${COMMCOMP-}"
    else
      echo "#CONFIG_mysql_dump_commcomp='no'"
    fi
    echo ""
    echo "# Use ssl encryption with mysqldump?"
    echo "#CONFIG_mysql_dump_usessl='yes'"
    echo ""
    echo "# For connections to localhost. Sometimes the Unix socket file must be specified."
    if isSet SOCKET; then
      printf '%s=%q\n' CONFIG_mysql_dump_socket "${SOCKET-}"
    else
      echo "#CONFIG_mysql_dump_socket=''"
    fi
    echo ""
    echo "# The maximum size of the buffer for client/server communication. e.g. 16MB (maximum is 1GB)"
    if isSet MAX_ALLOWED_PACKET; then
      printf '%s=%q\n' CONFIG_mysql_dump_max_allowed_packet "${MAX_ALLOWED_PACKET-}"
    else
      echo "#CONFIG_mysql_dump_max_allowed_packet=''"
    fi
    echo ""
    echo "# This option sends a START TRANSACTION SQL statement to the server before dumping data. It is useful only with"
    echo "# transactional tables such as InnoDB, because then it dumps the consistent state of the database at the time"
    echo "# when BEGIN was issued without blocking any applications."
    echo "#"
    echo "# When using this option, you should keep in mind that only InnoDB tables are dumped in a consistent state. For"
    echo "# example, any MyISAM or MEMORY tables dumped while using this option may still change state."
    echo "#"
    echo "# While a --single-transaction dump is in process, to ensure a valid dump file (correct table contents and"
    echo "# binary log coordinates), no other connection should use the following statements: ALTER TABLE, CREATE TABLE,"
    echo "# DROP TABLE, RENAME TABLE, TRUNCATE TABLE. A consistent read is not isolated from those statements, so use of"
    echo "# them on a table to be dumped can cause the SELECT that is performed by mysqldump to retrieve the table"
    echo "# contents to obtain incorrect contents or fail."
    echo "#CONFIG_mysql_dump_single_transaction='no'"
    echo ""
    echo "# http://dev.mysql.com/doc/refman/5.0/en/mysqldump.html#option_mysqldump_master-data"
    echo "# --master-data[=value] "
    echo "# Use this option to dump a master replication server to produce a dump file that can be used to set up another"
    echo "# server as a slave of the master. It causes the dump output to include a CHANGE MASTER TO statement that indicates"
    echo "# the binary log coordinates (file name and position) of the dumped server. These are the master server coordinates"
    echo "# from which the slave should start replicating after you load the dump file into the slave."
    echo "#"
    echo "# If the option value is 2, the CHANGE MASTER TO statement is written as an SQL comment, and thus is informative only;"
    echo "# it has no effect when the dump file is reloaded. If the option value is 1, the statement is not written as a comment"
    echo "# and takes effect when the dump file is reloaded. If no option value is specified, the default value is 1."
    echo "#"
    echo "# This option requires the RELOAD privilege and the binary log must be enabled. "
    echo "#"
    echo "# The --master-data option automatically turns off --lock-tables. It also turns on --lock-all-tables, unless"
    echo "# --single-transaction also is specified, in which case, a global read lock is acquired only for a short time at the"
    echo "# beginning of the dump (see the description for --single-transaction). In all cases, any action on logs happens at"
    echo "# the exact moment of the dump."
    echo "# =================================================================================================================="
    echo "# possible values are 1 and 2, which correspond with the values from mysqldump"
    echo "# VARIABLE=    , i.e. no value, turns it off (default)"
    echo "#"
    echo "#CONFIG_mysql_dump_master_data="
    echo ""
    echo "# Included stored routines (procedures and functions) for the dumped databases in the output. Use of this option"
    echo "# requires the SELECT privilege for the mysql.proc table. The output generated by using --routines contains"
    echo "# CREATE PROCEDURE and CREATE FUNCTION statements to re-create the routines. However, these statements do not"
    echo "# include attributes such as the routine creation and modification timestamps. This means that when the routines"
    echo "# are reloaded, they will be created with the timestamps equal to the reload time."
    echo "#"
    echo "# If you require routines to be re-created with their original timestamp attributes, do not use --routines. Instead,"
    echo "# dump and reload the contents of the mysql.proc table directly, using a MySQL account that has appropriate privileges"
    echo "# for the mysql database. "
    echo "#"
    echo "# This option was added in MySQL 5.0.13. Before that, stored routines are not dumped. Routine DEFINER values are not"
    echo "# dumped until MySQL 5.0.20. This means that before 5.0.20, when routines are reloaded, they will be created with the"
    echo "# definer set to the reloading user. If you require routines to be re-created with their original definer, dump and"
    echo "# load the contents of the mysql.proc table directly as described earlier."
    echo "#"
    echo "#CONFIG_mysql_dump_full_schema='yes'"
    echo ""
    echo "# Backup dump settings"
    echo ""
    echo "# Include CREATE DATABASE in backup?"
    if isSet CREATE_DATABASE; then
      printf '%s=%q\n' CONFIG_mysql_dump_create_database "${CREATE_DATABASE-}"
    else
      echo "#CONFIG_mysql_dump_create_database='no'"
    fi
    echo ""
    echo "# Separate backup directory and file for each DB? (yes or no)"
    if isSet SEPDIR; then
      printf '%s=%q\n' CONFIG_mysql_dump_use_separate_dirs "${SEPDIR-}"
    else
      echo "#CONFIG_mysql_dump_use_separate_dirs='yes'"
    fi
    echo ""
    echo "# Choose Compression type. (gzip or bzip2)"
    if isSet COMP; then
      printf '%s=%q\n' CONFIG_mysql_dump_compression "${COMP-}"
    else
      echo "#CONFIG_mysql_dump_compression='gzip'"
    fi
    echo ""
    echo "# Store an additional copy of the latest backup to a standard"
    echo "# location so it can be downloaded by third party scripts."
    if isSet LATEST; then
      printf '%s=%q\n' CONFIG_mysql_dump_latest "${LATEST-}"
    else
      echo "#CONFIG_mysql_dump_latest='no'"
    fi
    echo ""
    echo "# Remove all date and time information from the filenames in the latest folder."
    echo "# Runs, if activated, once after the backups are completed. Practically it just finds all files in the latest folder"
    echo "# and removes the date and time information from the filenames (if present)."
    echo "#CONFIG_mysql_dump_latest_clean_filenames='no'"
    echo ""
    echo "# Notification setup"
    echo ""
    echo "# What would you like to be mailed to you?"
    echo "# - log   : send only log file"
    echo "# - files : send log file and sql files as attachments (see docs)"
    echo "# - stdout : will simply output the log to the screen if run manually."
    echo "# - quiet : Only send logs if an error occurs to the MAILADDR."
    if isSet MAILCONTENT; then
      printf '%s=%q\n' CONFIG_mailcontent "${MAILCONTENT-}"
    else
      echo "#CONFIG_mailcontent='stdout'"
    fi
    echo ""
    echo "# Set the maximum allowed email size in k. (4000 = approx 5MB email [see docs])"
    if isSet MAXATTSIZE; then
      printf '%s=%q\n' CONFIG_mail_maxattsize "${MAXATTSIZE-}"
    else
      echo "#CONFIG_mail_maxattsize=4000"
    fi
    echo ""
    echo "# Email Address to send mail to? (user@domain.com)"
    if isSet MAILADDR; then
      printf '%s=%q\n' CONFIG_mail_address "${MAILADDR-}"
    else
      echo "#CONFIG_mail_address='root'"
    fi
    echo ""
	echo '# Create differential backups. Master backups are created weekly at #$CONFIG_do_weekly weekday. Between master backups,'
	echo "# diff is used to create differential backups relative to the latest master backup. In the Manifest file, you find the"
	echo "# following structure"
	echo '# $filename 	md5sum	$md5sum	diff_id	$diff_id	rel_id	$rel_id'
	echo "# where each field is separated by the tabular character '\t'. The entries with $ at the beginning mean the actual values,"
	echo "# while the others are just for readability. The diff_id is the id of the differential or master backup which is also in"
	echo "# the filename after the last _ and before the suffixes begin, i.e. .diff, .sql and extensions. It is used to relate"
	echo '# differential backups to master backups. The master backups have 0 as $rel_id and are thereby identifiable. Differential'
	echo '# backups have the id of the corresponding master backup as $rel_id.'
	echo "#"
	echo '# To ensure that master backups are kept long enough, the value of $CONFIG_rotation_daily is set to a minimum of 21 days.'
	echo "#"
	echo "#CONFIG_mysql_dump_differential='no'"
    echo ""
    echo "# Encryption"
    echo ""
    echo "# Do you wish to encrypt your backups using openssl?"
    echo "#CONFIG_encrypt='no'"
    echo ""
    echo "# Choose a password to encrypt the backups."
    echo "#CONFIG_encrypt_password='password0123'"
    echo ""
    echo "# Other"
    echo ""
    echo "# Backup local files, i.e. maybe you would like to backup your my.cnf (mysql server configuration), etc."
    echo "# These files will be tar'ed, depending on your compression option CONFIG_mysql_dump_compression compressed and"
    echo "# depending on the option CONFIG_encrypt encrypted."
    echo "#"
    echo "# Note: This could also have been accomplished with CONFIG_prebackup or CONFIG_postbackup."
    echo "#CONFIG_backup_local_files=()"
    echo ""
    echo "# Command to run before backups (uncomment to use)"
    if isSet PREBACKUP; then
      printf '%s=%q\n' CONFIG_prebackup "${PREBACKUP-}"
    else
      echo "#CONFIG_prebackup=\"/etc/mysql-backup-pre\""
    fi
    echo ""
    echo "# Command run after backups (uncomment to use)"
    if isSet POSTBACKUP; then
      printf '%s=%q\n' CONFIG_postbackup "${POSTBACKUP-}"
    else
      echo "#CONFIG_postbackup=\"/etc/mysql-backup-post\""
    fi
    echo ""
    echo "# Uncomment to activate! This will give folders rwx------"
    echo "# and files rw------- permissions."
    echo "#umask 0077"
    echo ""
    echo "# dry-run, i.e. show what you are gonna do without actually doing it"
    echo "# inactive: =0 or commented out"
    echo "# active: uncommented AND =1"
    echo "#CONFIG_dryrun=1"
    removeIO
    mv "$temp" "${1}_converted"
    return 0
  )
}


parse_config_file () {
  printf 'Found config file %s. ' "$1"
  if head -n1 "$1" | egrep -o 'version=.*' >& /dev/null; then
    version=`head -n1 "$1" | egrep -o 'version=.*' | awk -F"=" '{print $2}'`
    if [[ "$version" =~ 3.* ]]; then
      printf 'Version 3.* determined. No conversion necessary.\n'
    else
      printf 'Unknown version. Can not convert it. You have to convert it manually.\n'
    fi
  else
    printf 'No version information on first line of config file. Assuming the version is <3.\n'
    while true; do
	read -p "Convert? [Y/n] " yn
	[[ "x$yn" = "x" ]] && { upgrade_config_file "$1" || echo "Failed to convert."; break; }
	case $yn in
	    [Yy]* ) upgrade_config_file "$1" || echo "Failed to convert."; break;;
	    [Nn]* ) break;;
	    * ) echo "Please answer yes or no.";;
	esac
    done
  fi
}

#precheck
echo "### Checking archive files for existence, readability and integrity."
echo

precheck_files=( automysqlbackup 447c33d2546181d07d0c0d69d76b189b
automysqlbackup.conf d525efa3da15ce9fea96893e5a8ce6d5
README b17740fcd3a5f8579b907a42249a83cd
LICENSE 39bba7d2cf0ba1036f2a6e2be52fe3f0
)

n=$(( ${#precheck_files[@]}/2 ))
i=0
while [ $i -lt $n ]; do
  printf "${precheck_files[$((2*$i))]} ... "
  if [ -r "${precheck_files[$((2*$i))]}" ]; then
    printf "exists and is readable ... "
  else
    printf "failed\n"
    exit 1
  fi
  if echo "${precheck_files[$((2*$i+1))]}  ${precheck_files[$((2*$i))]}" | md5sum --check >/dev/null 2>&1; then
    printf "md5sum okay :)\n"
  else
    printf "md5sum failed :(\n"
    exit 1
  fi
  let i+=1
done

echo
printf 'Select the global configuration directory [/etc/automysqlbackup]: '
read configdir
configdir="${configdir%/}" # strip trailing slash if there
[[ "x$configdir" = "x" ]] && configdir='/etc/automysqlbackup'
printf 'Select directory for the executable [/usr/local/bin]: '
read bindir
bindir="${bindir%/}" # strip trailing slash if there
[[ "x$bindir" = "x" ]] && bindir='/usr/local/bin'

#create global config directory
echo "### Creating global configuration directory ${configdir}:"
echo
if [ -d "${configdir}" ]; then
  echo "exists already ... searching for config files:"
  for i in "${configdir}"/*.conf; do
    [[ "x$(basename $i)" = "xautomysqlbackup.conf" ]] && continue
    parse_config_file "$i"
  done
else
  if mkdir "${configdir}" >/dev/null 2>&1; then
    #testing for permissions
    if [ -r "${configdir}" -a -x "${configdir}" ]; then
      printf "success\n"
    else
      printf "directory successfully created but has wrong permissions, trying to correct ... "
      if chmod +rx "${configdir}" >/dev/null 2>&1; then
	printf "corrected\n"
      else
	printf "failed. Aborting. Make sure you run the script with appropriate permissions.\n"
      fi
    fi
  else
    printf "failed ... check permissions.\n"
  fi
fi

echo
#copying files
echo "### Copying files."
echo
cp -i automysqlbackup.conf LICENSE README "${configdir}"/
cp -i automysqlbackup.conf "${configdir}"/myserver.conf
cp -i automysqlbackup "${bindir}"/
[[ -f "${bindir}"/automysqlbackup ]] && [[ -x "${bindir}"/automysqlbackup ]] || chmod +x "${bindir}"/automysqlbackup || echo " failed - make sure you make the program executable, i.e. run 'chmod +x ${bindir}/automysqlbackup'"
echo

if echo $PATH | grep "${bindir}" >/dev/null 2>&1; then
  printf "if you are running automysqlbackup under the same user as you run this install script,\nyou should be able to access it by running 'automysqlbackup' from the command line.\n"
  printf "if not, you have to check if 'echo \$PATH' has ${bindir} in it\n"
  printf "\nSetup Complete!\n"
else
  printf "if running under the current user, you have to use the full path ${bindir}/automysqlbackup since /usr/local/bin is not in 'echo \$PATH'\n"
  printf "\nSetup Complete!\n"
fi