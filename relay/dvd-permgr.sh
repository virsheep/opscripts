#!/bin/bash

base_path=$(cd $(dirname $0);pwd)
user_list=$base_path/user.list
host_list=$base_path/host.list
operation=$1
local_user=$2
remote_host=$3
remote_user=$4
Add_permission(){
	pub_key="$(eval cat ~$local_user/.ssh/id_rsa.pub)"
	ssh -o PasswordAuthentication=no -o ConnectTimeout=3 $remote_host "
		grep -q '^'$remote_user':' /etc/passwd \
			|| useradd $remote_user
		[ -f ~$remote_user/.ssh/authorized_keys ] \
			|| {
				touch ~$remote_user/.ssh/authorized_keys
				chmod 644 ~$remote_user/.ssh/authorized_keys
			}
		echo "$pub_key" >>  ~$remote_user/.ssh/authorized_keys \
			&& echo "Add permission from $local_user to $remote_user@$remote_host success" \
			|| echo "Add permission from $local_user to $remote_user@$remote_host failed" \
	"
}
Del_permission(){
	pub_key="$(eval cat ~$local_user/.ssh/id_rsa.pub)"
	ssh -o PasswordAuthentication=no -o ConnectTimeout=3 $remote_host "
		grep -q '^'$remote_user':' /etc/passwd \
			|| {
				echo User $remote_user@$remote_host doesn\'t exist
				exit
			}
		sed -i '/$local_user@/d' ~$remote_user/.ssh/authorized_keys \
			&& echo "Del permission from $local_user to $remote_user@$remote_host success" \
			|| echo "Del permission from $local_user to $remote_user@$remote_host failed"
	"
}


Main(){
	case $operation in
		add)
			Add_permission
			;;
		del)
			Del_permission
			;;

	esac
}
Main
