#!/bin/bash

#get correct path to this script
thisScriptPath=`realpath $0`
thisDirPath=`dirname $thisScriptPath`
# get the database name from the sync_mysql.cnf
database=$(sed -nr "/^\[client\]/ { :l /^database[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" $thisDirPath/sync_mysql.cnf)

# truncate the portal_sync table
mysql --defaults-extra-file=$thisDirPath/sync_mysql.cnf -e "truncate table portal_sync"
# import the portal_sync table
cat $thisDirPath/portal_sync.sql | mysql --defaults-extra-file=$thisDirPath/sync_mysql.cnf
# move the portal_sync dump file to the DUMPS_HISTORY folder
mv $thisDirPath/portal_sync.sql $thisDirPath/DUMPS_HISTORY/$(date +%Y-%m-%d_%H:%M:%S)_portal_sync.sql
tables_for_sync_str=$(mysql --defaults-extra-file=$thisDirPath/sync_mysql.cnf \
                      -e "SELECT table_for_sync FROM portal_sync WHERE enable = 1")
# delete new line symbols
tables_for_sync_str=$(sed 's/\\n//g' <<< $tables_for_sync_str)
tables_for_sync_list=(${tables_for_sync_str// / })
# import each table from the tables_for_sync_list
for ((i = 1; i < ${#tables_for_sync_list[@]}; i++)); do
    # backup the table state to the BACKUP_HISTORY folder
    mysqldump --defaults-extra-file=$thisDirPath/sync_mysqldump.cnf --no-create-info --single-transaction \
              $database ${tables_for_sync_list[$i]} > \
              $thisDirPath/BACKUP_HISTORY/$(date +%Y-%m-%d_%H:%M:%S)_${tables_for_sync_list[$i]}.sql
    # read mysql dump in table_dump variable, the table should be already copied in the folder with script 
    table_dump=$(<$thisDirPath/${tables_for_sync_list[$i]}.sql)
    # if $table_dump is empty - go to the next iteration    
    if [ -z "$table_dump" ]; then
        continue
    fi
    # prepare querry: turn off autocommit -> delete all info from the table -> insert new data in the table -> commit
    sql_querry="SET autocommit=0; DELETE FROM ${tables_for_sync_list[$i]}; $table_dump COMMIT;"
    echo "$sql_querry"
    # apply changes
    mysql --defaults-extra-file=$thisDirPath/sync_mysql.cnf -e "$sql_querry"
    # move the dump file to the DUMPS_HISTORY folder
    mv $thisDirPath/${tables_for_sync_list[$i]}.sql \
       $thisDirPath/DUMPS_HISTORY/$(date +%Y-%m-%d_%H:%M:%S)_${tables_for_sync_list[$i]}.sql
done

