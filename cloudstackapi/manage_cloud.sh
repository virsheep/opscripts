#!/bin/bash
source_path=/home/yangxu/scripts/source2.0
base_path=$(cd $(dirname $0);pwd)
host_list=/home/work/.host_list
api_key="XPwn4dh2vckm4ft_mmdeYi3cmTs69_IWRk-SRBPTrlr7bd6GRvLlTuTj4g9VclrauDfrZBoxzboovHpywR4D9g"
secret_key="49dHFf_5RwouU0TIgySNQFFgIob7jlgWQt1J-bwDvT36MyJhE-6Ad0VGEuFgK6BR1qW3Jd66_3GE6pzYAciVPA"
site_url="http://10.8.248.70:8080/client/api?"
info_item="id name created state templatename cpunumber cpuspeed memory cpuused ipaddress hostname"
tmp_item="name displaytext"
args=$@
args_num=$#
operation=$1
hostname=$2
tmpname=$3
sername=$4
Test_user(){
        user_name=$1
        [[ "$(whoami)" != $user_name ]] \
                && echo -r "U have to run this script as user $user_name" \
                && exit
}
Test_help(){
        help_info=$1
        [[ "$args" == "--help" ]] \
                && echo  "$help_info" \
                && exit
}
Signature_url(){
	unfinished_url=$1
	signature=$(echo -n "apikey=$api_key&$unfinished_url" 	\
		| sed 's/.*/\L&\E/'	\
		| openssl sha1 -binary -hmac "$secret_key"	\
		| base64	\
		| sed 's/+/%2B/g;s/\//%2F/g;s/=/%3D/g'
	)
}
Make_finalurl(){
	final_url="$site_url$1&apikey=$api_key&signature=$signature"
}
Get_list(){
	api_listinfo="command=listVirtualMachines&response=json"
			Signature_url $api_listinfo	
			Make_finalurl $api_listinfo
			listinfo_json=$(curl  -s "$final_url")
			echo $listinfo_json|awk  -vcl=$cluster -vRS='[^[]{\"id\":' 'NR>1{match($0,/displayname\":\"([^"]+)/,a);printf("%30-s",a[1]);match($0,/ipaddress\":\"([^"]+)/,b);printf("%20-s%s\n", b[1],cl)}'|sort -nk2 -t-
}
	
Get_hostinfo(){
	api_hostinfo="command=listVirtualMachines&name=$hostname&response=json"
	Signature_url $api_hostinfo	
	Make_finalurl $api_hostinfo
	hostinfo_json=$(curl  -s "$final_url")
	for item in $info_item;do
		echo  $hostinfo_json|awk '{match($0,/'$item'\"?:\"?([^,"]+)/,array);printf("%15s : %s\n","'$item'",array[1])}'
	done
}
Get_ipcapinfo(){
	api_ipcapinfo="command=listCapacity&response=json"
	Signature_url $api_ipcapinfo
	Make_finalurl $api_ipcapinfo
	ipcap_json=$(curl -s "$final_url")
	echo $ipcap_json|awk -vcl=$cluster -vFS='[:,"]' -vRS='{' '/type\":8/{for(;i++<NF;){if($i~/^[0-9]+$/)a[++j]=$i};printf ("可用:%-10d\t总容量:%-10d\t集群:%10-s\n",a[3]-a[2],a[3],cl)}'
}
	
Get_tmpinfo(){
	api_tmpinfo="command=listTemplates&response=json&templatefilter=selfexecutable"	
	Signature_url $api_tmpinfo
	Make_finalurl $api_tmpinfo
	tmpinfo_json=$(curl -s "$final_url")
	echo $tmpinfo_json|awk -vRS='\"name|displaytext|\"id' 'NR>1{match($0,/[^:"]+/,a);b[++i]=a[0]}END{for(;j<i;){printf("%-35s : %25s : %25-s\n",b[++j],b[++j],b[++j])}}'
	
}
Get_serinfo(){
	api_serinfo="command=listServiceOfferings&response=json"
	Signature_url $api_serinfo
	Make_finalurl $api_serinfo
        tmpinfo_json=$(curl -s "$final_url")
        echo $tmpinfo_json|awk -vRS='\"name|displaytext|\"id' 'NR>1{match($0,/[^:"]+/,a);b[++i]=a[0]}END{for(;j<i;){printf("%-35s : %25s : %25-s\n",b[++j],b[++j],b[++j])}}'
}
Destroy_vm(){
	destroy_id=$(Get_hostinfo|grep -Po '(?<=id : ).+') 
	api_destroy="command=destroyVirtualMachine&expunge=true&id=$destroy_id&response=json"
	Signature_url $api_destroy
	Make_finalurl $api_destroy
	destroy_res=$(curl -s "$final_url")
	error_txt=$(echo $destroy_res|grep -Po '(?<=errortext\":\")[^"]+')
	[ -n "$error_txt" ] \
		&& echo -r "$error_txt" \
		&& exit \
		|| echo "Success"
}
Create_vm(){
	tmplate_id=$(Get_tmpinfo|sed -n '/'$tmpname'/s/ .*//p')
	service_id=$(Get_serinfo|sed -n '/'$sername'/s/ .*//p')
	api_create="command=deployVirtualMachine&name=$hostname&response=json&serviceofferingid=$service_id&templateid=$tmplate_id&zoneid=1"
    #echo $api_create
	Signature_url $api_create
	Make_finalurl $api_create
	create_res=$(curl -s "$final_url")
	error_txt=$(echo $create_res|grep -Po '(?<=errortext\":\")[^;]+')
	[ -n "$error_txt" ] \
		&& echo -r  "$error_txt" \
		&& exit \
		|| echo "Success"
}
Reboot_vm(){
    reboot_id=$(Get_hostinfo|grep -Po '(?<=id : ).+')
	api_create="command=rebootVirtualMachine&id=$reboot_id&response=json"
	Signature_url $api_create
	Make_finalurl $api_create
	create_res=$(curl -s "$final_url")
	error_txt=$(echo $create_res|grep -Po '(?<=errortext\":\")[^;]+')
	[ -n "$error_txt" ] \
		&& echo -r  "$error_txt" \
		&& exit \
		|| echo "Success"
}
Update_list(){
	Get_list
}
Main(){
#	Test_user root
	Test_help "
Usage: sh $0 arg1 arg2 arg3 arg4
arg1:operations(create|destroy|tmpinfo|serinfo|hostinfo|list)
arg2:hostname
arg3:tmpname
arg4:sername
"
	Update_list > $host_list
	
	case $operation in 
		hostinfo)
			Get_hostinfo		
			;;
		tmpinfo)
			Get_tmpinfo
			;;
		serinfo)
			Get_serinfo
			;;
		destroy)
			Destroy_vm
			;;
		create)
			Create_vm
			;;
        reboot)
            Reboot_vm
            ;;
		list)	
			cat $host_list
			;;
		ipcap)
			Get_ipcapinfo
			;;
	esac
}
Main
