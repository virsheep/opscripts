#!/bin/bash

timestamp=$(date +%s)
endpoint=$HOSTNAME
step=30
dirname=$(cd $(dirname $0);pwd|awk -F\/ '$0=$NF')
bin_path="/home/service/falcon-agent/nagios/libexec"
base_path=$(cd $(dirname $0);pwd)
config_path=/data/mysql_trade/
user="falcon_mon"
pass="f4e0N39HYrr3lqnF"
host="127.0.0.1"
service="mysqld"

metric_arrays=(metric_global_status metric_slave_status metric_global_variables)

metric_global_status=(Aborted_clients:compute Aborted_connects:compute Bytes_received:compute Bytes_sent:compute Com_lock_tables:compute Com_rollback:compute Com_delete:compute Com_insert:compute Com_insert_select:compute Com_load:compute Com_replace:compute Com_select:compute Com_update:compute Qcache_hits:compute Slow_queries:compute Threads_connected:undefined Threads_running:undefined Uptime:undefined Queries:compute)

metric_slave_status=(Seconds_Behind_Master:undefined)

metric_global_variables=(query_cache_size:undefined)

Get_current_value(){
    flag=$1
    case $flag in
        global_status)
            sql="show global status"
            eval $(mysql -u$user -p$pass -h$host -P$port -e "$sql" 2>/dev/null|awk '{printf("mysqld_%s=\"%s\"\n",$1,$2)}')
            ;;
        slave_status)
            sql="show slave status\G"
            eval $(mysql -u$user -p$pass -h$host -P$port -e "$sql" 2>/dev/null|awk -F'[: ]+' 'NF==3{v=$3~/^[0-9.]+$/?$3:-1;$0="mysqld_"$2"="v;print $0}')
            ;;
        global_variables)
            sql="show global variables"
            eval $(mysql -u$user -p$pass -h$host -P$port -e "$sql" 2>/dev/null|awk '{printf("mysqld_%s=\"%s\"\n",$1,$2)}')
            ;;
    esac
}
Curl_falcon(){
    for metric_array in ${metric_arrays[@]};do
        {
            for pre_metric in $(eval echo \${$metric_array[@]});do
                    [[ "$pre_metric" =~ ':compute' ]] \
                        && countertype="COUNTER" \
                        || countertype="GAUGE"
                    metric="mysqld_${pre_metric%%:*}"
                    value=$(eval echo \$$metric)
					[[ "$value" == "" ]] \
						&& value="-1"
					data_unit='{"metric":"'$metric'","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$value',"counterType":"'$countertype'","tags":"'$tags'"}'
        			[[ "$data_final" == "" ]] \
        			    && data_final=$data_unit \
        			    || data_final=$data_final,$data_unit
            done

			curl -s -X POST -d '['$data_final']' http://127.0.0.1:1988/v1/push

        } &
    done
}

Test_max_connection(){
     /usr/bin/mysql -u$user -p$pass -h$host -P$port -e 'quit' 2>&1 |grep -qi 'Too many connections'  \
		&& dvd-falconpost -e$endpoint -mmysqld_Threads_connected -s$step -v-1 -t"$tags" \
        && exit
}
Test_app_alive(){
	/usr/bin/mysqladmin -u$user -p$pass -h$host -P$port ping 2>/dev/null |grep -qi "mysqld is alive" \
		&& app_alive_status=0 \
		|| app_alive_status=1
    dvd-falconpost -mmysqld_alive -e$endpoint -s$step -v$app_alive_status -t"$tags"
}
Test_port_status(){
    port_status=$($bin_path/check_tcp -H $host -p $port|awk -F'[ :]' '{print $2=="OK"?0:1}')
    dvd-falconpost -mmysqld_port -e$endpoint -s$step -v$port_status -t"$tags"
}
Test_slave_status(){
    slave_status_flag=$(/usr/bin/mysql -u$user -p$pass -h$host -P$port -e "show slave status\G" 2>/dev/null |egrep -i "Slave_IO_Running|Slave_SQL_Running"|grep -i "yes"|grep -v "grep"|wc -l)
	[ "$slave_status_flag" -eq 2 ] \
		&& slave_status=0 \
		|| slave_status=1
	dvd-falconpost -e$endpoint -mmysqld_slavestatus -s$step -v$slave_status -t"$tags"
}
Test_slave_delay(){
	slave_delay=$(/usr/bin/mysql -u$user -p$pass -h$host -P$port -e "show slave status\G" 2>/dev/null |awk  '$0~"Seconds_Behind_Master"{print $NF=="NULL"?0:$NF}')
	dvd-falconpost -mmysqld_slavedelay -e$endpoint -s$step -v$slave_delay -t"$tags"
}
Main(){
	for file in $(find $config_path -name 'my*.cnf');do
		port=$(echo $file|grep -Po '(?<=my)\d+(?=.cnf)')
		#eval $(awk -F: '$1~/^(port|host|role)$/&&$0=$1"="$2' $file)
		tags=$(awk -F: -vs="port=$port" '{$0~"#\\[Mysqld_monitortag"?Flag=1:1}Flag{s=match($0,/#([^:]+):(.+)/,a)?s","a[1]"="a[2]:s}END{print s}' $file)
		echo $tags
		{
		    Test_max_connection
		    Test_port_status
		    Test_app_alive
		    Get_current_value global_status
		    Get_current_value global_variables
			[[ "$role" == "slave" ]] \
		    	&& {
					Test_slave_status
		    		Get_current_value slave_status
			    	Test_slave_delay
				}
		    Curl_falcon
		} &
	done
    wait
}
Main &>/dev/null
