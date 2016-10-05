#!/usr/bin/env bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
shopt -s extglob

# BEGIN _flags
let "filename_flag_encrypted=0x01"
let "filename_flag_gz=0x02"
let "filename_flag_bz2=0x04"
let "filename_flag_diff=0x08"
# END _flags

# BEGIN _errors_notifications
let "E=0x00" # no errors
let "N=0x00" # no notifications

let "E_dbdump_failed=0x01"
let "E_backup_local_failed=0x02"
let "E_mkdir_basedir_failed=0x04"
let "E_mkdir_subdirs_failed=0x08"
let "E_perm_basedir=0x10"
let "E_enc_cleartext_delfailed=0x20"
let "E_enc_failed=0x40"
let "E_db_empty=0x80"
let "E_create_pipe_failed=0x100"
let "E_missing_deps=0x200"
let "E_no_basedir=0x400"
let "E_config_backupdir_not_writable=0x800"
let "E_dump_status_failed=0x1000"
let "E_dump_fullschema_failed=0x2000"

let "N_config_file_missing=0x01"
let "N_arg_conffile_parsed=0x02"
let "N_arg_conffile_unreadable=0x04"
let "N_too_many_args=0x08"
let "N_latest_cleanup_failed=0x10"
let "N_backup_local_nofiles=0x20"
# END _errors_notifications

# BEGIN _functions

# @info:	Default configuration options.
# @deps:	(none)
load_default_config() {
  CONFIG_configfile="/etc/automysqlbackup/automysqlbackup.conf"
  CONFIG_backup_dir='/var/backup/db'
  CONFIG_multicore='yes'
  CONFIG_multicore_threads=2
  CONFIG_do_monthly="01"
  CONFIG_do_weekly="5"
  CONFIG_rotation_daily=6
  CONFIG_rotation_weekly=35
  CONFIG_rotation_monthly=150
  CONFIG_mysql_dump_port=3306
  CONFIG_mysql_dump_usessl='yes'
  CONFIG_mysql_dump_username='root'
  CONFIG_mysql_dump_password=''
  CONFIG_mysql_dump_host='localhost'
  CONFIG_mysql_dump_host_friendly=''
  CONFIG_mysql_dump_socket=''
  CONFIG_mysql_dump_create_database='no'
  CONFIG_mysql_dump_use_separate_dirs='yes'
  CONFIG_mysql_dump_compression='gzip'
  CONFIG_mysql_dump_commcomp='no'
  CONFIG_mysql_dump_latest='no'
  CONFIG_mysql_dump_latest_clean_filenames='no'
  CONFIG_mysql_dump_max_allowed_packet=''
  CONFIG_mysql_dump_single_transaction='no'
  CONFIG_mysql_dump_master_data=
  CONFIG_mysql_dump_full_schema='yes'
  CONFIG_mysql_dump_dbstatus='yes'
  CONFIG_mysql_dump_differential='no'
  CONFIG_backup_local_files=()
  CONFIG_db_names=()
  CONFIG_db_month_names=()
  CONFIG_db_exclude=( 'information_schema' )
  CONFIG_table_exclude=()
  CONFIG_mailcontent='stdout'
  CONFIG_mail_maxattsize=4000
  CONFIG_mail_splitandtar='yes'
  CONFIG_mail_use_uuencoded_attachments='no'
  CONFIG_mail_address='root'
  CONFIG_encrypt='no'
  CONFIG_encrypt_password='password0123'
}

# @return:	true, if variable is set; else false
isSet() {
  if [[ ! ${!1} && ${!1-_} ]]; then return 1; else return 0; fi
}

# @return:	true, if variable is empty; else false
isEmpty() {
  if [[ ${!1} ]]; then return 1; else return 0; fi
}

# @info:	Called when one of the signals EXIT, SIGHUP, SIGINT, SIGQUIT or SIGTERM is emitted.
#			It removes the IO redirection, mails any log file information and cleans up any temporary files.
# @args:	(none)
# @return:	(none)
mail_cleanup () {
  removeIO
  # if the variables $log_file and $log_errfile aren't set or are empty and both associated files don't exist, skip output methods.
  # this might happen if 'exit' occurs before they are set.
  if [[ ! -e "$log_file" && ! -e "$log_errfile" ]];then
    echo "Skipping normal output methods, since the program exited before any log files could be created."
  else
    case "${CONFIG_mailcontent}" in
	    'files')
			    # Include error log if larger than zero.
			    if [[ -s "$log_errfile" ]]; then
				    backupfiles=( "${backupfiles[@]}" "$log_errfile" )
				    errornote="WARNING: Error Reported - "
			    fi
				temp="$(mktemp "$CONFIG_backup_dir"/tmp/mail_content.XXXXXX)"
			    # Get backup size
			    attsize=`du -c "${backupfiles[@]}" | awk 'END {print $1}'`
			    if (( ${CONFIG_mail_maxattsize} >= ${attsize} )); then
					if [[ "x$CONFIG_mail_use_uuencoded_attachments" = "xyes" ]]; then
					  cat "$log_file" > "$temp"
					  for j in "${backupfiles[@]}"; do
						uuencode "$j" "$j" >> "$temp"
					  done
					  mail -s "${errornote} MySQL Backup Log and SQL Files for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address} < "$temp"
					else
					  mutt -s "${errornote} MySQL Backup Log and SQL Files for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" -a "${backupfiles[@]}" -- ${CONFIG_mail_address} < "$log_file"
					fi
			    elif (( ${CONFIG_mail_maxattsize} <= ${attsize} )) && [[ "x$CONFIG_mail_splitandtar" = "xyes" ]]; then
					if sPWD="$PWD"; cd "$CONFIG_backup_dir"/tmp && pax -wv "${backupfiles[@]}" | bzip2_compression | split -b $((CONFIG_mail_maxattsize*1000)) - mail_attachment_${datetimestamp}_ && cd "$sPWD"; then
					  files=("$CONFIG_backup_dir"/tmp/mail_attachment_${datetimestamp}_*)
					  echo -e "\n\nThe attachments have been split into multiple files.\nUse 'cat mail_attachment_2011-08-13_13h15m_* > mail_attachment_2011-08-13_13h15m.tar.bz2' to combine them and \
							  'bunzip2 <mail_attachment_2011-08-13_13h15m.tar.bz2 | pax -rv' to extract the content."
					  for ((j=0;j<"${#files[@]}";j++)); do
						if [[ "x$CONFIG_mail_use_uuencoded_attachments" = "xyes" ]]; then
						  if (( $j = 0 )); then
							cat "$log_file" > "$temp"
							uuencode "$j" "$j" >> "$temp"
						  else
							uuencode "$j" "$j" > "$temp"
						  fi
						  mail -s "${errornote} MySQL Backup Log and SQL Files for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address} < "$temp"
						else
						  mutt -s "${errornote} MySQL Backup Log and SQL Files for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}; Part $((j+1))/${#files[@]}" -a "${files[j]}" -- ${CONFIG_mail_address} < "$log_file"
						fi
					  done
					else
					  cat "$log_file" | mail -s "WARNING! - MySQL Backup exceeds set maximum attachment size on ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address}
					fi
				else
				    cat "$log_file" | mail -s "WARNING! - MySQL Backup exceeds set maximum attachment size on ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address}
			    fi
				rm "$temp"
			    ;;
	    'log')
			    cat "$log_file" | mail -s "MySQL Backup Log for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address}
			    [[ -s "$log_errfile" ]] && cat "$log_errfile" | mail -s "ERRORS REPORTED: MySQL Backup error Log for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address}
			    ;;
	    'quiet')
			    [[ -s "$log_errfile" ]] && cat "$log_errfile" | mail -s "ERRORS REPORTED: MySQL Backup error Log for ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host} - ${datetimestamp}" ${CONFIG_mail_address}
			    ;;
	    *)
			    if [[ -s "$log_errfile" ]]; then
					    cat "$log_file"
					    echo
					    echo "###### WARNING ######"
					    echo "Errors reported during AutoMySQLBackup execution.. Backup failed"
					    echo "Error log below.."
					    cat "$log_errfile"
			    else
				  cat "$log_file"
			    fi
			    ;;
    esac
    ###################################################################################
    # Clean up and finish
    [[ -e "$log_file" ]] && rm -f "$log_file"
    [[ -e "$log_errfile" ]] && rm -f "$log_errfile"
  fi
}

# @params:	#month	#year
# @deps:	(none)
days_of_month() {
  m="$1"; y="$2"; a=$(( 30+(m+m/8)%2 ))
  (( m==2 )) && a=$((a-2))
  (( m==2 && y%4==0 && ( y<100 || y%100>0 || y%400==0) )) && a=$((a+1))
  printf '%d' $a
}

# @info:	Checks if a folder is writable by creating a temporary file in it and removing it afterwards.
# @args:	folder to test
# @return:	returns false if creation of temporary file failed or it can't be removed afterwards; else true
# @deps:	(none)
chk_folder_writable () {
  local temp; temp="$(mktemp "$1"/tmp.XXXXXX)"
  if (( $? == 0 )); then
    rm "${temp}" || return 1
    return 0
  else
    return 1
  fi
}

# @info:	bzip2 compression
bzip2_compression() {
  var=("$@")
  re='^[0-9]*$'
  if [[ "x$CONFIG_multicore" = 'xyes' ]]; then
	  if [[ "x$CONFIG_multicore_threads" != 'xauto' ]] && [[ "x$CONFIG_multicore_threads" =~ $re ]]; then
		  var=( "-p${CONFIG_multicore_threads}" "${var[@]}" )
	  fi
	  pbzip2 "${var[@]}"
  else
	  bzip2 "${var[@]}"
  fi
}

# @info:	gzip compression
gzip_compression() {
  var=("$@")
  re='^[0-9]*$'
  if [[ "x$CONFIG_multicore" = 'xyes' ]]; then
	  if [[ "x$CONFIG_multicore_threads" != 'xauto' ]] && [[ "x$CONFIG_multicore_threads" =~ $re ]]; then
		  var=( "-p${CONFIG_multicore_threads}" "${var[@]}" )
	  fi
	  pigz "${var[@]}"
  else
	  gzip "${var[@]}"
  fi
}

# @info:	Remove date and time information from filename by renaming it.
# @args:	filename
# @return:	(none)
# @deps:	(none)
remove_datetimeinfo () {
  mv "$1" "$(echo "$1" | sed -re 's/_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}h[0-9]{2}m_(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|January|February|March|April|May|June|July|August|September|October|November|December|[0-9]{1,2})//g')"
}
export -f remove_datetimeinfo

# @info:	Set time and date variables.
# @args:	(none)
# @deps:	days_of_month
set_datetime_vars() {
  datetimestamp=`date +%Y-%m-%d_%Hh%Mm`		# Datestamp e.g 2002-09-21_18h12m
  date_stamp=`date +%Y-%m-%d`					# Datestamp e.g 2002-09-21
  date_day_of_week=`date +%A`					# Day of the week e.g. Monday
  date_dayno_of_week=`date +%u`				# Day number of the week 1 to 7 where 1 represents Monday
  date_day_of_month=`date +%e | sed -e 's/^ //'`				# Date of the Month e.g. 27
  date_month=`date +%B`						# Month e.g January
  date_weekno=`date +%V | sed -e 's/^0//'`	# Week Number e.g 37
  year=`date +%Y`
  month=`date +%m | sed -e 's/^0//'`
  date_lastday_of_last_month=$(days_of_month $(( $month==1 ? 12 : $month-1 )) $(( $month==1 ? ($year-1):$year )) )
  date_lastday_of_this_month=$(days_of_month $month $year)
}

