#!/bin/bash

base_path=$(cd $(dirname $0);pwd)
build_path=/tmp/build
back_path=/mnt/code_bakcup
tmp_path=/tmp/tmp
log_path=$base_path/log
fekey_path=$base_path/fekey
template_path=$base_path/template
fekey_prod_path=/mnt/export/product/
ip_list="$base_path/ip.list"
module_conf="$base_path/module.conf"
tool_name="Davdian release script"
cur_date=$(date +%Y%m%d-%H:%M:%S)
version=0.1
script_name=$0
operation=$1
module=$2
re_env=$3
svn_path=$4
cur_user=$5
keypush_list=$6
args_count=$#
args=$@
sshd_port=56868
rsync_module="test"

thread_file="$base_path/thread.pipe"
thread_num=10


Init_thread(){
    rm -rf $thread_file
    mkfifo $thread_file
    exec 9<>$thread_file
	for num in $(seq 1 $thread_num);do
		Operate_fd insert
	done
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

Init_env(){
	mkdir -p $build_path
	mkdir -p $back_path
	mkdir -p $tmp_path
	mkdir -p $template_path
	Init_thread

}

Show_help(){
	Split_line
	echo -e "
    ${tool_name##*/} v$version
	A release script to push the codes to the prod/qa/dev env.

    Usage:
        sh $script_name \$operation \$module \$env \$svn_path \$username \$keypushpath
	Arguments:
		operation   : push or rollback
		module 	    : module_name
		env         : env iplist_name
		svn_path    : svn path post
		username    : username of operator
		keypushpath : fekey push list
    "
	Split_line
}

Test_args(){
	[[ "$args" =~ "--help" ]] \
		&& Show_help \
		&& exit
    [[ "$args" =~ "--debug" ]] \
        && debug_flag=1 \
		&& exit
	[ "$args_count" != 5 -a "$args_count" != 6 ] \
		&& echo "ArgsError : Args num wrong"\
		&& Show_help \
		&& exit
    [ "$operation" != "pre" -a "$operation" != "push" -a "$operation" != "rollback" ] \
        &&  echo "ArgsError : Operation should only be pre or push " \
		&& Show_help\
        && exit
	grep -q "$re_env" $ip_list \
		|| {
			echo "ArgsError : No such env named $re_env" \
				&& Show_help\
				&& exit
		}
	[[ "$keypush_list" != "" ]] \
		&& {
			grep -q "$keypush_list" $ip_list \
				|| {
					echo "ArgsError : No such env named $re_env" \
						&& Show_help\
						&& exit
				}
		}

    grep -q "$module" $module_conf  \
        || {
			echo "ArgsError : No such module named $module" \
				&& Show_help\
				&& exit
		}
	[ "$svn_path" == "trunk" ] \
			&& svn_path_post="trunk" \
			|| svn_path_post="branch/$svn_path"
	[[ "$module" =~ ^(temp|images|data|cert|cron)_ ]] \
			&& svn_path_post=""
}

Parse_conf(){
	iplist=$(awk '$0~/\[/{flag=0}flag&&!/^#/{print}$0=="['$re_env']"{flag=1}' $ip_list)
	eval $(awk -F'\\|\\|' '!/^#/&&$1=="'$module'"{print "prod_path="$2";svn_path_pre="$3'} $module_conf)
#	echo module=$module
#	echo re_env=$re_env
#	echo prod_path=$prod_path
#	echo svn_path_pre=$svn_path_pre
#	echo "$iplist"
}


Svn_expt(){
	svn_path_final="$svn_path_pre/$svn_path_post"
	release_ver=$(svn info $svn_path_final|awk  '$1~/^(版本|Revision):/&&$0=$2')

	[ "x$release_ver" == "x" ] \
		&& echo "ArgsError : No such svn path "\
		&& exit
	[ -d "$build_path/$re_env/$module" ] \
		&& rm -rf  /tmp/build/$re_env/$module
	Split_line
	echo -e "svn路径:$svn_path_final\nsvn版本:$release_ver\n操作人:$cur_user"
	Split_line
	Check_repl "确认检出"
	Split_line
	sleep 1
	svn export $svn_path_final $build_path/$re_env/$module --force  \
		&& Split_line \
		&& sleep 1 \
		&& echo "svn 文件检出成功" \
		|| {
			echo "svn 文件检出失败" \
				&& exit
		}

}
Check_push(){
	Split_line
	echo "推送列表为:"
	Split_line
	echo "$iplist"
	Split_line
	Check_repl "检查服务器传输协议和连通性"
	Split_line

	for ip in $iplist;do
		rsync  -e "ssh -p $sshd_port"  -an $build_path/$re_env/$module/ $ip:$prod_path/ \
			&& echo $ip   :   ready. \
			|| { echo $ip   :   ready. \
					&& let error_count++
			}
	done
	Split_line
	Check_repl "检查文件diff信息"
	Split_line
	#tmp_path
	rm -rf /tmp/tmp/*
	[[ "$module" =~ ^fe_ ]] \
		&& echo "前端上线跳过diff功能 "\
		&& return

	for ip in $iplist;do
		echo "@$ip"
		mkdir -p $tmp_path/$ip/$re_env
		rsync -e "ssh -p $sshd_port" -az --delete $ip:$prod_path/ $tmp_path/$ip/$re_env/$module/
		diff -r $build_path/$re_env/$module $tmp_path/$ip/$re_env/$module
		#break
		Split_line
	done
}
Push_code(){
	Split_line
	Check_repl "推送代码"
	Split_line
	for ip in $iplist;do
		rsync -e "ssh -p $sshd_port" -az --delete $build_path/$re_env/$module/ $ip:$prod_path/ \
			&& echo "$ip  rsyncd  succeed " \
			|| echo "$ip  rsyncd  failed  "
	done
    case $module in
    	fe_*)
    		fekey_iplist=$(awk '$0~/\[/{flag=0}flag&&!/^#/{print}$0=="['$keypush_list']"{flag=1}' $ip_list)
    		case $keypush_list in 
    			*dev)
					dev_flag=$(echo $keypush_list|grep -Po '(?<=_)\d+(?=_)')
					for ip in $fekey_iplist;do
						rsync -e "ssh -p $sshd_port" -az $fekey_path/.$key_file_name $ip:/$fekey_prod_path/.${key_file_name}$dev_flag
					done
					;;
    			*oa)
					dev_flag=$(echo $keypush_list|grep -Po '(?<=_)\d+(?=_)')
					for ip in $fekey_iplist;do
						rsync -e "ssh -p $sshd_port" -az $fekey_path/.$key_file_name $ip:/$fekey_prod_path/.${key_file_name}$dev_flag
					done
					;;
						
    			*)
					for ip in $fekey_iplist;do
					    rsync -e "ssh -p $sshd_port" -az $fekey_path/.$key_file_name $ip:/$fekey_prod_path/
					done
					;;
			esac
						
    				
    		
    		;;
    	*)
    		;;
    esac
	echo "[$cur_date] [$operation] [$cur_user] [$module] [$re_env] [$svn_path_final]" >> $log_path/$operation.log
	Split_line
}
Split_line(){
	echo "-------------------------------------------"
}
Check_repl(){
	message=$1
	echo $message
		
	#read -p "$message.  continue(y/n): " check_obj
	#case $check_obj in
	#	y|Y)
	#		;;
	#	n|N)
	#		exit
	#		;;
	#esac
}
Backup_code(){
	Split_line
	Check_repl "备份线上代码"
	Split_line
	[[ "$module" =~ ^fe_ ]] \
		&& echo "前端上线跳过备份功能" \
		&& return
	for ip in $iplist;do
	#	ssh $ip "rsync -az /workdir /backupdir_$cur_date"
		ssh -p $sshd_port $ip  -o stricthostkeychecking=no -o ConnectTimeout=3 "rsync -az --delete $prod_path/ $back_path/${prod_path##*/}/ "  \
			&& echo "$ip backup succeed " \
			|| echo "$ip backup failed "
	done
	Split_line
}
Init_pay_url_dev(){

	echo "[开始] 修改支付url"
	sed -i 's;wxpay/\wxpay_callback.php;wxpay_t/\wxpay_callback.php;' $build_path/$re_env/$module/wxpay/vendor/WxPayPubHelper/WxPay.pub.config.php

	if [ `grep -R 'open.bravetime.net/wxpay/wxpay.php?weixin=1' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/wxpay.php?weixin=1]"
		grep -R 'open.bravetime.net/wxpay/wxpay.php?weixin=1' $build_path/$re_env/$module | awk -F ':' '{print $1}' |  xargs sed -i "s;open.bravetime.net\/wxpay\/wxpay.php?weixin=1;open.davdian.com\/wxpay_t\/wxpay.php?weixin=1;g"
	else
		echo "No match [open.bravetime.net/wxpay/wxpay.php?weixin=1]"
	fi

	if [ `grep -R 'open.bravetime.cn/wxpay/wxpay.php?weixin=1' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/wxpay.php?weixin=1]"
		grep -R 'open.bravetime.cn/wxpay/wxpay.php?weixin=1' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s;open.bravetime.cn\/wxpay\/wxpay.php?weixin=1;open.davdian.com\/wxpay_t\/wxpay.php?weixin=1;g"
	else
		echo "No match [open.bravetime.cn/wxpay/wxpay.php?weixin=1]"
	fi

	if [ `grep -R 'open.bravetime.net/wxpay/wxpay.php?weixin=0' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/wxpay.php?weixin=0]"
		grep -R 'open.bravetime.net/wxpay/wxpay.php?weixin=0' $build_path/$re_env/$module | awk -F ':' '{print $1}' |xargs sed -i "s;open.bravetime.net\/wxpay\/wxpay.php?weixin=0;open.bravetime.net\/wxpay_t\/wxpay.php?weixin=0;g"
	else
		echo "No match [open.bravetime.net/wxpay/wxpay.php?weixin=0]"
	fi

	if [ `grep -R 'open.bravetime.cn/wxpay/wxpay.php?weixin=0' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.cn/wxpay/wxpay.php?weixin=0]"
		grep -R 'open.bravetime.cn/wxpay/wxpay.php?weixin=0' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s;open.bravetime.cn\/wxpay\/wxpay.php?weixin=0;open.bravetime.cn\/wxpay_t\/wxpay.php?weixin=0;g"
	else
		echo "No match [open.bravetime.cn/wxpay/wxpay.php?weixin=0]"
	fi

	if [ `grep -R 'open.bravetime.net/wxpay/wxpay.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/wxpay.php]"
		grep -R 'open.bravetime.net/wxpay/wxpay.php' $build_path/$re_env/$module | grep -v 'open.bravetime.net/wxpay/wxpay.php?weixin=' | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.net\/wxpay\/wxpay.php/open.davdian.com\/wxpay_t\/wxpay.php/g"
	else
		echo "No match [open.bravetime.net/wxpay/wxpay.php]"
	fi

	if [ `grep -R 'open.bravetime.cn/wxpay/wxpay.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.cn/wxpay/wxpay.php]"
		grep -R 'open.bravetime.cn/wxpay/wxpay.php' $build_path/$re_env/$module | grep -v 'open.bravetime.cn/wxpay/wxpay.php?weixin=' | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.cn\/wxpay\/wxpay.php/open.davdian.com\/wxpay_t\/wxpay.php/g"
	else
		echo "No match [open.bravetime.cn/wxpay/wxpay.php]"
	fi

	if [ `grep -R 'open.bravetime.net/wxpay/native.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/native.php]"
		grep -R 'open.bravetime.net/wxpay/native.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.net\/wxpay\/native.php/open.davdian.com\/wxpay_t\/native.php/g"
	else
		echo "No match [open.bravetime.net/wxpay/native.php]"
	fi

	if [ `grep -R 'open.bravetime.cn/wxpay/native.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.cn/wxpay/native.php]"
		grep -R 'open.bravetime.cn/wxpay/native.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.cn\/wxpay\/native.php/open.davdian.com\/wxpay_t\/native.php/g"
	else
		echo "No match [open.bravetime.cn/wxpay/native.php]"
	fi

	if [ `grep -R 'open.bravetime.net/wxpay/wxpay_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.net/wxpay/wxpay_callback.php]"
		grep -R 'open.bravetime.net/wxpay/wxpay_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.net\/wxpay\/wxpay_callback.php/open.bravetime.net\/wxpay_t\/wxpay_callback.php/g"
	else
		echo "No match [open.bravetime.net/wxpay/wxpay_callback.php]"
	fi

	if [ `grep -R 'open.bravetime.cn/wxpay/wxpay_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		echo "Replace [open.bravetime.cn/wxpay/wxpay_callback.php]"
		grep -R 'open.bravetime.cn/wxpay/wxpay_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/open.bravetime.cn\/wxpay\/wxpay_callback.php/open.bravetime.cn\/wxpay_t\/wxpay_callback.php/g"
	else
		echo "No match [open.bravetime.net/wxpay/wxpay_callback.php]"
	fi

	sed -i 's;davdian;bravetime;g' $build_path/$re_env/$module/include/Common.php
	sed -i 's;com;net;g' $build_path/$re_env/$module/include/Common.php
	sed -i 's/bravetime.net/davdian.com/g' $build_path/$re_env/$module/alipay/alipay.config.php
	sed -i 's/bravetime.net/davdian.com/g' $build_path/$re_env/$module/wxpay/vendor/WxPayPubHelper/WxPay.pub.config.php
	echo "[结束] 修改支付url"
}
Init_admin_db_conf(){
	user_no=`cat -n $template_file |grep  -w "DB" -A 6|grep -w "DB_USER"|awk '{print $1}'`
	sed -i "${user_no}s/'DB_USER' => 'davdian'/'DB_USER' => 'mamamba'/1" $template_file
	user_pwd=`cat -n $template_file |grep  -w "DB" -A 6|grep -w "DB_PWD"|awk '{print $1}'`
	sed -i "${user_pwd}s/'DB_PWD' => 'e50e-11e4-a8f3-3c15c2c1fbbc'/'DB_PWD' => 'JYRupWtgk95r5C7Eck'/g " $template_file

	user_no_s=`cat -n $template_file |grep  -w "SDB" -A 6|grep -w "DB_USER"|awk '{print $1}'`
	sed -i "${user_no_s}s/'DB_USER' => 'mamamba'/'DB_USER' => 'davdian'/1" $template_file
	user_pwd_s=`cat -n $template_file |grep  -w "SDB" -A 6|grep -w "DB_PWD"|awk '{print $1}'`
	sed -i "${user_pwd_s}s/'DB_PWD' => 'JYRupWtgk95r5C7Eck'/'DB_PWD' => 'e50e-11e4-a8f3-3c15c2c1fbbc'/g " $template_file

	user_no_bi=`cat -n $template_file |grep  -w "BI_DB" -A 6|grep -w "DB_USER"|awk '{print $1}'`
	sed -i "${user_no_bi}s/'DB_USER' => 'mamamba'/'DB_USER' => 'davdian'/1" $template_file
	user_pwd_bi=`cat -n $template_file |grep  -w "BI_DB" -A 6|grep -w "DB_PWD"|awk '{print $1}'`
	#sed -i "${user_pwd_bi}s/'DB_PWD' => 'e50e-11e4-a8f3-3c15c2c1fbbc'/'DB_PWD' => 'JYRupWtgk95r5C7Eck'/g " $template_file
}

Init_pay_url_prod(){

	echo "[开始] 修改支付url"
	sed -i 's;wxpay/\wxpay_callback.php;wxpay_t2/\wxpay_callback.php;' $build_path/$re_env/$module/wxpay/vendor/WxPayPubHelper/WxPay.pub.config.php
	if [ `grep -R '/wxpay/wxpay.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay.php/\/wxpay_t2\/wxpay.php/g"
	fi
	if [ `grep -R '/wxpay/native.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/native.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/native.php/\/wxpay_t2\/native.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i"s/\/wxpay\/wxpay_callback.php/\/wxpay_t2\/wxpay_callback.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_app.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_app.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay_app.php/\/wxpay_t2\/wxpay_app.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_app_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_app_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay_app_callback.php/\/wxpay_t2\/wxpay_app_callback.php/g"
	fi
}
Init_pay_url_oa(){

	echo "[开始] 修改支付url"
	sed -i 's;wxpay/\wxpay_callback.php;wxpay_t3/\wxpay_callback.php;' $build_path/$re_env/$module/wxpay/vendor/WxPayPubHelper/WxPay.pub.config.php
	if [ `grep -R '/wxpay/wxpay.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay.php/\/wxpay_t3\/wxpay.php/g"
	fi
	if [ `grep -R '/wxpay/native.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/native.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/native.php/\/wxpay_t3\/native.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i"s/\/wxpay\/wxpay_callback.php/\/wxpay_t3\/wxpay_callback.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_app.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_app.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay_app.php/\/wxpay_t3\/wxpay_app.php/g"
	fi
	if [ `grep -R '/wxpay/wxpay_app_callback.php' $build_path/$re_env/$module | wc -l` -gt 0 ]; then
		grep -R '/wxpay/wxpay_app_callback.php' $build_path/$re_env/$module | awk -F ':' '{print $1}' | xargs sed -i "s/\/wxpay\/wxpay_app_callback.php/\/wxpay_t3\/wxpay_app_callback.php/g"
	fi
	sed -i 's/vyohui.cn/davdian.com/g' $build_path/$re_env/$module/alipay/alipay.config.php
	sed -i 's/vyohui.cn/davdian.com/g' $build_path/$re_env/$module/wxpay/vendor/WxPayPubHelper/WxPay.pub.config.php
	echo "[结束] 修改支付url" 

}
Init_seller_domain(){
	echo "Init seller domain "
	sed -i 's/bravetime.net/davdian.com/g' $build_path/$re_env/$module/include/Common.php 
	sed -i 's/img.bravetime.net/pic.davdian.com/g' $build_path/$re_env/$module/include/apps/admin/view/index_head.php
	sed -i 's/img.bravetime.net/pic.davdian.com/g' $build_path/$re_env/$module/include/apps/admin/view/index_bottom.php
}

Init_domain_prod(){
	echo "replace domain prod "
   	grep -R 'bravetime.cn' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;bravetime.cn;davdian.com;g"
   	grep -R 'bravetime.net' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;bravetime.net;davdian.com;g"
   	grep -R 'mamamba.net'  $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;mamamba.net;davdian.com;g"
}
Init_domain_dev(){
   	echo "replace domain dev"
   	grep -R 'bravetime.cn' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;bravetime.cn;bravetime.net;g"
   	grep -R 'davdian.com' $build_path/$re_env/$module  |grep -v pic.davdian.com| awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;davdian.com;bravetime.net;g"
   	grep -R 'mamamba.net'  $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;mamamba.net;bravetime.net;g"
	grep -R 'pic.bravetime.net' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;pic.bravetime.net;pic.davdian.com;g"
	grep -R 'fe.' $build_path/$re_env/$module/themes/default/ | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;fe\.;fe2\.;g"j
}
Init_domain_oa(){
	echo "replace domain oa"
    grep -R 'bravetime.cn' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;bravetime.cn;vyohui.cn;g"
    grep -R 'bravetime.net' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;bravetime.net;vyohui.cn;g"
    grep -R 'mamamba.net'  $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;mamamba.net;vyohui.cn;g"
    grep -R 'pic.bravetime.net' $build_path/$re_env/$module | awk -F':' '{print $1}' | sort | uniq | xargs sed -i "s;pic.bravetime.net;pic.davdian.com;g"
}

Init_con_conf(){
	flag_num=$(echo $module|grep -Po '(?<=_)\d+(?=_)')
	for file in $(find $build_path/$re_env/$module/ -type f -name '*Convention.php*');do 
		sed -ri '/fe_wap/s/'"'"',/'$flag_num'&/g' $file
	done
}
Change_con_conf(){
	find /$build_path/$re_env/$module/ -type f -name '*Convention.php*' -exec rsync -az $template_file {} \;
	chown -R www.root /$build_path/$re_env/$module/data 2>/dev/null         
	[[ "$module" =~ ^(temp|images|data|cert)_ ]] \
		&&	chown -R www.root /$build_path/$re_env/$module 2>/dev/null         
}

Init_official(){
	grep -R 'manage.html' $build_path/$re_env/$module/ | awk -F':' '{print $1}' | sort | uniq | xargs sed -i 's/manage.html/http:\/\/s\.davdian.com\/login\.html/g'
    grep -R 'bravetime.cn' $build_path/$re_env/$module/ | awk -F':' '{print $1}' | sort | uniq | xargs sed -i 's/bravetime.cn/davdian.com/g'
}

Init_code(){
	r_num=$(awk 'BEGIN{srand();print int(rand()*10000+10000)}')
	env_flag=${module##*_}
	template_file=$template_path/Convention_$env_flag.php
	echo $env_flag
	rm -f $template_file
	cd $template_path
	svn export http://182.92.226.68:8000/svn/code/deploy/dev1/publishf/Convention_$env_flag.php

	case $module in
		fe_*)
			echo "[$cur_date] $r_num" >> $log_path/fekey.log
			prod_path=$prod_path/$r_num
			key_file_name=$(echo $module|sed -r 's/_(dev|prod|oa)//g')
			echo $r_num > $fekey_path/.$key_file_name
			;;
		admin_*)
			Init_admin_db_conf
			cd $build_path/$re_env/$module/
			ln -s images aimages
			case $env_flag in 
				dev)
					Init_domain_dev
					Change_con_conf
					Init_con_conf
					;;
				prod)
					Init_domain_prod
					Change_con_conf
					;;
				oa)
					Init_domain_oa
					Change_con_conf
					Init_con_conf
					;;
			esac
			;;
		mobile_*)
			cd $build_path/$re_env/$module/
			case $env_flag in
				dev)
					Init_domain_dev
					ln -s wxpay wxpay_t
					Init_pay_url_dev
					Change_con_conf
					Init_con_conf
					;;
				prod)
					Init_domain_prod
					ln -s wxpay wxpay_t2
					Init_pay_url_prod
					Change_con_conf
					;;
				oa)
					Init_domain_oa
					ln -s wxpay wxpay_t3
					Init_pay_url_oa
					Change_con_conf
					Init_con_conf
					;;
			esac
			;;
		seller_*)
			case $env_flag in
				dev)
					Init_domain_dev
					Init_seller_domain
					Change_con_conf
					Init_con_conf
					;;
				prod)
					Init_domain_prod
					Change_con_conf
					;;
				oa)
					Init_domain_oa
					Init_seller_domain
					Change_con_conf
					Init_con_conf
					;;
			esac
			;;
		official_*)
			Init_official
			;;
		*)
			case $env_flag in
				dev)
					Init_domain_dev
					Change_con_conf
					Init_con_conf
					;;
				prod)
					Init_domain_prod
					Change_con_conf
					;;
				oa)
					Init_domain_prod
					Change_con_conf
					Init_con_conf
					;;
			esac
			;;
	esac
}





Roll_back(){
	Split_line
	echo "回滚服务器列表为"
	Split_line
	echo "$iplist"
	Split_line
	echo "回滚相关信息"
	Split_line
	echo -e "模块:$module\n环境:$re_env"
	Split_line
	Check_repl "回滚确认"
	Split_line
	for ip in $iplist;do
	#	echo $back_path/${prod_path##*/}/  $prod_path/
		ssh -p $sshd_port $ip -o stricthostkeychecking=no -o ConnectTimeout=3 "rsync 	 -az $back_path/${prod_path##*/}/ $prod_path/" \
			&& echo "$ip rollback succeed" \
			|| echo "$ip rollback failed"
	done
	Split_line
	echo "[$cur_date] [$operation] [$cur_user] [$module] [$re_env]" >> $log_path/$operation.log
}
Main(){
	Init_env
	Test_args
	Parse_conf
	case $operation in
		pre|push)
			Svn_expt
			Init_code
			Check_push
			Backup_code
			Push_code
			;;
		rollback)
			Roll_back
			;;
	esac
}
Main
