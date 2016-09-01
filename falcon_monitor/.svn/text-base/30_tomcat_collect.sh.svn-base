#!/bin/bash

timestamp=$(date +%s)
endpoint=$HOSTNAME
step=30
dirname=$(cd $(dirname $0);pwd|awk -F\/ '$0=$NF')
bin_path="/home/service/falcon-agent/nagios/libexec"
base_path=$(cd $(dirname $0);pwd)
config_path="/etc/redis.conf.d"
service="tomcat"
host=127.0.0.1
conf_path_list="/home/q/www/y.davdian.com/conf /home/q/www/message.davdian.com/conf/ /usr/local/tomcat/conf /home/q/m.bravetime.net/conf/"

Test_port_status(){
    port_status=$($bin_path/check_tcp -H $host -p $port|awk -F'[ :]' '{print $2=="OK"?0:1}')
    dvd-falconpost -e$endpoint -mtomcat_port -s$step -v$port_status -t"$tags"
    [[ "$port_status" == 1 ]] \
		&& continue
}
Main(){
	for file_path in $conf_path_list;do
		[ ! -d $file_path ] \
			&& continue
	awk 'BEGIN{a=1}/<!--/{a--}/-->/{a++}/<(Server|Connector)/&&a{match($0,/port="([0-9]+)/,b);host=match($0,/address="([0-9.]+)/,c)?c[1]:"127.0.0.1";print b[1],host}' $file_path/server.xml|while read port host;do
			tags=$(awk -F: -vs="port=$port" '{$0~"#\\[Tomcat_monitortag"?Flag=1:1}Flag{s=match($0,/#([^:]+):(.+)/,a)?s","a[1]"="a[2]:s}END{print s}' $file_path/server.xml)
			Test_port_status
		done
	done
    wait
}
Main  &>/dev/null