# @info:	This function is called after data has already been saved. It performs encryption and
#			hardlink-copying of files to a latest folder.
# @return:	flags
# @deps:	load_default_config
files_postprocessing () {
	local flags
	let "flags=0x00"
	let "flags_files_postprocessing_success_encrypt=0x01"

	# -> CONFIG_encrypt
	[[ "${CONFIG_encrypt}" = "yes" && "${CONFIG_encrypt_password}" ]] && {
	  if (( $CONFIG_dryrun )); then
	    printf 'dry-running: openssl enc -aes-256-cbc -e -in %s -out %s.enc -pass pass:%s\n' ${1} ${1} "${CONFIG_encrypt_password}"
	  else
	    openssl enc -aes-256-cbc -e -in ${1} -out ${1}.enc -pass pass:"${CONFIG_encrypt_password}"
	    if (( $? == 0 )); then
		  if rm ${1} 2>&1; then
		    echo "Successfully encrypted archive as ${1}.enc"
		    let "flags |= $flags_files_postprocessing_success_encrypt"
		  else
		    echo "Successfully encrypted archive as ${1}.enc, but could not remove cleartext file ${1}."
		    let "E |= $E_enc_cleartext_delfailed"
		  fi
	    else
		  let "E |= $E_enc_failed"
	    fi
	  fi
	}
	# <- CONFIG_encrypt

	# -> CONFIG_mysql_dump_latest
	[[ "${CONFIG_mysql_dump_latest}" = "yes" ]] && {
	  if (( $flags & $flags_files_postprocessing_success_encrypt )); then
		if (( $CONFIG_dryrun )); then
		  printf 'dry-running: cp -al %s.enc %s/latest/\n' "${1}" "${CONFIG_backup_dir}"
		else
		  cp -al "${1}${suffix}.enc" "${CONFIG_backup_dir}"/latest/
		fi
	  else
		if (( $CONFIG_dryrun )); then
		  printf 'dry-running: cp -al %s %s/latest/\n' "${1}" "${CONFIG_backup_dir}"
		else
		  cp -al "${1}" "${CONFIG_backup_dir}"/latest/
		fi
	  fi
	}
	# <- CONFIG_mysql_dump_latest

	return $flags
}

# @info:	When called, sets error and notify strings matching their flags. It then goes through all
#			collected error and notify messages and displays them.
# @args:	(none)
# @return:	true if no errors were set, otherwise false
# @deps:	log_base2, load_default_config
error_handler () {

  errors=(
    [0x01]='dbdump() failed.'
    [0x02]='Backup of local files failed. This is not this scripts primary objective. Continuing anyway.'
    [0x04]="Could not create the backup_dir ${CONFIG_backup_dir}. Please check permissions of the higher directory."
    [0x08]='At least one of the subdirectories (daily, weekly, monthly, latest) failed to create.'
    [0x10]="The backup_dir ${CONFIG_backup_dir} is not writable AND/OR executable."
    [0x20]='Could not remove the cleartext file after encryption. This error did not cause an abort. Remove it manually and check permissions.'
    [0x40]='Encryption failed. Continuing without encryption.'
    [0x80]='The mysql server is empty, i.e. no databases found. Check if something is wrong. Exiting.'
    [0x100]='Failed to create the named pipe (fifo) for reading in all databases. Exiting.'
    [0x200]='Dependency programs are missing. Perhaps they are not in $PATH. Exiting.'
    [0x400]='No basedir found, i.e. '
    [0x800]="${CONFIG_backup_dir} is not writable. Exiting."
    [0x1000]='Running of mysqlstatus failed.'
    [0x2000]='Running of mysqldump full schema failed.'
  )

  notify=(
    [0x01]="${CONFIG_configfile} was not found - no global config file."
    [0x02]="Parsed config file ${opt_config_file}."
    [0x04]="Unreadable config file \"${opt_config_file}\""
    [0x08]='Supplied more than one argument, ignoring ALL arguments - using default and global config file only.'
    [0x10]='Could not remove the files in the latest directory. Please check this.'
    [0x20]='No local backup files were set.'
    [0x40]=''
    [0x80]=''
    [0x100]=''
    [0x200]=''
    [0x400]=''
    [0x800]=''
    [0x1000]=''
    [0x2000]=''
  )

  local n
  local e

  n=$((${#notify[@]}-1))
  while (( N > 0 )); do
    e=$((2**n))
    if (( N&e )); then
      echo "Note:" ${notify[e]}
      let "N-=e"
    fi
    ((n--))
  done
  unset n;

  n=$((${#errors[@]}-1))
  if (( E > 0 )); then
    while (( E > 0 )); do
      e=$((2**n))
      if (( E&e )); then
	echo "Error:" ${errors[e]}
	let "E-=e"
      fi
      ((n--))
    done
    exit 1
  else
    exit 0
  fi
}

# @info:	Packs files in array ${#CONFIG_backup_local_files[@]} into tar file with optional compression.
# @args:	archive file without compression suffix, i.e. ending on .tar
# @return:	true in case of dry-run, otherwise the return value of tar -cvf
# @deps:	load_default_config
backup_local_files () {
  if ((! ${#CONFIG_backup_local_files[@]})) ; then
    if (( $CONFIG_dryrun )); then
      case "${CONFIG_mysql_dump_compression}" in
	  'gzip')
	    echo "tar -czvf ${1}${suffix} ${CONFIG_backup_local_files[@]}";
	    ;;
	  'bzip2')
	    echo "tar -cjvf ${1}${suffix} ${CONFIG_backup_local_files[@]}";
	    ;;
	  *)
	    echo "tar -cvf ${1}${suffix} ${CONFIG_backup_local_files[@]}";
	    ;;
      esac
      echo "dry-running: tar -cv ${1} ${CONFIG_backup_local_files[@]}"
      return 0;
    else
      case "${CONFIG_mysql_dump_compression}" in
	  'gzip')
	    tar -czvf "${1}${suffix}" "${CONFIG_backup_local_files[@]}";
	    return $?
	    ;;
	  'bzip2')
	    tar -cjvf "${1}${suffix}" "${CONFIG_backup_local_files[@]}";
	    return $?
	    ;;
	  *)
	    tar -cvf "${1}${suffix}" "${CONFIG_backup_local_files[@]}";
	    return $?
	    ;;
      esac
    fi
  else
    let "N |= $N_backup_local_nofiles"
    echo "No local backup files specified."
  fi
}

# @info:	Parses the configuration options and sets the variables appropriately.
# @args:	(none)
# @deps:	load_default_config
parse_configuration () {
    # OPT string for use with mysqldump ( see man mysqldump )
    opt=( '--quote-names' '--opt' )

    # OPT string for use with mysql (see man mysql )
    mysql_opt=()

    # OPT string for use with mysqldump fullschema
    opt_fullschema=( '--all-databases' '--routines' '--no-data' )

	# OPT string for use with mysqlstatus
	opt_dbstatus=( '--status' )

    [[ "${CONFIG_mysql_dump_usessl}" = "yes" ]] 		&& {
	  opt=( "${opt[@]}" '--ssl' )
	  mysql_opt=( "${mysql_opt[@]}" '--ssl' )
	  opt_fullschema=( "${opt_fullschema[@]}" '--ssl' )
	  opt_dbstatus=( "${opt_dbstatus[@]}" '--ssl' )
    }
    [[ "${CONFIG_mysql_dump_master_data}" ]] && (( ${CONFIG_mysql_dump_master_data} == 1 || ${CONFIG_mysql_dump_master_data} == 2 )) && { opt=( "${opt[@]}" "--master-data=${CONFIG_mysql_dump_master_data}" );}
    [[ "${CONFIG_mysql_dump_single_transaction}" = "yes" ]]	&& {
	  opt=( "${opt[@]}" '--single-transaction' )
	  opt_fullschema=( "${opt_fullschema[@]}" '--single-transaction' )
    }
    [[ "${CONFIG_mysql_dump_commcomp}" = "yes" ]]		&& {
	  opt=( "${opt[@]}" '--compress' )
	  opt_fullschema=( "${opt_fullschema[@]}" '--compress' )
	  opt_dbstatus=( "${opt_dbstatus[@]}" '--compress' )
    }
    [[ "${CONFIG_mysql_dump_max_allowed_packet}" ]]		&& {
	  opt=( "${opt[@]}" "--max_allowed_packet=${CONFIG_mysql_dump_max_allowed_packet}" )
	  opt_fullschema=( "${opt_fullschema[@]}" "--max_allowed_packet=${CONFIG_mysql_dump_max_allowed_packet}" )
    }
    [[ "${CONFIG_mysql_dump_socket}" ]]			&& {
	  opt=( "${opt[@]}" "--socket=${CONFIG_mysql_dump_socket}" )
	  mysql_opt=( "${mysql_opt[@]}" "--socket=${CONFIG_mysql_dump_socket}" )
	  opt_fullschema=( "${opt_fullschema[@]}" "--socket=${CONFIG_mysql_dump_socket}" )
	  opt_dbstatus=( "${opt_dbstatus[@]}" "--socket=${CONFIG_mysql_dump_socket}" )
    }
    [[ "${CONFIG_mysql_dump_port}" ]]			&& {
	  opt=( "${opt[@]}" "--port=${CONFIG_mysql_dump_port}" )
	  mysql_opt=( "${mysql_opt[@]}" "--port=${CONFIG_mysql_dump_port}" )
	  opt_fullschema=( "${opt_fullschema[@]}" "--port=${CONFIG_mysql_dump_port}" )
	  opt_dbstatus=( "${opt_dbstatus[@]}" "--port=${CONFIG_mysql_dump_port}" )
    }

    # Check if CREATE DATABASE should be included in Dump
    if [[ "${CONFIG_mysql_dump_use_separate_dirs}" = "yes" ]]; then
	    if [[ "${CONFIG_mysql_dump_create_database}" = "no" ]]; then
		    opt=( "${opt[@]}" '--no-create-db' )
	    else
		    opt=( "${opt[@]}" '--databases' )
	    fi
    else
	    opt=( "${opt[@]}" '--databases' )
    fi
      
	# if differential backup is active and the specified rotation is smaller than 21 days, set it to 21 days to ensure, that
	# master backups aren't deleted.
	if [[ "x$CONFIG_mysql_dump_differential" = "xyes" ]] && (( ${CONFIG_rotation_daily} < 21 )); then
	  CONFIG_rotation_daily=21
	fi

    # -> determine suffix
    case "${CONFIG_mysql_dump_compression}" in
      'gzip')	suffix='.gz';;
      'bzip2')	suffix='.bz2';;
      *)		suffix='';;
    esac
    # <- determine suffix

	# -> check exclude tables for wildcards
	local tmp;tmp=()
	local z;z=0
	for i in "${CONFIG_table_exclude[@]}"; do
	  r='^[^*.]+\.[^.]+$'; [[ "$i" =~ $r ]] || { printf 'The entry %s in CONFIG_table_exclude has a wrong format. Ignoring the entry.' "$i"; continue; }
	  db=${i%.*}
	  table=${i#"$db".}
	  r='\*'; [[ "$i" =~ $r ]] || { tmp[z++]="$i"; continue; }
	  while read -r; do tmp[z++]="${db}.${REPLY}"; done < <(mysql --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${mysql_opt[@]}" --batch --skip-column-names -e "select table_name from information_schema.tables where table_schema='${db}' and table_name like '${table//\*/%}';")
	done
	for l in "${tmp[@]}"; do echo "exclude $l";done
	CONFIG_table_exclude=("${tmp[@]}")
	# <-

    if ((${#CONFIG_table_exclude[@]})); then
      for i in "${CONFIG_table_exclude[@]}"; do
		opt=( "${opt[@]}" "--ignore-table=$i" )
      done
    fi
}

# @info:	Backup database status
# @args:	archive file without compression suffix, i.e. ending on .txt
# @return:	true in case of dry-run, otherwise the return value of mysqlshow
# @deps:	load_default_config, parse_configuration
dbstatus() {
  if (( $CONFIG_dryrun )); then
    case "${CONFIG_mysql_dump_compression}" in
	'gzip')
	  echo "dry-running: mysqlshow --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_dbstatus[@]} | gzip_compression > ${1}${suffix}";
	  ;;
	'bzip2')
	  echo "dry-running: mysqlshow --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_dbstatus[@]} | bzip2_compression > ${1}${suffix}";
	  ;;
	*)
	  echo "dry-running: mysqlshow --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_dbstatus[@]} > ${1}${suffix}";
	  ;;
    esac
    return 0;
  else
    case "${CONFIG_mysql_dump_compression}" in
	'gzip')
	  mysqlshow --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_dbstatus[@]}" | gzip_compression > "${1}${suffix}";
	  return $?
	  ;;
	'bzip2')
	  mysqlshow --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_dbstatus[@]}" | bzip2_compression > "${1}${suffix}";
	  return $?
	  ;;
	*)
	  mysqlshow --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_dbstatus[@]}" > "${1}${suffix}";
	  return $?
	  ;;
    esac
  fi
}

