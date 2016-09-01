#!/bin/bash

basePath=$(cd $(dirname $0);pwd)
operationList="$basePath/iplist"
thread_file="$basePath/thread.pipe"
thread_num=50
Op_thread(){
	operation=$1
	case $operation in
		init)
			rm -rf $thread_file
			mkfifo $thread_file
			exec 9<>$thread_file
			for num in $(seq $thread_num);do
				echo " " 1>&9
			done
			;;
		insert)
			echo " " 1>&9
			;;
		delete)
			read -u 9
			;;
		close)
			exec 9<&-
			;;
	esac
}

loop_operation(){
    for host in $(awk '$0=$1' $operationList);do
       	Op_thread delete
        {
            #some cmds


#            rsync -e "ssh -p 56868" --timeout=3 -az --delete  \
#				$host:/etc/php.ini tmp/$host
            ssh -p 56868 -o PasswordAuthentication=no -o ConnectTimeout=3 $host "
			"

            #cmds end
            Op_thread insert
        }&
    done
    wait
}
Main(){
    Op_thread init
    loop_operation
}
Main
