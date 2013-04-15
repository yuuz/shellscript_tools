#!/bin/bash

if [ $# -lt 2 ]; then
	echo "input database hostname and user."
	exit -1
fi


TMP_FILE=/tmp/eventsdump.tmp
DELIMITER="tab____tab"

TARGET_DB_HOST=$1
DB_USER=$2

mysql -u ${DB_USER} -p -h ${TARGET_DB_HOST} -N --execute="
select 
    EVENT_SCHEMA,
    INTERVAL_VALUE,
    EXECUTE_AT,
    INTERVAL_FIELD,
    STATUS,
    EVENT_NAME,
    EVENT_TYPE,
    replace(EVENT_DEFINITION, '\n', ' ' ) 
from information_schema.EVENTS
" | sed -e "s/\t/${DELIMITER}/g" >$TMP_FILE

while read line; 
do
	TARGET_DATABASE=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f1`
	INTERVAL_VALUE=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f2`
	EXECUTE_AT=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f3`
	INTERVAL_FIELD=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f4`
	STATUS=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f5`
	EVENT_NAME=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f6`
	EVENT_TYPE=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f7`
	EVENT_DEFINITION=`echo $line | sed -e "s/${DELIMITER}/\t/g" |cut -f8`
	STATUS_SQL="";
	if [ "ENABLED" == ${STATUS} ];then
		STATUS_SQL="ENABLE"
	fi
	if [ "DISABLED" == ${STATUS} ];then
		STATUS_SQL="DISABLE"
	fi
	if [ "SLAVESIDE_DISABLED" == ${STATUS} ];then
		STATUS_SQL="DISABLE ON SLAVE"
	fi

	if [ "RECURRING" == "${EVENT_TYPE}" ];then
		echo "--- execute at ${TARGET_DATABASE} ---";
		echo "DELIMITER |
CREATE EVENT IF NOT EXISTS ${EVENT_NAME} ON SCHEDULE EVERY ${INTERVAL_VALUE} ${INTERVAL_FIELD} STARTS CURRENT_TIMESTAMP ${STATUS_SQL} DO ${EVENT_DEFINITION} 
| ";
	else
		echo "--- execute at ${TARGET_DATABASE} ---";
		echo "DELIMITER |
CREATE EVENT IF NOT EXISTS ${EVENT_NAME} ON SCHEDULE AT ${EXECUTE_AT} ${STATUS_SQL} DO BEGIN ${EVENT_DEFINITION}; 
|";
	fi


done < $TMP_FILE