# @info:	Backup of the database schema.
# @args:	filename to save data to
# @return:	true in case of dry-run, otherwise the return value of mysqldump
# @deps:	load_default_config, parse_configuration
fullschema () {
  if (( $CONFIG_dryrun )); then
    case "${CONFIG_mysql_dump_compression}" in
	'gzip')
	  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_fullschema[@]} | gzip_compression > ${1}${suffix}";
	  ;;
	'bzip2')
	  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_fullschema[@]} | bzip2_compression > ${1}${suffix}";
	  ;;
	*)
	  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt_fullschema[@]} > ${1}${suffix}";
	  ;;
    esac
    return 0;
  else
    case "${CONFIG_mysql_dump_compression}" in
	'gzip')
	  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_fullschema[@]}" | gzip_compression > "${1}${suffix}";
	  return $?
	  ;;
	'bzip2')
	  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_fullschema[@]}" | bzip2_compression > "${1}${suffix}";
	  return $?
	  ;;
	*)
	  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt_fullschema[@]}" > "${1}${suffix}";
	  return $?
	  ;;
    esac
  fi
}

# @info:	Process a single db.
# @args:	subfolder, prefix, midfix, extension, rotation, rotation_divisor, rotation_string, 0/1 (db/dbs), db[, db ...]
process_dbs() {
  local subfolder="$1"
  local prefix="$2"
  local midfix="$3"
  local extension="$4"
  local rotation="$5"
  local rotation_divisor="$6"
  local rotation_string="$7"
  local multipledbs="$8"
  shift 8

  local name
  local subsubfolder

  # only activate differential backup for daily backups
  [[ "x$subfolder" != "xdaily" ]] && activate_differential_backup=0 || activate_differential_backup=1

  if (( $multipledbs )); then
	# multiple dbs
	subsubfolder=""
	name="all-databases"
  else
	# single db
	subsubfolder="/$1"
	name="$@"
  fi

  [[ -d "${CONFIG_backup_dir}/${subfolder}${subsubfolder}" ]] || {
  if (( $CONFIG_dryrun )); then
      printf 'dry-running: mkdir -p %s/${subfolder}%s\n' "${CONFIG_backup_dir}" "${subsubfolder}"
    else
      mkdir -p "${CONFIG_backup_dir}/${subfolder}${subsubfolder}"
    fi
  }

  manifest_file="${CONFIG_backup_dir}/${subfolder}${subsubfolder}/Manifest"
  fname="${CONFIG_backup_dir}/${subfolder}${subsubfolder}/${prefix}${name}_${datetimestamp}${midfix}${extension}"

  (( $CONFIG_debug )) && echo "DEBUG: process_dbs >> Setting manifest file to: ${manifest_file}" 

  if (( $multipledbs )); then
	# multiple databases
	db="all-databases"
  else
	# single db
	db="$1"
  fi

  if [[ "x$CONFIG_mysql_dump_differential" = "xyes" ]] && [[ "x${CONFIG_encrypt}" != "xyes" ]] && (( $activate_differential_backup )); then


	  unset manifest_entry manifest_entry_to_check

	  echo "## Reading in Manifest file"
	  parse_manifest "$manifest_file"
	  echo
	  echo "Number of manifest entries: $(num_manifest_entries)"
	  echo


	  # -> generate diff file
	  let "filename_flags=0x00"
	  
# 	  ## -> get latest differential manifest entry for specified db
# 	  if get_latest_manifest_entry_for_db "$db" 1; then
# 		pid="${manifest_entry[2]}"
# 		# filename format: prefix_db_YYYY-MM-DD_HHhMMm_[A-Za-z0-9]{8}(.sql|.diff)(.gz|.bz2)(.enc)
# 		FileStub=${manifest_entry[0]%.@(sql|diff)*}
# 		FileExt=${manifest_entry[0]#"$FileStub"}
# 		re=".*\.enc.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_encrypted"
# 		re=".*\.gz.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_gz"
# 		re=".*\.bz2.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_bz2"
# 		re=".*\.diff.*";	[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_diff"
# 		manifest_latest_diff_entry=("${manifest_entry[@]}")
# 	  else	# no entries in manifest
# 		pid=0
# 	  fi
# 	  ## <- get latest differential manifest entry for specified db

	  ## -> get latest master manifest entry for specified db
	  # Create a differential backup if a master entry in the manifest exists, it isn't the day we do weekly master backups or the master file we fetched is already from today.
	  if get_latest_manifest_entry_for_db "$db" 0 && ( (( ${date_dayno_of_week} != ${CONFIG_do_weekly} )) || [[ "${manifest_entry[0]}" = *_$(date +%Y-%m-%d)_* ]] ); then
		pid="${manifest_entry[2]}"
		# filename format: prefix_db_YYYY-MM-DD_HHhMMm_[A-Za-z0-9]{8}(.sql|.diff)(.gz|.bz2)(.enc)
		FileStub="${manifest_entry[0]%.@(sql|diff)*}"
		FileExt="${manifest_entry[0]#"$FileStub"}"
		re=".*\.enc.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_encrypted"
		re=".*\.gz.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_gz"
		re=".*\.bz2.*";		[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_bz2"
		re=".*\.diff.*";	[[ "$FileExt" =~ $re ]] && let "filename_flags|=$filename_flag_diff"
		manifest_latest_master_entry=("${manifest_entry[@]}")
	  else	# no entries in manifest
		pid=0
	  fi
	  ## <- get latest master manifest entry for specified db

  fi

  if [[ "x$CONFIG_mysql_dump_differential" = "xyes" ]] && [[ "x${CONFIG_encrypt}" != "xyes" ]] && (( $activate_differential_backup )) && ((! ($filename_flags & $filename_flag_encrypted) )); then

	  # the master file is encrypted ... well this just shouldn't happen ^^ not going to decrypt or stuff like that ...at least not today :)

	  if [[ "x$pid" = "x0" ]]; then
		# -> create master backup
		cfname="$(mktemp "${fname%.sql}_"XXXXXXXX".sql${suffix}")"
		uid="${cfname%.@(diff|sql)*}"
		uid="${uid:-8:8}"
		case "${CONFIG_mysql_dump_compression}" in
		'gzip')
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" | gzip_compression > "$cfname";
		  ;;
		'bzip2')
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" | bzip2_compression > "$cfname";
		  ;;
		*)
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" > "$cfname";
		  ;;
		esac
		add_manifest_entry "$manifest_file" "$cfname" "$pid" "$db" && parse_manifest "$manifest_file" && cp -al "$cfname" "${CONFIG_backup_dir}"/latest/ && echo "Generated master backup $cfname" && return 0 || return 1
		# <- create master backup
	  else
		cfname="$(mktemp "${fname%.sql}_"XXXXXXXX".diff${suffix}")"
		uid="${cfname%.@(diff|sql)*}"
		uid=${uid:-8:8}
		echo "Creating differential backup to ${manifest_entry[0]}:"
		case "${CONFIG_mysql_dump_compression}" in
		'gzip')
		  if (( $filename_flags & $filename_flag_gz )); then
			diff <(gzip_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | gzip_compression > "$cfname";
		  elif (( $filename_flags & $filename_flag_bz2 )); then
			diff <(bzip2_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | gzip_compression > "$cfname";
		  else
			diff "${manifest_latest_master_entry[0]}" <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | gzip_compression > "$cfname";
		  fi
		  ;;
		'bzip2')
		  if (( $filename_flags & $filename_flag_gz )); then
			diff <(gzip_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | bzip2_compression > "$cfname";
		  elif (( $filename_flags & $filename_flag_bz2 )); then
			diff <(bzip2_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | bzip2_compression > "$cfname";
		  else
			diff "${manifest_latest_master_entry[0]}" <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") | bzip2_compression > "$cfname";
		  fi
		  ;;
		*)
		  if (( $filename_flags & $filename_flag_gz )); then
			diff <(gzip_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") > "$cfname";
		  elif (( $filename_flags & $filename_flag_bz2 )); then
			diff <(bzip2_compression -dc "${manifest_latest_master_entry[0]}") <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") > "$cfname";
		  else
			diff "${manifest_latest_master_entry[0]}" <(mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@") > "$cfname";
		  fi
		  ;;
		esac
		add_manifest_entry "$manifest_file" "$cfname" "$pid" "$db" && parse_manifest "$manifest_file" && cp -al "$cfname" "${manifest_latest_master_entry[0]}" "${CONFIG_backup_dir}"/latest/ && echo "generated $cfname" && return 0 || return 1
		
	  fi
	  # <- generate diff filename

  else
	  cfname="${fname}${suffix}"
	  if (( $CONFIG_dryrun )); then
		case "${CONFIG_mysql_dump_compression}" in
		'gzip')
		  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt[@]} $@ | gzip_compression > ${cfname}"
		  ;;
		'bzip2')
		  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt[@]} $@ | bzip2_compression > ${cfname}"
		  ;;
		*)
		  echo "dry-running: mysqldump --user=${CONFIG_mysql_dump_username} --password=${CONFIG_mysql_dump_password} --host=${CONFIG_mysql_dump_host} ${opt[@]} $@ > ${cfname}"
		  ;;
		esac
		return 0;
	  else
		case "${CONFIG_mysql_dump_compression}" in
		'gzip')
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" | gzip_compression > "${cfname}"
		  ret=$?
		  ;;
		'bzip2')
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" | bzip2_compression > "${cfname}"
		  ret=$?
		  ;;
		*)
		  mysqldump --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${opt[@]}" "$@" > "${cfname}"
		  ret=$?
		  ;;
		esac
	  fi

  fi
  

  if (( $ret == 0 )); then
	  echo "Rotating $(( ${rotation}/${rotation_divisor} )) ${rotation_string} backups for ${name}"
	  if (( $CONFIG_dryrun )); then
	    find "${CONFIG_backup_dir}/${subfolder}${subsubfolder}" -mtime +"${rotation}" -type f -exec echo "dry-running: rm" {} \;
	  else
	    find "${CONFIG_backup_dir}/${subfolder}${subsubfolder}" -mtime +"${rotation}" -type f -exec rm {} \;
	  fi
	  files_postprocessing "$cfname"
	  tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
	  backupfiles=( "${backupfiles[@]}" "${cfname}${var}" )
  else
	  let "E |= $E_dbdump_failed"
	  echo "dbdump with parameters \"${CONFIG_db_names[@]}\" \"${cfname}\" failed!"
  fi
}

