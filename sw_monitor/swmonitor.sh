#!/bin/bash

base_path=$(cd $(dirname $0);pwd)
ip_list=$base_path/iplist
nettopo_list=$base_path/nettopolist
c_str=meitucomview
snmp_version=2c
sw_cmd="snmpwalk -v$snmp_version -c$c_str"
interval=60
thread_file="$base_path/thread.pipe"
thread_num=30
local_ip=$(hostname -i)
local_idc=${HOSTNAME%%-*} 
power_status_oid="1.3.6.1.4.1.25506.8.35.9.1.2.1.2"
sensortemp_status_oid="1.3.6.1.4.1.25506.2.6.1.1.1.1.12"
cpu_usage_oid="1.3.6.1.4.1.25506.2.6.1.1.1.1.6"
mem_usage_oid="1.3.6.1.4.1.25506.2.6.1.1.1.1.8"
fan_status_oid="1.3.6.1.4.1.25506.8.35.9.1.1.1.2"
index_oid="1.3.6.1.2.1.47.1.1.1.1.7"


Init_thread(){
    thread_file=$1
    thread_num=$2
        rm -rf $thread_file
        mkfifo $thread_file
        exec 9<>$thread_file
    if [ "$2" == 0 ];then
        return
    else
        for num in $(seq 1 $thread_num);do
            Operate_fd insert
        done
    fi
}

Close_thread(){
	exec 9>&-
}

Operate_fd(){
        case $1 in
                insert) echo " " 1>&9   ;;
                delete) read -u 9   ;;
        esac
}
Net_topo_collect(){

	grep -v "$local_ip" $nettopo_list|while read target_idc target_ip;do 
		eval $(/usr/sbin/fping -ec1 $target_ip  2>&1 1>/dev/null | awk '$0!~/^$/{match($0,/%loss = [0-9]+\/[0-9]+\/([^,]+)%/,a);match($0,/max = [0-9.]+\/([0-9.]+)\/.+$/,b);t=b[1]?b[1]:-1;print "ping_loss="a[1]";ping_delay="t}')
		mt-falconpost -eNET-TOPO-MONITOR -mpingLoss -v$ping_loss -t\"idc_pointing=${local_idc}_to_$target_idc,ip_pointing=${local_ip}_to_$target_ip\"
		mt-falconpost -eNET-TOPO-MONITOR -mpingDelay -v$ping_delay -t\"idc_pointing=${local_idc}_to_$target_idc,ip_pointing=${local_ip}_to_$target_ip\"
	done
}
		
Port_collect(){

 	for ip in $(cat $ip_list|awk '$2=="Mon_'$local_ip'"&&$0=$NF');do
		Operate_fd delete 
		{
			endpoint=$($sw_cmd $ip sysname|awk '$0=$NF')
			step=60
			timestamp=$(date +%s)

			/usr/sbin/fping $ip && agent_status=1 || agent_status=0
			mt-falconpost -e$endpoint -magent.alive -v$agent_status -t"ip=$ip"
			$sw_cmd $ip $index_oid|grep -Pi 'BOARD|SENSOR'|awk '{match($0,/([0-9]+) = STRING: "([A-Za-z]+)/,a);print a[1]" "a[2]" null"}' > .tmp_file_$ip
			$sw_cmd $ip $power_status_oid |awk '{match($0,/([0-9]+) = INTEGER: ([0-9]+)/,a);print a[1]" power "a[2]}' >> .tmp_file_$ip
			$sw_cmd $ip $fan_status_oid|awk '{match($0,/([0-9]+) = INTEGER: ([0-9]+)/,a);print a[1]" fan "a[2]}' >> .tmp_file_$ip
			while read index index_type value;do
				case $index_type in
					[Ss][Ee][Nn][Ss][Oo][Rr])
						sensor_temp=$($sw_cmd $ip $sensortemp_status_oid.$index|awk '$0=$NF')	
						tags="sensorIndex=$index,ip=$ip"
						data='{"metric":"sensorTemp","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$sensor_temp',"counterType":"GAUGE","tags":"'$tags'"}'
						;;
					Board)
						cpuUsage=$($sw_cmd $ip $cpu_usage_oid.$index|awk '$0=$NF')
						memUsage=$($sw_cmd $ip $mem_usage_oid.$index|awk '$0=$NF')
						tags="boardIndex=$index,ip=$ip"
						data='{"metric":"cpuUsage","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$cpuUsage',"counterType":"GAUGE","tags":"'$tags'"},{"metric":"memUsage","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$memUsage',"counterType":"GAUGE","tags":"'$tags'"}'
						;;
					power)
						powerStatus=$value
						tags="powerIndex=$index,ip=$ip"
						data='{"metric":"powerStatus","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$value',"counterType":"GAUGE","tags":"'$tags'"}'
						;;
					fan)
						fanStatus=$value
						tags="fanIndex=$index,ip=$ip"
						data='{"metric":"fanStatus","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$value',"counterType":"GAUGE","tags":"'$tags'"}'
						;;
				esac
				[ "$post_data" == "" ] \
					&& post_data=$data \
					|| post_data=$post_data","$data
				
			done < .tmp_file_$ip
			curl -s -X POST -d '['$post_data']' http://192.168.133.64:1988/v1/push

			rm -f .tmp_file_$ip
			eval $($sw_cmd $ip ifDescr|awk -F'[. ]+' '$0="ifName_"$2"="$NF')
			eval $($sw_cmd $ip ifOperStatus|awk -F'[. )(]+' '$0="PortStatus_"$2"="$(NF-1)')
			eval $($sw_cmd $ip IF-MIB::ifHCInOctets|awk -F'[. ]+' '$0="ifIn_"$2"="$NF')
			eval $($sw_cmd $ip IF-MIB::ifHCOutOctets|awk -F'[. ]+' '$0="ifOut_"$2"="$NF')
			for ifFlag in $($sw_cmd $ip ifIndex|awk '$0=$NF');do
				tags="ifName=$(eval echo \$ifName_$ifFlag),ifIndex=$ifFlag,ip=$ip"
				data='{"metric":"PortStatus","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$(eval echo \$PortStatus_$ifFlag)',"counterType":"GAUGE","tags":"'$tags'"},{"metric":"ifIn","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$(eval echo \$ifIn_$ifFlag)',"counterType":"COUNTER","tags":"'$tags'"},{"metric":"ifOut","endpoint":"'$endpoint'","timestamp":'$timestamp',"step":'$step',"value":'$(eval echo \$ifOut_$ifFlag)',"counterType":"COUNTER","tags":"'$tags'"}'
				[ "$post_data" == "" ] \
					&& post_data=$data \
					|| post_data=$post_data","$data
				
			done
			curl -s -X POST -d '['$post_data']' http://192.168.133.64:1988/v1/push
			wait
			Operate_fd insert
		}&
	done
	wait
}
Main(){
	Init_thread $thread_file $thread_num
	Net_topo_collect
	Port_collect
	Close_thread
}
Main
