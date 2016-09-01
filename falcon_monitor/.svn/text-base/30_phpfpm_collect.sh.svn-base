#!/bin/bash

timestamp=$(date +%s)
endpoint=$HOSTNAME
step=$(echo $0|grep -Po '\d+(?=_)')
dirname=$(cd $(dirname $0);pwd|awk -F\/ '$0=$NF')
bin_path="/home/service/falcon-agent/nagios/libexec"
host="127.0.0.1"
service="php-fpm"
fpm_config="/etc/php-fpm.d/www.conf"
metric_fpm=(start_time:undefined start_since:undefined accepted_conn:undefined listen_queue:undefined max_listen_queue:undefined listen_queue_len:undefined idle_processes:undefined active_processes:undefined total_processes:undefined max_active_processes:undefined max_children_reached:undefined)


Get_current_value(){
	eval $(env SCRIPT_NAME=/phpfpmstatus SCRIPT_FILENAME=/phpfpmstatus QUERY_STRING= REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:$port| awk '{match($0,/([^:]+): +([0-9]+)/,a);printf a[1]a[2]?"phpfpm_"gensub(" ","_","g",a[1])"="a[2]"\n":""}')
}
Curl_falcon(){
	for pre_metric in ${metric_fpm[@]};do
			[[ "$pre_metric" =~ ':compute' ]] \
				&& countertype="COUNTER" \
				|| countertype="GAUGE"
			metric="phpfpm_${pre_metric%%:*}"
			value=$(eval echo \$$metric)
			data_unit='{"metric":"'$metric'","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$value',"counterType":"'$countertype'","tags":"'$tags'"}'
			[[ "$data_final" == "" ]] \
				&& data_final=$data_unit \
				|| data_final=$data_final,$data_unit
        done
		curl -s -X POST -d '['$data_final']' http://127.0.0.1:1988/v1/push
	wait


}
Test_port_status(){
    port_status=$($bin_path/check_tcp -H 127.0.0.1 -p $port|awk -F'[ :]' '{print $2=="OK"?0:1}')
    dvd-falconpost -mphpfpm_port -s$step -v$port_status -t"$tags"
    [[ "$port_status" == 1 ]] \
        && continue
}
Get_process_percent(){
	max_process=$(awk '$1=="pm.max_children"&&$0=$3' $fpm_config)
	processnum_per=$(awk 'BEGIN{printf("%0.2f",'$phpfpm_active_processes'/'$max_process')}')
	dvd-falconpost -mphpfpm_processnum_per -s$step -v$processnum_per -t"$tags"
}

Main(){
	#for file in $(find /usr/local/php/etc/pool.d/ -type f -name *.conf);do
		#port=$(awk -F'[: ]+' '/listen/&&$0=$NF' $file)
		port=9000
		#tags=$(awk -F: -vs="port="$port '{$0~"Mt_Phpfpm_monitortag"?Flag=1:$0!~/^;/?Flag=0:1}Flag{s=match($0,/;([^:]+):(.+)/,a)?s","a[1]"="a[2]:s}END{print s}' $file)
		tags="port=$port"
	#	{
		Get_current_value
		Get_process_percent
		Test_port_status
		Curl_falcon
	#	} &
	#done
	#wait
}
Main &>/dev/null