# @info:	Save stdout and stderr
# @deps:	(none)
activateIO() {
  ###################################################################################
  # IO redirection for logging.
  # $1 = $log_file, $2 = $log_errfile

  #(( $CONFIG_debug )) || {
    touch "$log_file"
    exec 6>&1				# Link file descriptor #6 with stdout. Saves stdout.
    exec > "$log_file"		# stdout replaced with file $log_file.

    touch "$log_errfile"
    exec 7>&2				# Link file descriptor #7 with stderr. Saves stderr.
    exec 2> "$log_errfile"	# stderr replaced with file $log_errfile.
  #}
}

# @info:	Restore stdout and stderr redirections.
# @deps:	(none)
removeIO() {
  exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
  exec 2>&7 7>&-      # Restore stdout and close file descriptor #7.
}

# @info:	Checks directories and subdirectories for existence and activates logging to either
#		$CONFIG_backup_dir or /tmp depending on what exists.
# @args:	(none)
# @deps:	load_default_config, activateIO, chk_folder_writable, error_handler
directory_checks_enable_logging () {
    ###################################################################################
    # Check directories and do cleanup work

    checkdirs=( "${CONFIG_backup_dir}"/{daily,weekly,monthly,latest,tmp} )
    [[ "${CONFIG_backup_local_files[@]}" ]] && { checkdirs=( "${checkdirs[@]}" "${CONFIG_backup_dir}/backup_local_files" ); }
    [[ "${CONFIG_mysql_dump_full_schema}" = 'yes' ]] && { checkdirs=( "${checkdirs[@]}" "${CONFIG_backup_dir}/fullschema" ); }
	[[ "${CONFIG_mysql_dump_dbstatus}" = 'yes' ]] && { checkdirs=( "${checkdirs[@]}" "${CONFIG_backup_dir}/status" ); }

    tmp_permcheck=0
    printf '# Checking for permissions to write to folders:\n'


    # "dirname ${CONFIG_backup_dir}" exists?
    # Y -> ${CONFIG_backup_dir} exists?
    #      Y -> Dry-run?
    #           Y -> log to /tmp, proceed to test subdirs
    #           N -> check writable ${CONFIG_backup_dir}?
    #                Y -> proceed to test subdirs
    #                N -> error: can't write to ${CONFIG_backup_dir}. Exit.
    #      N -> Dry-run?
    #           N -> proceed without testing subdirs
    #           Y -> create directory ${CONFIG_backup_dir}?
    #                Y -> check writable ${CONFIG_backup_dir}?
    #                     Y -> proceed to test subdirs
    #                     N -> error: can't write to ${CONFIG_backup_dir}. Exit.
    #                N -> error: ${CONFIG_backup_dir} is not writable. Exit.
    # N -> Dry-run?
    #      Y -> log to /tmp, proceed without testing subdirs
    #      N -> error: no basedir. Exit.


    # -> check base folder
    printf 'base folder %s ... ' "$(dirname "${CONFIG_backup_dir}")"
    if [[ -d "$(dirname "${CONFIG_backup_dir}")" ]]; then

	printf 'exists ... ok.\n'
	printf 'backup folder %s ... ' "${CONFIG_backup_dir}"

	if [[ -d "${CONFIG_backup_dir}" ]]; then
	    printf 'exists ... writable? ' 
	    if (( $CONFIG_dryrun )); then
	      printf 'dry-running. Skipping. Logging to /tmp\n'
	      log_file="/tmp/${CONFIG_mysql_dump_host}-`date +%N`.log"
	      log_errfile="/tmp/ERRORS_${CONFIG_mysql_dump_host}-`date +%N`.log"
	      activateIO "$log_file" "$log_errfile"
	      tmp_permcheck=1
	    else
		if chk_folder_writable "${CONFIG_backup_dir}"; then
		  printf 'yes. Proceeding.\n'
		  log_file="${CONFIG_backup_dir}/${CONFIG_mysql_dump_host}-`date +%N`.log"
		  log_errfile="${CONFIG_backup_dir}/ERRORS_${CONFIG_mysql_dump_host}-`date +%N`.log"
		  activateIO "$log_file" "$log_errfile"
		  tmp_permcheck=1
		else
		  printf 'no. Exiting.\n'
		  let "E |= $E_config_backupdir_not_writable"
		  error_handler
		fi
	    fi

	else

	    printf 'creating ... '
	    if (( $CONFIG_dryrun )); then
		printf 'dry-running. Skipping.\n'
	    else
		if mkdir -p "${CONFIG_backup_dir}" >/dev/null 2>&1; then
		  printf 'success.\n'
		  log_file="${CONFIG_backup_dir}/${CONFIG_mysql_dump_host}-`date +%N`.log"
		  log_errfile="${CONFIG_backup_dir}/ERRORS_${CONFIG_mysql_dump_host}-`date +%N`.log"
		  activateIO "$log_file" "$log_errfile"
		  tmp_permcheck=1
		else
		  printf 'failed. Exiting.\n'
		  let "E |= $E_mkdir_basedir_failed"
		  error_handler
		fi
	    fi

	fi

    else

	if (( $CONFIG_dryrun )); then
	    printf 'dry-running. Skipping. Logging to /tmp\n'
	    log_file="/tmp/${CONFIG_mysql_dump_host}-`date +%N`.log"
	    log_errfile="/tmp/ERRORS_${CONFIG_mysql_dump_host}-`date +%N`.log"
	    activateIO "$log_file" "$log_errfile"
	else
	  printf 'does not exist. Exiting.\n'
	  let "E |= $E_no_basedir"
	  error_handler
	fi

    fi
    # <- check base folder


    # -> check subdirs
    if (( $tmp_permcheck ==  1 )); then

	(( $CONFIG_dryrun )) || [[ -r "${CONFIG_backup_dir}" && -x "${CONFIG_backup_dir}" ]] || { let "E |= $E_perm_basedir"; error_handler; }

	for i in "${checkdirs[@]}"; do
	  printf 'checking directory "%s" ... ' "$i"
	  if [[ -d "$i" ]]; then
	    printf 'exists.\n'
	  else
	    printf 'creating ... '
	    if (( $CONFIG_dryrun )); then
	      printf 'dry-running. Skipping.\n'
	    else
		if mkdir -p "$i" >/dev/null 2>&1; then
		  printf 'success.\n'
		else
		  printf 'failed. Exiting.\n'
		  let "E |= $E_mkdir_subdirs_failed"
		  error_handler
		fi
	    fi
	  fi
	done

    fi
    # <- check subdirs

}

