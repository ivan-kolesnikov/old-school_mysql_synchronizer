#!/bin/bash

#get correct path to this script
thisScriptPath=`realpath $0`
thisDirPath=`dirname $thisScriptPath`

# get the [DATA BASE] credentials from the .INI file
user=$(sed -nr "/^\[DATA BASE\]/ { :l /^user[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
       $thisDirPath/sync_mysqldump_mysql.cnf)
host=$(sed -nr "/^\[DATA BASE\]/ { :l /^host[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
       $thisDirPath/sync_mysqldump_mysql.cnf)
password=$(sed -nr "/^\[DATA BASE\]/ { :l /^password[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
           $thisDirPath/sync_mysqldump_mysql.cnf)
database=$(sed -nr "/^\[DATA BASE\]/ { :l /^database[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
           $thisDirPath/sync_mysqldump_mysql.cnf)
# get the [REMOTE SERVER] credentials from the .INI file
user_rs=$(sed -nr "/^\[REMOTE SERVER\]/ { :l /^user_rs[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
          $thisDirPath/sync_mysqldump_mysql.cnf)
host_rs=$(sed -nr "/^\[REMOTE SERVER\]/ { :l /^host_rs[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
          $thisDirPath/sync_mysqldump_mysql.cnf)
password_rs=$(sed -nr "/^\[REMOTE SERVER\]/ { :l /^password_rs[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
              $thisDirPath/sync_mysqldump_mysql.cnf)
dir_rs=$(sed -nr "/^\[REMOTE SERVER\]/ { :l /^dir_rs[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" \
         $thisDirPath/sync_mysqldump_mysql.cnf)

# get the portal_sync table with tables for transfer
mysqldump --user=$user --password=$password --no-create-info --single-transaction --compact \
          $database portal_sync > $thisDirPath/portal_sync.sql
# transfer the portal_sync dump file to the remote server
sshpass -p $password_rs scp $thisDirPath/portal_sync.sql $user_rs@$host_rs:$dir_rs
# move the portal_sync dump file to the DUMPS_HISTORY folder
mv $thisDirPath/portal_sync.sql $thisDirPath/DUMPS_HISTORY/$(date +%Y-%m-%d_%H:%M:%S)_portal_sync.sql

# get the table names from the portal_sync table
tables_for_sync_str=$(echo "SELECT table_for_sync FROM portal_sync WHERE enable = 1" | \
                      mysql -h$host -u$user -p$password $database)
# delete new line symbols
tables_for_sync_str=$(sed 's/\\n//g' <<< $tables_for_sync_str)
tables_for_sync_list=(${tables_for_sync_str// / })
#dump each table from the tables_for_sync_list
for ((i = 1; i < ${#tables_for_sync_list[@]}; i++)); do
    # make the table dump
    mysqldump --user=$user --password=$password --no-create-info --single-transaction --compact \
              $database ${tables_for_sync_list[$i]} > $thisDirPath/${tables_for_sync_list[$i]}.sql
    # transfer the dump file to the remote server
    sshpass -p $password_rs scp $thisDirPath/${tables_for_sync_list[$i]}.sql $user_rs@$host_rs:$dir_rs
    # move the dump file to the DUMPS_HISTORY folder
    mv $thisDirPath/${tables_for_sync_list[$i]}.sql \
       $thisDirPath/DUMPS_HISTORY/$(date +%Y-%m-%d_%H:%M:%S)_${tables_for_sync_list[$i]}.sql
done
