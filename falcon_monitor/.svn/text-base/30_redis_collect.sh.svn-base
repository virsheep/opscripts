#!/bin/bash

timestamp=$(date +%s)
endpoint=$HOSTNAME
step=30
dirname=$(cd $(dirname $0);pwd|awk -F\/ '$0=$NF')
bin_path="/home/service/falcon-agent/nagios/libexec"
base_path=$(cd $(dirname $0);pwd)
config_path="/etc/redis.conf.d"
service="redis"
host=127.0.0.1
metric_redis=(uptime_in_seconds:undefined rdb_bgsave_in_progress:undefined blocked_clients:undefined connected_clients:undefined connected_slaves:undefined expired_keys:undefined keyspace_hits:compute keyspace_misses:compute total_commands_processed:compute used_memory:undefined used_memory_rss:undefined total_connections_received:compute)


Get_current_value(){
	metric_re=$(echo ${metric_redis[@]}|sed -r 's/:\w+//g;s/ /|/g')
	eval  $(redis-cli $auth -h $host -p $port "info"|awk -F: -vre="^$metric_re$" '$1~re{printf("redis_%s=\"%d\"\n",$1,$2)}')
}

Get_current_conpercent(){
	redis_max_con=$(redis-cli $auth -h $host -p $port config get maxclients|awk 'NR>1')
	redis_cur_con=$redis_connected_clients
	#echo con $redis_cur_con/$redis_max_con $host $port
	redis_connected_percent=$(awk 'BEGIN{printf("%.2f\n", int("'$redis_max_con'")==0?0:'$redis_cur_con'/int("'$redis_max_con'"))}')
	dvd-falconpost -e$endpoint -mredis_connected_percent -v$redis_connected_percent -s$step -t"$tags"
}
Get_current_mempercent(){
	redis_max_mem=$(redis-cli $auth -h $host -p $port config get maxmemory|awk 'NR>1')
	redis_cur_mem=$redis_used_memory
	#echo mem $redis_cur_mem/$redis_max_mem $host $port
	redis_mem_percent=$(awk 'BEGIN{printf("%.2f\n", int("'$redis_max_mem'")==0?0:'$redis_cur_mem'/int("'$redis_max_mem'"))}')
	dvd-falconpost -e$endpoint -mredis_mem_percent -v$redis_mem_percent -s$step -t"$tags"
}


Curl_falcon(){
		for pre_metric in ${metric_redis[@]};do
			[[ "$pre_metric" =~ ':compute' ]] \
				&& countertype="COUNTER" \
				|| countertype="GAUGE"
			metric="redis_${pre_metric%%:*}"
			value=$(eval echo \$$metric)
			[[ x"$value" == "x" ]] \
				&& continue
        	data_unit='{"metric":"'$metric'","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$value',"counterType":"'$countertype'","tags":"'$tags'"}'
        	[[ "$data_final" == "" ]] \
        	    && data_final=$data_unit \
        	    || data_final=$data_final,$data_unit
    done
	echo $data_final
    curl -s -X POST -d '['$data_final']' http://127.0.0.1:1988/v1/push
}

Test_max_connection(){
	redis-cli $auth -h $host -p $port "quit" | egrep -iq "ERR max number" \
		&& dvd-falconpost -e$endpoint -mredis_connected_clients -s$step -v"-1" -t"$tags" \
        && exit
}
Test_port_status(){
    port_status=$($bin_path/check_tcp -H $host -p $port|awk -F'[ :]' '{print $2=="OK"?0:1}')
    dvd-falconpost -e$endpoint -mredis_port -s$step -v$port_status -t"$tags"
    [[ "$port_status" == 1 ]] \
		&& continue
}

Main(){
	for file in $(find $config_path -name 'r*.conf');do
		port=$(echo $file|grep -Po '(?<=r)\d+(?=.conf)')
		tags=$(awk -F: -vs="port=$port" '{$0~"#\\[Redis_monitortag"?Flag=1:1}Flag{s=match($0,/#([^:]+):(.+)/,a)?s","a[1]"="a[2]:s}END{print s}' $file)
		auth=$(awk -F: '$1=="#pass"&&$0="-a "$2' $file)
		{
			Test_max_connection
			Test_port_status
			Get_current_value
			Get_current_conpercent
			Get_current_mempercent
			Curl_falcon
		} &
	done
    wait
}
Main   &>/dev/null