# @info:	If CONFIG_mysql_dump_latest is set to 'yes', the directory ${CONFIG_backup_dir}"/latest will
#			be cleaned.
# @args:	(none)
# @deps:	load_default_config
cleanup_latest ()  {
    # -> latest cleanup
    if [[ "${CONFIG_mysql_dump_latest}" = "yes" ]]; then
      printf 'Cleaning up latest directory ... '
      if (( $CONFIG_dryrun )); then
	printf 'dry-running. Skipping.\n'
      else
	if rm -f "${CONFIG_backup_dir}"/latest/* >/dev/null 2>&1; then
	  printf 'success.\n'
	else
	  printf 'failed. Continuing anyway, activating Note-Flag.\n'
	  let "N |= $N_latest_cleanup_failed"
	fi
      fi
    fi
    # <- latest cleanup
}

# @info:	Checks for dependencies in form of external programs, that need to be available when running
#			this program.
# @args:	(none)
# @deps:	load_default_config
check_dependencies () {
    echo
    echo "# Testing for installed programs"
    dependencies=( 'mysql' 'mysqldump' )

	if [[ "x$CONFIG_multicore" = 'xyes' ]]; then

		if [[ "x$CONFIG_mysql_dump_compression" = 'xbzip2' ]]; then
		  if type pbzip2 &>/dev/null; then
		    echo "pbzip2 ... found."
		  else
		    CONFIG_multicore='no' # turn off multicore support, since the program isn't there
		    echo "WARNING: Turning off multicore support, since pbzip2 isn't there."
		  fi
		elif [[ "x$CONFIG_mysql_dump_compression" = 'xgzip' ]]; then
		  if type pigz &>/dev/null; then
		    echo "pigz ... found."
		  else
		    CONFIG_multicore='no' # turn off multicore support, since the program isn't there
		    echo "WARNING: Turning off multicore support, since pigz isn't there."
		  fi
		fi

	else
		[[ "x$CONFIG_mysql_dump_compression" = 'xbzip2' ]] && dependencies=("${dependencies[@]}" 'bzip2' )
		[[ "x$CONFIG_mysql_dump_compression" = 'xgzip' ]] && dependencies=("${dependencies[@]}" 'gzip' )
	fi	  

    if [[ "x$CONFIG_mailcontent" = 'xlog' || "x$CONFIG_mailcontent" = 'xquiet' ]]; then
      dependencies=( "${dependencies[@]}" 'mail' )
    elif [[ "x$CONFIG_mailcontent" = 'xfiles' ]]; then
	  dependencies=( "${dependencies[@]}" 'mail' )
	  if [[ "x$CONFIG_mail_use_uuencoded_attachments" != 'xyes' ]]; then
		dependencies=( "${dependencies[@]}" 'mutt' )
	  fi
    fi

    for i in "${dependencies[@]}"; do
      printf '%s ... ' "$i"
      if type "$i" &>/dev/null; then
		printf 'found.\n'
      else
		printf 'not found. Aborting.\n';
		let "E |= $E_missing_deps"
		error_handler
      fi
    done
    echo
}

# @info:	Get database list and remove excluded ones.
# @args:	(none)
# @deps:	load_default_config, error_handler
#
#	alldbnames = array of all databases
#	empty?	->	error
#	remove excludes from array alldbnames
#	CONFIG_db_names empty? -> set to alldbnames
#	CONFIG_db_month_names empty? -> set to alldbnames
#
parse_databases() {
  # bash 4.x version
  #mapfile -t alldbnames < <(mysql --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" --batch --skip-column-names -e "show databases")
  alldbnames=()

  printf "# Parsing databases ... "
  # bash 3.0
  local i;i=0;
  while read -r; do alldbnames[i++]="$REPLY"; done < <(mysql --user="${CONFIG_mysql_dump_username}" --password="${CONFIG_mysql_dump_password}" --host="${CONFIG_mysql_dump_host}" "${mysql_opt[@]}" --batch --skip-column-names -e "show databases")
  unset i

  # mkfifo foo || exit; trap 'rm -f foo' EXIT

  ((! "${#alldbnames[@]}" )) && { let "E |= $E_db_empty"; error_handler; }

  # -> remove excluded dbs from list
  for exclude in "${CONFIG_db_exclude[@]}"; do
	for i in "${!alldbnames[@]}"; do if [[ "x${alldbnames[$i]}" = "x${exclude}" ]]; then unset 'alldbnames[i]'; fi; done
  done
  # <- remove excluded dbs from list

  # check for empty array lists and copy all dbs
  ((! ${#CONFIG_db_names[@]}))	&& CONFIG_db_names=( "${alldbnames[@]}" )
  ((! ${#CONFIG_db_month_names[@]}))	&& CONFIG_db_month_names=( "${alldbnames[@]}" )
  printf "done.\n"
}

# @return:	true if locked, false otherwise
# @param:	manifest_file
status_manifest() {
  if [[ -e "$1".lock ]]; then
    return 0
  else
    return 1
  fi
}
# @return: true if successfully created lock file, else false
# @param:	manifest_file
lock_manifest() {
  if status_manifest "$1"; then
    return 0
  else
    if touch "$1".lock &>/dev/null; then
      return 0
    else
      return 1
    fi
  fi
}
# @return: true if successfully removed lock file, else false
# @param:	manifest_file
unlock_manifest() {
  if status_manifest "$1"; then
    if rm "$1".lock &>/dev/null; then
      return 0
    else
      return 1
    fi
  else
    return 0
  fi
}
# @return: true if unlock_manifest or lock_manifest, depending on status_manifest, return true, else false
# @param:	manifest_file
toggle_manifest() {
  if status_manifest "$1"; then
    unlock_manifest "$1" && return 0 || return 1
  else
    lock_manifest "$1" && return 0 || return 1
  fi
}

# expects manifest_entry_to_check to be an array with four entries
# @param:	manifest_file
# return:	0, if all is okay
#			1, file doesn't exist - removed entry from manifest
#			2, file doesn't exist - tried to remove entry from manifest, but failed
check_manifest_entry() {
  local entry_md5sum
  [[ ! -e "${manifest_entry_to_check[0]}" ]] && { rm_manifest_entry_by_filename "${manifest_entry_to_check[0]}" 1 && return 1 || return 2; }
  entry_md5sum="$(md5sum "${manifest_entry_to_check[0]}" | awk '{print $1}')"
  if [[ "${entry_md5sum}" != "${manifest_entry_to_check[1]}" ]]; then
	printf 'g/%s/s//%s/g\nw\nq' "${manifest_entry_to_check[1]}" "${entry_md5sum}" | ed -s "$1"
  else
	return 0
  fi
}

# parse manifest file and collect entries in manifest_array
# @param:	manifest_file
#
#	sort manifest file after first field (filename) -> read this line by line
#		check if line matches regexp || add to array manifest_entries_corrupted && continue
#		split lines at tab character \t and put into array line_arr
#		check manifest entry
#			-> file does not exist -> remove entry from manifest; continue no matter if this succeeds or not
#		loop through previous entries in the manifest
#			filename already in there? remove all entries with the same filename but the one that is already in the array
#			md5sum has already occured?
#				if size = 0
#					then don't compare
#				else
#					request user action by adding entry to array manifest_entries_user_action_required with information, that identical files exist && continue 2
#				fi
#		add entry to manifest_array
#
parse_manifest() {
  local i n re line line_arr check
  unset manifest_array; manifest_array=()
  local tmp_md5sum
  # array ( filename_1, md5sum_1, id_1[, rel_id_1] ), ... )
  # reserving 4 members for each entry, thus each filename entry in the array has array key 4(n-1)+1
  (( $CONFIG_debug )) && echo ">>>>>>> Parsing manifest file: $1"
  n=1
  [[ -s "$1" ]] &&
  while read line
  do
	# ANY CHANGES INSIDE HERE ON THE MANIFEST_FILE HAVE NO IMPACT ON THE LINES WE LOOP OVER; THE sort COMMAND READS THE FILE ENTIRELY AT THE BEGINNING AND PASSES THE OUTPUT TO THE LOOP
	# check if line has expected format, i.e. check against regular expression
    re=$'^[^\t]*\tmd5sum\t[^\t]*\tdiff_id\t[A-Za-z0-9]{8}\trel_id\t(0|[A-Za-z0-9]{8})\tdb\t[^\t]*$'
    [[ $line =~ $re ]] || { echo "Corrupted line: $line"; manifest_entries_corrupted=( "${manifest_entries_corrupted[@]}" "$1" "$line" ); continue; }
    IFS=$'\t' read -ra line_arr <<< "$line"

	# prepare array of the current line
    manifest_entry_to_check=()
    for ((i=0;i<${#line_arr[@]};i=$i+2)); do
      manifest_entry_to_check[i/2]="${line_arr[i]}"
    done
    # check manifest entry, which uses the array manifest_entry_to_check
	check_manifest_entry "$1"
	check=$?
	case $check in
	  1)  (( $CONFIG_debug )) && echo "File for manifest entry $line does not exist. Entry removed."
		  continue # file doesn't exist - removed entry from manifest
		  break;;
	  2)  (( $CONFIG_debug )) && echo "File for manifest entry $line does not exist. Failed to remove the entry."
		  continue # file doesn't exist - tried to remove entry from manifest, but failed
		  break;;
	esac

	# loop through the manifest_array, as it has been filled by now and check if an entry already exists with the same values
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i]}" = "x${line_arr[0]}" ]]; then	# found entry with the same filename
		(( $CONFIG_debug )) && echo "Found multiple entries with the same filename. Removing all but the first-found entry from manifest."
		# remove all entries with this filename and add a new one based on the values of the item already in the array
		rm_manifest_entry_by_filename "$1" "${manifest_array[i]}" 1 && add_manifest_entry "$1" "${manifest_array[i]}" "${manifest_array[i+3]}"
		continue 2	# the original entry, to which we compared, is already in the manifest_array; no matter if this is resolved or not, we don't 
					# need to add this entry to the manifest_array
	  elif [[ "x${manifest_array[i+1]}" = "x${line_arr[2]}" ]]; then	# found entry with different filename but same md5sum - file copied and renamed?!
		if [[ ! -s "${line_arr[0]}" ]]; then # empty file - don't start to compare md5sums ...
		  (( $CONFIG_debug )) && echo "Found empty file ${line_arr[0]}."
		else
		  (( $CONFIG_debug )) && echo "Found multiple entries with the same md5sum but different filename."
		  (( $CONFIG_debug )) && echo -e ">> fname_manifest:\t${manifest_array[i]}\t${manifest_array[i+1]}\n>> fname_line:\t\t${line_arr[0]}\t${line_arr[2]}"
		  if [[ "x${line_arr[6]}" != "x0" ]]; then
			if [[ "x${manifest_array[i+3]}" = "x${line_arr[6]}" ]]; then	# parent id is the same; TODO inform user of this predicament and suggest solution 
			  manifest_entries_user_action_required=( "${manifest_entries_user_action_required[@]}" "$1" "${manifest_array[i]}" "The file has an identical copy with the same parent id. If you don't know why it exists, it is safe to remove it." )
			  continue 2
			else
			  manifest_entries_user_action_required=( "${manifest_entries_user_action_required[@]}" "$1" "${manifest_array[i]}" "The file has an identical copy with different parent id. This should not happen. Remove the file, which is not the correct follow-up to the previous differential or master backup." )
			  continue 2
			fi
		  fi
		fi
	  fi
    done

	# add entry to manifest array
    for ((i=0;i<${#line_arr[@]};i=$i+2)); do
      manifest_array[(n-1)*${fields}+i/2]="${line_arr[i]}"
      #echo "manifest array key $((($n-1)*4+$i/2)) with value ${line_arr[i]}"
    done
    
    ((n++))
  done < <(sort -t $'\t' -k"1" "$1")
  (( $CONFIG_debug )) && echo "<<<<<<< # manifest entries: $((${#manifest_array[@]}/$fields))"
  (( $CONFIG_debug )) && echo "<<<<<<< FINISHED"
  return 0
}

# get_manifest_entry_by_* PATTERN [regexp]
# if second parameter 'regexp' (string!) is passed, PATTERN will be matched as regular expression
get_manifest_entry_by_filename() {
  local i
  if [[ "x$2" = "xregexp" ]]; then
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "${manifest_array[i]}" =~ $1 ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  else
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i]}" = "x$1" ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  fi
  return 1
}
get_manifest_entry_by_md5sum() {
  local i
  if [[ "x$2" = "xregexp" ]]; then
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "${manifest_array[i+1]}" =~ $1 ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  else
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i+1]}" = "x$1" ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
	  fi
    done
  fi
  return 1
}
get_manifest_entry_by_id() {
  local i
  if [[ "x$2" = "xregexp" ]]; then
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "${manifest_array[i+2]}" =~ $1 ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  else
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i+2]}" = "x$1" ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  fi
  return 1
}
get_manifest_entry_by_rel_id() {
  local i
  if [[ "x$2" = "xregexp" ]]; then
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "${manifest_array[i+3]}" =~ $1 ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  else
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i+3]}" = "x$1" ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  fi
  return 1
}
get_manifest_entry_by_db() {
  local i
  if [[ "x$2" = "xregexp" ]]; then
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "${manifest_array[i+4]}" =~ $1 ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  else
    for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
      if [[ "x${manifest_array[i+4]}" = "x$1" ]]; then
		manifest_entry=( "${manifest_array[i]}" "${manifest_array[i+1]}" "${manifest_array[i+2]}" "${manifest_array[i+3]}" "${manifest_array[i+4]}" )
		return 0
		break;
      fi
    done
  fi
  return 1
}

# @params:	db, master/diff (0,1)
# @return:	2: no entries in manifest for the specified database 'db'
#			1: could not get manifest element by filename
#			0: all fine, match is in array 'manifest_entry'
get_latest_manifest_entry_for_db() {
  local db_array newarray i
  for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
	if (( $2 )); then # latest differential or master backup, i.e. just take the latest one!
	  if [[ "x${manifest_array[i+4]}" = "x$1" ]]; then
		db_array=( "${db_array[@]}" "${manifest_array[i]}" )
	  fi
	else # latest master backup, pid=0
	  if [[ "x${manifest_array[i+4]}" = "x$1" && "x${manifest_array[i+3]}" = "x0" ]]; then
		db_array=( "${db_array[@]}" "${manifest_array[i]}")
	  fi
	fi
  done
  if (( "${#db_array[@]}" == 0 )); then return 2;
  else
	#newarray=(); while IFS= read -r -d '' line; do newarray+=("$line"); done < <(printf '%s\0' "${db_array[@]}" | sort -z)
	get_manifest_entry_by_filename "${db_array[@]:(-1)}" # last entry of db_array, has, due to the way sort works, to be the latest one
	return $?
  fi
}

# @params:	manifest_file	filename/md5sum/id/rel_id	[1(=don't parse manifest after finished)]
# if second parameters 
#
#	lock manifest -> use awk, print all lines that don't have second parameter at the appropriate field -> unlock manifest
#	param3=0 -> parse manifest
#
rm_manifest_entry_by_filename() {
  lock_manifest "$1" && awk -F"\t" -v v="$2" '$1 != v' "$1" > "$1".tmp && mv "$1".tmp "$1" && unlock_manifest "$1" || return 1
  (( "$3" )) || parse_manifest "$1"
  return 0
}
rm_manifest_entry_by_md5sum() {
  lock_manifest "$1" && awk -F"\t" -v v="$2" '$3 != v' "$1" > "$1".tmp && mv "$1".tmp "$1" && unlock_manifest "$1" || return 1
  (( "$3" )) || parse_manifest "$1"
  return 0
}
rm_manifest_entry_by_id() {
  lock_manifest "$1" && awk -F"\t" -v v="$2" '$5 != v' "$1" > "$1".tmp && mv "$1".tmp "$1" && unlock_manifest "$1" || return 1
  (( "$3" )) || parse_manifest "$1"
  return 0
}
rm_manifest_entry_by_rel_id() {
  lock_manifest "$1" && awk -F"\t" -v v="$2" '$7 != v' "$1" > "$1".tmp && mv "$1".tmp "$1" && unlock_manifest "$1" || return 1
  (( "$3" )) || parse_manifest "$1"
  return 0
}
rm_manifest_entry_by_db() {
  lock_manifest "$1" && awk -F"\t" -v v="$2" '$9 != v' "$1" > "$1".tmp && mv "$1".tmp "$1" && unlock_manifest "$1" || return 1
  (( "$3" )) || parse_manifest "$1"
  return 0
}

# parameters: manifest_file, filename, parent_id, db
add_manifest_entry() {
  local md5sum
  local id
  local filename
  local parent_id
  local db
  filename="$2"
  parent_id="$3"
  db="$4"
  lock_manifest "$1" || return 1
  id="${filename%.@(diff|sql)*}"
  id="${id:(-8):8}"
  #id="$(echo $filename | sed -re 's/.*_[0-9]{2}h[0-9]{2}m_([^\.]*)\..*/\1/')"
  md5sum="$(md5sum "$filename" | awk '{print $1}')"
  if [[ "x$parent_id" = 'x' ]]; then
    echo -e "${filename}\tmd5sum\t${md5sum}\tdiff_id\t${id}\trel_id\t0\tdb\t${db}" >> "$1"
  else
    echo -e "${filename}\tmd5sum\t${md5sum}\tdiff_id\t${id}\trel_id\t${parent_id}\tdb\t${db}" >> "$1"
  fi
  unlock_manifest "$1" || return 1
}

