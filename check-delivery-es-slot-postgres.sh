#!/bin/bash

TELEGRAM_BOT_TOKEN="<TOKEN>"
last_result_file=/opt/monitoring/result_last_check_lsn.txt
log_file=/opt/monitoring/log_file.txt


sent_alert_1 () {
        echo "$(date), alert sent ... " >> $log_file
        curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "<ID>", "text": "SANDBOX Delivery_es_slot has no rows when checking lsn ... !!!"}' https://api.telegram.org/bot<TOKEN>/sendMessage
}

sent_alert_2 () {
        echo "$(date), alert sent ... " >> $log_file
        curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "<ID>", "text": " SANDBOX Delivery_es_slot | LSN_SENT and LSN_WRITE not match ..., please check !!!"}' https://api.telegram.org/bot<TOKEN>/sendMessage
}

auto_create_file () {
        for i in $log_file,$last_result_file
        do
            if [ -f "$i" ]; then
                echo " File is exist, nothing to do ..." >> /dev/null
                find /opt/monitoring -name result_last_check_lsn.txt  -type f -size +10000k -exec cat /dev/null > $last_result_file {} \;
                find /opt/monitoring -name scrip_check_lsn.sh  -type f -size +10000k -exec cat /dev/null > $last_result_file {} \;
            else
                touch $i
            fi
        done    
}
check_sent_lsn () {
        # Write last LSN to file
        echo "$(date), checking LNS ... " >> ${last_result_file}
        PGPASSWORD=<PASS> psql -Upostgres -h127.0.0.1 -p7432 -c "select pg_stat_replication.sent_lsn,write_lsn from pg_stat_replication inner join pg_replication_slots on pg_stat_replication.pid = pg_replication_slots.active_pid where pg_replication_slots.slot_name = 'sync_es_slot'" >> ${last_result_file}

        # Get sent_lsn and write_lsn
        count_rows=$(PGPASSWORD=<PASS> psql -Upostgres -h127.0.0.1 -p7432 -c "select pg_stat_replication.sent_lsn,write_lsn from pg_stat_replication inner join pg_replication_slots on pg_stat_replication.pid = pg_replication_slots.active_pid where pg_replication_slots.slot_name = 'sync_es_slot'" | awk 'NR == 3' |grep -v row |wc -l)
        sent_lsn=$(PGPASSWORD=<PASS> psql -Upostgres -h127.0.0.1 -p7432 -c "select pg_stat_replication.sent_lsn,write_lsn from pg_stat_replication inner join pg_replication_slots on pg_stat_replication.pid = pg_replication_slots.active_pid where pg_replication_slots.slot_name = 'sync_es_slot'" | awk 'NR == 3 { print $1}')
        write_lsn=$(PGPASSWORD=<PASS> psql -Upostgres -h127.0.0.1 -p7432 -c "select pg_stat_replication.sent_lsn,write_lsn from pg_stat_replication inner join pg_replication_slots on pg_stat_replication.pid = pg_replication_slots.active_pid where pg_replication_slots.slot_name = 'sync_es_slot'" | awk 'NR == 3 { print $3}')
}

compare_lsn () {
        check_sent_lsn
        if [ $count_rows -eq 0 ]; then
              echo " $(date) , Has no rows exist, let's check sync_connector !!!"  >> ${log_file}  
              sent_alert_1
        else
                if [ "$sent_lsn" = "$write_lsn" ]; then
                        echo " $(date) , sent_lsn  and write_lsn is matching  ..."  >> ${log_file}
                else
                        echo " $(date) ,  LSN not matching - It will be check again after 30s !!! " >> ${log_file}
                        sleep 30;
                        check_sent_lsn
                        if [ "$sent_lsn" = "$write_lsn" ]; then
                                echo " $(date) , sent_lsn  and write_lsn is matching  ..."  >> ${log_file}
                        else
                                echo " $(date) ,  LSN not matching - Alert sending to telegram !!! " >> ${log_file}
                                sent_alert_2
                        fi
                fi
        fi
}
auto_create_file && compare_lsn
