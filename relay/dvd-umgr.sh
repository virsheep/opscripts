#!/bin/bash

#1/bin/bash

base_path=$(cd $(dirname $0);pwd)
chroot_path="/home/chroot"
key_path=$base_path/keys/
tool_name=$0
operation=$1
user=$2
key=$3

Split_line(){
	echo "-------------------------------------------------"
}
Error_out(){
	local content=$1
	echo "Error : $content"
}
User_add(){
	Split_line
	grep -q "^$user:" /etc/passwd \
		&& {
			Error_out "User $user exist!"
			Split_line
			exit
		} \
		||{
			useradd $user \
				&& echo "Add $user : success"
			mkdir -p /home/$user/.ssh
			ssh-keygen -t rsa -f /home/$user/.ssh/id_rsa -N "" &>/dev/null \
				&& echo "Generating key pair : success"
			sed -i 's/root@/'$user'@/' /home/$user/.ssh/id_rsa.pub
			rsync -az /home/$user/.ssh/id_rsa $key_path/$user
			rsync -az /home/$user/.ssh/id_rsa.pub $key_path/$user.pub
			touch /home/$user/.ssh/authorized_keys
			chmod 644 /home/$user/.ssh/authorized_keys
			chmod 644 /home/$user/.ssh/id_rsa.pub
			chmod 700 /home/$user/.ssh
			chown -R $user:$user /home/$user/.ssh
			mv -f /home/$user $chroot_path/home/
			ln -s $chroot_path/home/$user /home/$user
			echo -e "^$user$\t/home/chroot" >> /etc/security/chroot.conf
			[ "$key" != "" ] \
				&& {
					echo "$key" >> /home/$user/.ssh/authorized_keys \
						&& echo "Add chroot configration : success"
				}
		}
	Split_line
}

User_del(){
	Split_line
	grep -q "^$user:" /etc/passwd \
		&& {
			userdel $user \
				&& echo "Del $user : success"
			rm -rf /home/$user $chroot_path/home/$user \
				&& echo "Remove home dir : success"
			sed -i '/^\^'$user'\$/d' /etc/security/chroot.conf \
				&& echo "Remove chroot configration : success"
		} \
		|| {
			Error_out "User $user doesn't exist!"
			Split_line
			exit
		}
	Split_line
}
Key_update(){
	Split_line
	grep -q "^$user:" /etc/passwd \
		&& {
			[ "$pub_key" == "" ] \
				&& read -p "input the key.pub :" pub_key
			echo "$pub_key" >> /home/$user/.ssh/authorized_keys \
				&& echo "Pubkey updated : success"
		} \
		|| {
			Error_out "User $user doesn't exist!"
			Split_line
			exit
		}
	Split_line
}
Help_info(){
	Split_line
	echo -e "Usage :
	sh $0 \\
		   \${operation} \${user} \${keys}
Args  :
	operation	: 	add,del,key
	user 		:	username
	keys		:	pubkey with ' ' "
	Split_line
}



Main(){
	case $operation in
		--help)
			Help_info
			;;
		add)
			User_add
			;;
		del)
			User_del
			;;
		key)
			Key_update
			;;
		*)
			Error_out "Wrong Args "
			;;
	esac
}
Main