# @info:	Echos number of manifest entries.
num_manifest_entries() {
  echo "$((${#manifest_array[@]}/$fields))"
}

# @info:	Test if a value is in the array testarray
# @param:	value
# @var in_array_index:	array index of the first match
# @return	0 if a match was found, otherwise 1
in_array() {
  local j
  for ((j=0;j<"${#testarray[@]}";j++)); do
	if [[ "x${testarray[j]}" = "x$1" ]]; then
	  in_array_index=$j
	  return 0
	fi
  done
  return 1
}

# @param:	clear(0/1), meta_information, list_value1, list_value2, ...
extended_select() {
	local a c k m i r r_number meta_information choice selection do_clear
	meta_information="$2"
	do_clear="$1"
	shift 2
	declare -a list=("$@")
	selection=()
	# BEGIN _select_filenames
	#tput sc
	while true; do
		if (( $do_clear )); then
		  clear
		else
		  : #tput rc
		fi
		declare -a testarray=("${selection[@]}")
		echo "Selection for <$meta_information>"
		echo "Notation: 1,2-4,-5,-6-9 or * or -* ('-' will remove selections)."
		# print options

		for ((i=0;i<"${#list[@]}";i++)); do
		  if in_array $i; then
			echo -e "$i) [+]\t${list[i]}"
		  else
			echo -e "$i) [ ]\t${list[i]}"
		  fi
		done
		
		echo -e "$i)\tDONE"
		done_id=$i

		min=0
		max=${#list[@]} # we have to account for the last possible number of DONE
		# evaluate response
		while true; do
			printf '#? '
			read choice
			r='^((-?[0-9]+(-[0-9]+)?,)*-?[0-9]+(-[0-9]+)?|-?\*)$'
			[[ $choice =~ $r ]] || continue
			if [[ "x$choice" = 'x*' ]]; then
				unset m
				for ((m=0;m<"${#list[@]}";m++)); do
				  selection=("${selection[@]}" "$m")
				done
				continue 2
			elif [[ "x$choice" = 'x-*' ]]; then
				selection=()
				continue 2
			else
				unset string num1 num2 op op_rm
				r_number='^[0-9]$'

				# BEGIN process_choice
				for ((a=0;a<${#choice};a++))
				do
					c="${choice:a:1}"
					declare -a testarray=("${selection[@]}")

					if (( ${#string} == 0 )) && [[ "x$c" = "x-" ]] && ! (($op)); then
						op_rm=1
						continue
					elif [[ $c =~ $r ]]; then
						string=${string}"$c"
						if (( $a == (${#choice}-1) )); then # last character
							# we have a A-B case
							if (($op)); then
								num2="$string"
								unset k
								for ((k=$num1;k<=$num2;k++)); do
								  (( $k >= $min )) && (( $k <= $max )) || continue
								  if ! in_array $k; then
									selection=("${selection[@]}" $k)
								  else
									if (( $op_rm )); then
									  new_array=()
									  for ((m="$((${#selection[@]}-1))";m>=0;m--)); do
										if [[ "x${selection[m]}" != "x$k" ]]; then
										  new_array=("${new_array[@]}" "${selection[m]}")
										fi
									  done
									  declare -a selection=("${new_array[@]}")
									fi
								  fi
								done
								unset op op_rm num1 num2 string
								continue
							else
								(( $string >= $min )) && (( $string <= $max )) || continue
								if ! in_array "$string"; then
								  selection=("${selection[@]}" "$string")
								else
								  if (($op_rm)); then
									unset m
									new_array=()
									for ((m=0;m<"${#selection[@]}";m++)); do
									  if [[ "x${selection[m]}" != "x$string" ]]; then
										new_array=("${new_array[@]}" "${selection[m]}")
									  fi
									done
									declare -a selection=("${new_array[@]}")
								  fi
								fi
							fi
						else
						  continue
						fi
					elif [[ "x$c" = "x-" ]]; then
						num1="$string"
						unset string
						op=1
						if (( $a == (${#choice}-1) )); then
						  break
						else
						  continue
						fi
					elif [[ "x$c" = "x," ]]; then
						# we have a A-B case
						if (($op)); then
						  num2="$string"
						  unset k
						  for ((k=$num1;k<=$num2;k++)); do
							(( $k >= $min )) && (( $k <= $max )) || continue
							if ! in_array $k; then
							  selection=("${selection[@]}" $k)
							else
							  if (( $op_rm )); then
								unset m
								new_array=()
								for ((m=0;m<"${#selection[@]}";m++)); do
								  if [[ "x${selection[m]}" != "x$k" ]]; then
									new_array=("${new_array[@]}" "${selection[m]}")
								  fi
								done
								declare -a selection=("${new_array[@]}")
							  fi
							fi
						  done
						  unset op op_rm num1 num2 string
						  continue
						else # it's just a single number
							(( $string >= $min )) && (( $string <= $max )) || { unset op op_rm num1 num2 string; continue; }
							if ! in_array "$string"; then
							  selection=("${selection[@]}" "$string")
							else
							  if (($op_rm)); then
								unset m
								new_array=()
								for ((m=0;m<"${#selection[@]}";m++)); do
								  if [[ "x${selection[m]}" != "x$string" ]]; then
									new_array=("${new_array[@]}" "${selection[m]}")
								  fi
								done
								declare -a selection=("${new_array[@]}")
							  fi
							fi
							unset op op_rm num1 num2 string
							continue
						fi
					else
					  continue 2; # this should not happen
					fi
				done
				# END process_choice

				declare -a testarray=("${selection[@]}")
				if in_array "$done_id"; then
				  break 2
				else
				  continue 2
				fi
			fi
		done
	done
	extended_select_return=()
	extended_select_return_id=()
	for i in "${selection[@]}"; do
	  [[ "x$i" != "x$done_id" ]] && { extended_select_return=("${extended_select_return[@]}" "${list[i]}"); extended_select_return_id=("${extended_select_return_id[@]}" "$i"); }
	done
	
}

# END _functions


# BEGIN _methods

# @info:	Backup method
method_backup () {
	manifest_entries_corrupted=()
	manifest_entries_user_action_required=()


	# END __FUNCTIONS
	##############################################################################################################
	# BEGIN __STARTUP

	load_default_config

	trap mail_cleanup EXIT SIGHUP SIGINT SIGQUIT SIGTERM
	if [[ -r "${CONFIG_configfile}" ]]; then source "${CONFIG_configfile}"; echo "Parsed config file \"${CONFIG_configfile}\""; else let "N |= $N_config_file_missing"; fi; echo
	if (( $opt_flag_config_file )); then if [[ -r "${opt_config_file}" ]]; then source "${opt_config_file}"; let "N |= $N_arg_conffile_parsed"; else let "N |= $N_arg_conffile_unreadable"; fi; else let "N |= $N_too_many_args"; fi

	(( $CONFIG_dryrun )) && {
	  echo "NOTE: We are dry-running. That means, that the script just shows you what it would do, if it were operating normally."
	  echo "THE PRINTED COMMANDS CAN'T BE COPIED AND EXECUTED IF THERE ARE SPECIAL CHARACTERS, SPACES, ETC. IN THERE THAT WOULD NEED TO BE PROPERLY QUOTED IN ORDER TO WORK. THESE WERE CORRECTLY QUOTED FOR THE OUTPUT COMMAND, BUT CAN'T BE SEEN NOW."
	  echo
	}

	export LC_ALL=C
	PROGNAME=`basename $0`
	PATH=${PATH}:/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin 
	version=3.0
	fields=5 # manifest fields

	directory_checks_enable_logging
	cleanup_latest
	set_datetime_vars
	check_dependencies	# check for required programs
	parse_configuration	# parse configuration and set variables appropriately


	# END __STARTUP
	#--------------------------------------------------------------------------------------------------------------------------------------
	# BEGIN __PREPARE

	backupfiles=()
	parse_databases

	# debug output of variables
	(( $CONFIG_debug )) && { echo; echo "# DEBUG: printing all current variables"; declare -p | egrep -o '.* (CONFIG_[a-z_]*|opt|mysql_opt|opt_dbstatus|opt_fullschema)=.*'; echo; }
	(( $CONFIG_debug )) && { echo "DEBUG: before pre-backup"; ( IFS=,; echo "DEBUG: CONFIG_db_names '${CONFIG_db_names[*]}'" ); ( IFS=,; echo "DEBUG: CONFIG_db_month_names '${CONFIG_db_month_names[*]}'" );}


	# END __PREPARE
	#--------------------------------------------------------------------------------------------------------------------------------------
	# BEGIN __MAIN

	### filename formats
	##
	## example date values:
	# 14'th of August (08) 2011
	# week number: 32
	# Sunday (date_dayno_of_week: 7)
	##
	## separate db's:
	#	monthly_DBNAME_2011-08-14_18h12m_August.sql(.enc).{gz,bzip2}
	#	weekly_DBNAME_2011-08-14_18h12m_32.sql(.enc).{gz,bzip2}
	#	daily_DBNAME_2011-08-14_18h12m_7.sql(.enc).{gz,bzip2}
	## all-databases:
	#	monthly_all-databases_DBNAME_2011-08-14_18h12m_August.sql(.enc).{gz,bzip2}
	#	weekly_all-databases_DBNAME_2011-08-14_18h12m_32.sql(.enc).{gz,bzip2}
	#	daily_all-databases_DBNAME_2011-08-14_18h12m_7.sql(.enc).{gz,bzip2}

	echo "======================================================================"
	echo "AutoMySQLBackup version ${version}"
	echo "http://sourceforge.net/projects/automysqlbackup/"
	echo 
	echo "Backup of Database Server - ${CONFIG_mysql_dump_host_friendly:-$CONFIG_mysql_dump_host}"
	( IFS=,; echo "Databases - ${CONFIG_db_names[*]}" )
	( IFS=,; echo "Databases (monthly) - ${CONFIG_db_month_names[*]}" )
	echo "======================================================================"


	# -> preback commands
	if [[ "${CONFIG_prebackup}" ]]; then
		echo "======================================================================"
		echo "Prebackup command output."
		echo
		source ${CONFIG_prebackup}
		echo
		echo "======================================================================"
		echo
	fi
	# <- preback commands

	# -> backup local files
	if [[ "${CONFIG_backup_local_files[@]}" ]] && [[ ${CONFIG_do_weekly} != 0 && ${date_dayno_of_week} = ${CONFIG_do_weekly} ]] && (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/backup_local_files/bcf_weekly_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m_${date_weekno}.tar${suffix}"); ((! ${#f[@]}))); then
		echo "======================================================================"
		echo "Backup local files. Doing this weekly on CONFIG_do_weekly."
		echo
		backup_local_files "${CONFIG_backup_dir}/backup_local_files/bcf_weekly_${datetimestamp}_${date_weekno}.tar"
		tmp_flags=$?; var=; 
		if (( $? == 0 )); then
		  echo "success!"
		  backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/backup_local_files/bcf_weekly_${datetimestamp}_${date_weekno}.tar" )
		else
		  let "E |= $E_backup_local_failed"
		  echo "failed!"
		fi
		echo
		echo "======================================================================"
		echo
	fi
	# <- backup local files

	# -> dump full schema
	if [[ "${CONFIG_mysql_dump_full_schema}" = 'yes' ]]; then
		echo "======================================================================"
		echo "Dump full schema."
		echo

		# monthly
		if (( ${CONFIG_do_monthly} != 0 && (${date_day_of_month} == ${CONFIG_do_monthly} || $date_day_of_month == $date_lastday_of_this_month && $date_lastday_of_this_month < ${CONFIG_do_monthly}) )) && (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/fullschema/fullschema_monthly_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m_${date_month}.sql${suffix}"); ((! ${#f[@]}))); then
		  fullschema "${CONFIG_backup_dir}/fullschema/fullschema_monthly_${datetimestamp}_${date_month}.sql"
		  if (( $? == 0 )); then
			echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
			if (( $CONFIG_dryrun )); then
			  find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_monthly}" -type f -name 'fullschema_monthly*' -exec echo "dry-running: rm" {} \;
			else
			  find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_monthly}" -type f -name 'fullschema_monthly*' -exec rm {} \;
			fi
			files_postprocessing "${CONFIG_backup_dir}/fullschema/fullschema_monthly_${datetimestamp}_${date_month}.sql${suffix}"
			tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
			backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/fullschema/fullschema_monthly_${datetimestamp}_${date_month}.sql${suffix}${var}" )
		  else
			let "E |= $E_dump_fullschema_failed"
		  fi
		fi

		# weekly
		if [[ ${CONFIG_do_weekly} != 0 && ${date_dayno_of_week} = ${CONFIG_do_weekly} ]] && (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/fullschema/fullschema_weekly_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m_${date_weekno}.sql${suffix}"); ((! ${#f[@]}))); then
		  fullschema "${CONFIG_backup_dir}/fullschema/fullschema_weekly_${datetimestamp}_${date_weekno}.sql"
		  if (( $? == 0 )); then
			echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
			if (( $CONFIG_dryrun )); then
			  find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_weekly}" -type f -name 'fullschema_weekly*' -exec echo "dry-running: rm" {} \;
			else
			  find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_weekly}" -type f -name 'fullschema_weekly*' -exec rm {} \;
			fi
			files_postprocessing "${CONFIG_backup_dir}/fullschema/fullschema_weekly_${datetimestamp}_${date_weekno}.sql${suffix}"
			tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
			backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/fullschema/fullschema_weekly_${datetimestamp}_${date_weekno}.sql${suffix}${var}" )
		  else
			let "E |= $E_dump_fullschema_failed"
		  fi
		fi

		# daily
		fullschema "${CONFIG_backup_dir}/fullschema/fullschema_daily_${datetimestamp}_${date_day_of_week}.sql"
		if (( $? == 0 )); then
		  echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
		  if (( $CONFIG_dryrun )); then
			find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_daily}" -type f -name 'fullschema_daily*' -exec echo "dry-running: rm" {} \;
		  else
			find "${CONFIG_backup_dir}/fullschema" -mtime +"${CONFIG_rotation_daily}" -type f -name 'fullschema_daily*' -exec rm {} \;
		  fi
		  files_postprocessing "${CONFIG_backup_dir}/fullschema/fullschema_daily_${datetimestamp}_${date_day_of_week}.sql${suffix}"
		  tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
		  backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/fullschema/fullschema_daily_${datetimestamp}_${date_day_of_week}.sql${suffix}${var}" )
		else
		  let "E |= $E_dump_fullschema_failed"
		fi
		echo
		echo "======================================================================"
		echo
	  
	fi
	# <- dump full schema

	# -> dump status
	if [[ "${CONFIG_mysql_dump_dbstatus}" = 'yes' ]]; then
		echo "======================================================================"
		echo "Dump status."
		echo

		# monthly
		if (( ${CONFIG_do_monthly} != 0 && (${date_day_of_month} == ${CONFIG_do_monthly} || $date_day_of_month == $date_lastday_of_this_month && $date_lastday_of_this_month < ${CONFIG_do_monthly}) )) && (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/status/status_monthly_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m_${date_month}.txt${suffix}"); ((! ${#f[@]}))); then
		  dbstatus "${CONFIG_backup_dir}/status/status_monthly_${datetimestamp}_${date_month}.txt"
		  if (( $? == 0 )); then
			echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
			if (( $CONFIG_dryrun )); then
			  find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_monthly}" -type f -name 'status_monthly*' -exec echo "dry-running: rm" {} \;
			else
			  find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_monthly}" -type f -name 'status_monthly*' -exec rm {} \;
			fi
			files_postprocessing "${CONFIG_backup_dir}/status/status_monthly_${datetimestamp}_${date_month}.txt${suffix}"
			tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
			backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/status/status_monthly_${datetimestamp}_${date_month}.txt${suffix}${var}" )
		  else
			let "E |= $E_dump_status_failed"
		  fi
		fi

		# weekly
		if [[ ${CONFIG_do_weekly} != 0 && ${date_dayno_of_week} = ${CONFIG_do_weekly} ]] && (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/status/status_weekly_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m_${date_weekno}.txt${suffix}"); ((! ${#f[@]}))); then
		  dbstatus "${CONFIG_backup_dir}/status/status_weekly_${datetimestamp}_${date_weekno}.txt"
		  if (( $? == 0 )); then
			echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
			if (( $CONFIG_dryrun )); then
			  find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_weekly}" -type f -name 'status_weekly*' -exec echo "dry-running: rm" {} \;
			else
			  find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_weekly}" -type f -name 'status_weekly*' -exec rm {} \;
			fi
			files_postprocessing "${CONFIG_backup_dir}/status/status_weekly_${datetimestamp}_${date_weekno}.txt${suffix}"
			tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
			backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/status/status_weekly_${datetimestamp}_${date_weekno}.txt${suffix}${var}" )
		  else
			let "E |= $E_dump_status_failed"
		  fi
		fi

		# daily
		dbstatus "${CONFIG_backup_dir}/status/status_daily_${datetimestamp}_${date_day_of_week}.txt"
		if (( $? == 0 )); then
		  echo "Rotating $(( ${CONFIG_rotation_monthly}/31 )) month backups for ${mdb}"
		  if (( $CONFIG_dryrun )); then
			find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_daily}" -type f -name 'status_daily*' -exec echo "dry-running: rm" {} \;
		  else
			find "${CONFIG_backup_dir}/status" -mtime +"${CONFIG_rotation_daily}" -type f -name 'status_daily*' -exec rm {} \;
		  fi
		  files_postprocessing "${CONFIG_backup_dir}/status/status_daily_${datetimestamp}_${date_day_of_week}.txt${suffix}"
		  tmp_flags=$?; var=; (( $tmp_flags & $flags_files_postprocessing_success_encrypt )) && var=.enc
		  backupfiles=( "${backupfiles[@]}" "${CONFIG_backup_dir}/status/status_daily_${datetimestamp}_${date_day_of_week}.txt${suffix}${var}" )
		else
		  let "E |= $E_dump_status_failed"
		fi
		echo
		echo "======================================================================"
		echo
	  
	fi
	# <- dump status


	# -> BACKUP DATABASES
	  echo "Backup Start Time `date`"
	  echo "======================================================================"

	  ## <- monthly backup, unique per month
	  if (( ${CONFIG_do_monthly} != 0 && (${date_day_of_month} == ${CONFIG_do_monthly} || $date_day_of_month == $date_lastday_of_this_month && $date_lastday_of_this_month < ${CONFIG_do_monthly}) )); then
		  echo "Monthly Backup ..."
		  echo

		  subfolder="monthly"
		  prefix="monthly_"
		  midfix="_${date_month}"
		  extension=".sql"
		  rotation="${CONFIG_rotation_monthly}"
		  rotation_divisor="31"
		  rotation_string="month"

		  if [[ "${CONFIG_mysql_dump_use_separate_dirs}" = "yes" ]]; then
			for db in "${CONFIG_db_month_names[@]}"; do
			  echo "Monthly Backup of Database ( ${db} )"
			  (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/${subfolder}/${db}/${prefix}${db}_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m${midfix}${extension}${suffix}"); ((${#f[@]}))) && continue
			  process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 0 "$db"
			  echo ----------------------------------------------------------------------
			done
		  else
			  echo "Monthly backup of databases ( ${CONFIG_db_month_names[@]} )."
			  (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/${subfolder}/${prefix}all-databases_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m${midfix}${extension}${suffix}"); ((${#f[@]}))) &&
				process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 1 "${CONFIG_db_month_names[@]}"
			  echo "----------------------------------------------------------------------"
		  fi
	  fi
	  ## <- monthly backup

	  ## <- weekly backup, unique per week
	  if (( ${CONFIG_do_weekly} != 0 && ${date_dayno_of_week} == ${CONFIG_do_weekly} )); then
		  echo "Weekly Backup ..."
		  echo

		  subfolder="weekly"
		  prefix="weekly_"
		  midfix="_${date_weekno}"
		  extension=".sql"
		  rotation="${CONFIG_rotation_weekly}"
		  rotation_divisor="7"
		  rotation_string="week"
		  if [[ "${CONFIG_mysql_dump_use_separate_dirs}" = "yes" ]]; then
			for db in "${CONFIG_db_names[@]}"; do
			  echo "Weekly Backup of Database ( ${db} )"
			  (shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/${subfolder}/${db}/${prefix}${db}_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m${midfix}${extension}${suffix}"); ((${#f[@]}))) && continue
			  process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 0 "$db"
			  echo "----------------------------------------------------------------------"
			done
		  else
			echo "Weekly backup of databases ( ${CONFIG_db_names[@]} )."
			(shopt -s nullglob dotglob; f=("${CONFIG_backup_dir}/${subfolder}/${prefix}all-databases_${date_stamp}_"[0-9][0-9]"h"[0-9][0-9]"m${midfix}${extension}${suffix}"); ((${#f[@]}))) &&
			  process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 1 "${CONFIG_db_names[@]}"
			echo "----------------------------------------------------------------------"
		  fi
	  fi
	  ## <- weekly backup

	  ## -> daily backup, test (( 1 )) is always true, just creates a grouping for Kate, which can be closed ^^
	  if (( 1 )); then
		  echo "Daily Backup ..."
		  echo

		  subfolder="daily"
		  prefix="daily_"
		  midfix="_${date_day_of_week}"
		  extension=".sql"
		  rotation="${CONFIG_rotation_daily}"
		  rotation_divisor="1"
		  rotation_string="day"

		  if [[ "${CONFIG_mysql_dump_use_separate_dirs}" = "yes" ]]; then
			for db in "${CONFIG_db_names[@]}"; do
			  echo "Daily Backup of Database ( ${db} )"
			  process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 0 "$db"
			  echo "----------------------------------------------------------------------"
			done
		  else
			echo "Daily backup of databases ( ${CONFIG_db_names[@]} )."
			process_dbs "$subfolder" "$prefix" "$midfix" "$extension" "$rotation" "$rotation_divisor" "$rotation_string" 1 "${CONFIG_db_names[@]}"
			echo "----------------------------------------------------------------------"
		  fi
	  fi
	  ## <- daily backup

	  echo
	  echo "Backup End Time `date`"
	  echo "======================================================================"
	# <- BACKUP DATABASES


	# -> clean latest filenames
	[[ "${CONFIG_mysql_dump_latest_clean_filenames}" = 'yes' ]] && find "${CONFIG_backup_dir}"/latest/ -type f -exec bash -c 'remove_datetimeinfo "$@"' -- {} \;
	# <- clean latest filenames

	# -> finished information
	echo "Total disk space used for backup storage..."
	echo "Size - Location"
	echo `du -hsH "${CONFIG_backup_dir}"`
	echo
	echo "======================================================================"
	# <- finished information

	# -> postbackup commands
	if [[ "${CONFIG_postbackup}" ]];then
		echo "======================================================================"
		echo "Postbackup command output."
		echo
		source ${CONFIG_postbackup}
		echo
		echo "======================================================================"
	fi
	# <- postbackup commands

	if [[ -s "$log_errfile" ]];then status=1; else status=0; fi

	exit ${status}

}

# @return	variable method_list_manifest_entries_array
method_list_manifest_entries () {
	local files files_master files_manifest file db manifest_files manifest_files_db selected_dbs i z l master_flags master to_rm actions
	manifest_entries_corrupted=()
	manifest_entries_user_action_required=()
	files=()
	files_master=()
	files_manifest=()
	master_flags=0
	let "filename_flag_encrypted=0x01"
	let "filename_flag_gz=0x02"
	let "filename_flag_bz2=0x04"
	let "filename_flag_diff=0x08"

	##############################################################################################################
	# BEGIN __STARTUP

	load_default_config

	if [[ -r "${CONFIG_configfile}" ]]; then source "${CONFIG_configfile}"; echo "Parsed config file \"${CONFIG_configfile}\""; else let "N |= $N_config_file_missing"; fi; echo
	if (( $opt_flag_config_file )); then if [[ -r "${opt_config_file}" ]]; then source "${opt_config_file}"; let "N |= $N_arg_conffile_parsed"; else let "N |= $N_arg_conffile_unreadable"; fi; else let "N |= $N_too_many_args"; fi

	export LC_ALL=C
	PROGNAME=`basename $0`
	PATH=${PATH}:/usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin 
	version=3.0
	fields=5 # manifest fields

	set_datetime_vars
	check_dependencies	# check for required programs
	parse_configuration	# parse configuration and set variables appropriately

	# BEGIN __MAIN
	unset manifest_files manifest_files_db i db
	while IFS= read -r -d '' file; do
	  db="${file#/var/backup/db/@(daily|monthly|weekly|latest)/}";
	  db="${db%/Manifest}";
	  manifest_files_db[i]="$db"
	  manifest_files[i++]="$file"
	done < <(find "${CONFIG_backup_dir}"/ -type f -name 'Manifest' -print0)

	extended_select 0 "Databases" "${manifest_files_db[@]}"
	declare -a selected_dbs=("${extended_select_return[@]}")

	for db in "${selected_dbs[@]}"; do
		selected_available_files=()
		for ((i=0;i<"${#manifest_files_db[@]}";i++)); do
		  if [[ "x${manifest_files_db[i]}" = "x$db" ]]; then
			selected_available_files[j++]="${manifest_files[i]}"
		  fi
		done
		if (( "${#selected_available_files[@]}" > 0 )); then
			extended_select 1 "$db" "${selected_available_files[@]}"
			declare -a selected_entries=("${extended_select_return[@]}")
			if (( "${#selected_entries[@]}" > 0 )); then
				for z in "${selected_entries[@]}"; do
				  parse_manifest "$z"
				  list=()
				  list_id=()
				  for ((i=0;$i<"${#manifest_array[@]}";i=$i+$fields)); do
					if [[ "${manifest_array[i+3]}" != 0 ]]; then # only add differential backups
					  list=("${list[@]}" "${manifest_array[i]}")
					  list_id=("${list_id[@]}" "${manifest_array[i+3]}") # save rel_id, so we can retrieve the master backup file
					fi
				  done
				  if (( "${#list[@]}" > 0 )); then
					extended_select 1 "$z" "${list[@]}"
					if (( "${#extended_select_return[@]}" > 0 )); then
					  for ((i=0;$i<"${#extended_select_return[@]}";i++)); do
						if get_manifest_entry_by_id "${list_id[${extended_select_return_id[i]}]}"; then
						  files=("${files[@]}" "${extended_select_return[i]}")
						  files_master=("${files_master[@]}" "${manifest_entry[0]}")
						  files_manifest=("${files_manifest[@]}" "$z")
						else
						  echo "no found master for id ${list_id[${extended_select_return_id[i]}]}"
						fi
					  done
					fi
				  fi
				done
			fi
		fi
	done
	# END _select_filenames
	declare -a method_list_manifest_entries_array=("${files[@]}")
	declare -a method_list_manifest_entries_array_master=("${files_master[@]}")
	declare -a method_list_manifest_entries_array_manifest=("${files_manifest[@]}")

	clear
	echo "You have selected the following files:"
	for i in "${files[@]}"; do printf '>>> %s\n' "$i"; done
	echo
	actions=('diff to full' 'remove files (also from Manifest)')
	extended_select 0 "Actions" "${actions[@]}"
	for action in "${extended_select_return[@]}"; do
		case "$action" in
			'diff to full')
				for ((l=0;$l<"${#files[@]}";l++)); do
				  # put the unpacking of the master file in here, so that in the case of multiple diffs with the same
				  # master file don't cause the script to unpack the same master file multiple times
				  master="${files_master[l]}"
				  diff="${files[l]}"
				  FileStub="${master%.@(sql|master)*}"
				  FileExt="${master#"$FileStub"}"
				  re=".*\.enc.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_encrypted"
				  re=".*\.gz.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_gz"
				  re=".*\.bz2.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_bz2"
				  re=".*\.diff.*";	[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_diff"
				  if (( $master_flags & $filename_flag_gz )); then
					declare -a testarray=("${to_rm[@]}")
					if ! in_array "${master%.gz}"; then
					  gzip_compression -dc "$master" > "${master%.gz}"
					  to_rm=("${to_rm[@]}" "${master%.gz}")
					fi
					master="${master%.gz}"
				  elif (( $master_flags & $filename_flag_bz2 )); then
					declare -a testarray=("${to_rm[@]}")
					if ! in_array "${master%.bz2}"; then
					  bzip2_compression -dc "$master" > "${master%.bz2}"
					  to_rm=("${to_rm[@]}" "${master%.bz2}")
					fi
					master="${master%.bz2}"
				  else
					:
				  fi
				  method_diff_to_full "$master" "$diff"
				  #printf '%s\n>>> master: %s\n>>> manifest: %s\n' "${files[l]}" "${files_master[l]}" "${files_manifest[l]}"
				done
				# cleanup all unpacked master files ... the unpacked diff files are cleaned up by method_diff_to_full
				for i in "${to_rm[@]}"; do rm "$i"; done
			;;
			'remove files (also from Manifest)')
				for ((l=0;$l<"${#files[@]}";l++)); do
				  if rm_manifest_entry_by_filename "${files_manifest[l]}" "${files[l]}" 1; then
					rm "${files[l]}"
				  fi
				done
			;;
			*)
			  echo "Unrecognized option. This Should not happen! Error!"
			;;
		esac
	done

	# END __MAIN
}

# @info:	Convert a differential backup file to a full one.
# @param:	master_backup_file diff_backup_file
method_diff_to_full() {
	local diff full diff_flags master_flags to_rm
	master="$1"
	diff="$2"
	diff_flags=0
	master_flags=0
	to_rm=()

	FileStub="${diff%.@(sql|diff)*}"
	FileExt="${diff#"$FileStub"}"
	re=".*\.enc.*";		[[ "$FileExt" =~ $re ]] && let "diff_flags|=$filename_flag_encrypted"
	re=".*\.gz.*";		[[ "$FileExt" =~ $re ]] && let "diff_flags|=$filename_flag_gz"
	re=".*\.bz2.*";		[[ "$FileExt" =~ $re ]] && let "diff_flags|=$filename_flag_bz2"
	re=".*\.diff.*";	[[ "$FileExt" =~ $re ]] && let "diff_flags|=$filename_flag_diff"
	FileStub="${master%.@(sql|master)*}"
	FileExt="${master#"$FileStub"}"
	re=".*\.enc.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_encrypted"
	re=".*\.gz.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_gz"
	re=".*\.bz2.*";		[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_bz2"
	re=".*\.diff.*";	[[ "$FileExt" =~ $re ]] && let "master_flags|=$filename_flag_diff"

	# TODO: Differential backup with encryption is not yet implemented!
	if (( $diff_flags & $filename_flag_encrypted )); then
	  : #decrypt it
	fi

	if (( $master_flags & $filename_flag_encrypted )); then
	  : #decrypt it
	fi

	if (( $diff_flags & $filename_flag_gz )); then
	  gzip_compression -dc "$diff" > "${diff%.gz}"
	  to_rm=("${to_rm[@]}" "${diff%.gz}")
	  diff="${diff%.gz}"
	elif (( $diff_flags & $filename_flag_bz2 )); then
	  bzip2_compression -dc "$diff" > "${diff%.bz2}"
	  to_rm=("${to_rm[@]}" "${diff%.bz2}")
	  diff="${diff%.bz2}"
	else
	  :
	fi

	if (( $master_flags & $filename_flag_gz )); then
	  gzip_compression -dc "$master" > "${master%.gz}"
	  to_rm=("${to_rm[@]}" "${master%.gz}")
	  master="${master%.gz}"
	elif (( $master_flags & $filename_flag_bz2 )); then
	  bzip2_compression -dc "$master" > "${master%.bz2}"
	  to_rm=("${to_rm[@]}" "${master%.bz2}")
	  master="${master%.bz2}"
	else
	  :
	fi

	patch "$master" "$diff" -o "${diff/diff/sql}"

	# cleanup
	for i in "${to_rm[@]}"; do rm "$i"; done
}

# END _methods


# BEGIN __main

NO_ARGS=0
E_OPTERROR=85

if (( $# == $NO_ARGS )); then   # Script invoked with no command-line args?
  echo "Invoking backup method."; echo; method_backup
fi

while getopts ":c:blh" Option
do
  case $Option in
	c     ) echo "Using \"$OPTARG\" as optional config file."; echo; opt_config_file="$OPTARG"; opt_flag_config_file=1;;
	b     ) echo "MySQL backup method invoked."; echo;  opt_flag_method_backup=1;;
	l	  ) echo "List manifest entries."; echo; opt_flag_list_manifest_entries=1;;
	h	  )	echo "Usage `basename $0` options -cblh"
			echo -e "-c CONFIG_FILE\tSpecify optional config file."
			echo -e "-b\tUse backup method."
			echo -e "-l\tList manifest entries."
			echo -e "-h\tShow this help."
			exit 0;;
	#n | o ) echo "Scenario #2: option -$Option-   [OPTIND=${OPTIND}]";;

	#q     ) echo "Scenario #4: option -q-\
	#				with argument \"$OPTARG\"   [OPTIND=${OPTIND}]";;
	#  Note that option 'q' must have an associated argument,
	#+ otherwise it falls through to the default.
	#r | s ) echo "Scenario #5: option -$Option-";;
	*     ) echo "Unimplemented option chosen.";;   # Default.
  esac
done

(( $opt_flag_method_backup )) && method_backup
(( $opt_flag_list_manifest_entries )) && method_list_manifest_entries

shift $(($OPTIND - 1))
#  Decrements the argument pointer so it points to next argument.
#  $1 now references the first non-option item supplied on the command-line
#+ if one exists.

# For backward compatibility. If no option items are present and only one non-option item is there, we expect it
# to be the optional config file and invoke the backup method.
opt_flags=( "${!opt_flag_@}" )	# array of all set variables starting with opt_flag_
if (( $# == 1 )) && (( ${#opt_flags[@]} == 0 )); then
  opt_config_file="$1"; opt_flag_config_file=1; method_backup
elif (( $# == 0 )) && (( ${#opt_flags[@]} == 0 )); then
  method_backup
fi

# END __main