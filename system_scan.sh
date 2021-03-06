#!/bin/bash

####################################################
###
### Copyright (2020, ) Gemini.Chen
###
### Author: gemini_chen@163.com
### Date  : 2020/07/14
### Scene : KSNS
###
######################################################
hostname_out=""
database_out=""
software_out=""
appuser_out=""


function get_hostname
{
	hostname_out=$(hostname)
	echo "hostname: $hostname_out"
}

function get_appuser
{
	# uid > 200
	user_list=$(awk -F: '$3>=200 {print $1}' /etc/passwd)
	for index in $user_list
	do
		appuser_out=$appuser_out$index", "
	done
	user_lenght=$(echo ${#appuser_out})
	# redhat need enhance
	user_end=$(echo "$user_lenght-2"|bc)
	appuser_info=${appuser_out:0: $user_end}
	echo "appuser: $appuser_info"
}


function get_database_version
{
	oracle_out=""
	db2_out=""
	mysql_out=""

	# oracle
	ps -ef |grep smon | grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then 
		oracle_version=$(su oracle -c 'sqlplus -v' |awk '{print $3}')
		oracle_out="Oracle $oracle_version ,"
	fi

	# db2
	ps -ef |grep db2sysc|grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then
		db2_version=$(su ksdbinst -c 'db2level')
		db2_out="DB2 $db2_version ,"
	fi

	# mysql
	netstat -ano |grep 3306 >/dev/null
	if [[ $? -eq 0 ]];then
		mysql_version=$(mysql -V | awk {'print $3'})
		mysql_out="MySQL ${mysql_version%?}"
	fi

	echo "database: $oracle_out $db2_out $mysql_out"
}

function get_software_version
{
	redis_out=""
	tomcat_out=""
	was_out=""
	nginx_out=""
	mq_out=""
	cics_out=""
	java_out=""
	# redis
	netstat -ano |grep 6379 &> /dev/null
	if [[ $? -eq 0 ]];then
		redis_version=$(redis-server -v|awk '{print$3}')
		redis_out="Redis $redis_version, "
	fi

	# tomcat
	ps -ef|grep tomcat| grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then
		#
		tomcat_path=$(dirname $(find / -name startup.sh| grep tomcat))
		tomcat_version=$(sh $tomcat_path/version.sh | grep 'Server number' | awk -F ": " {'print $2'})
		tomcat_out="Tomcat $tomcat_version, "
	fi	

	# was
	ps -ef |grep was| grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then 
		was_version=$(/opt/IBM/WebSphere/AppServer/bin/versionInfo.sh)
		was_out="WAS $was_version, "
	fi

	# nginx
	ps -ef|grep nginx| grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then
                #
		nginx_version=$(nginx -v 2>&1 | awk -F"/" '{print $2}')
		nginx_out="Nginx $nginx_version, "
        fi

	# mq
	ps -ef|grep MQ| grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then
                #
		mq_version=$(dspmqver)
		mq_out="MQ $mq_version, "
        fi

	# cics
	ps -ef|grep cics| grep -v grep &> /dev/null
	if [[ $? -eq 0 ]];then
                #
		cics_version=$(cicscp -v version)
		cics_out="CICS $cics_version, "
        fi

	# java
	java -version &> /dev/null
	if [[ $? -eq 0 ]];then
                java_version=$(java -version 2>&1 |awk 'NR==1{ gsub(/"/,""); print $3 }')
		java_out="Java $java_version"
        fi

	echo "software: $redis_out$tomcat_out$was_out$nginx_out$mq_out$cics_out$java_out"
}


function __main__
{
	get_hostname
	get_appuser
	get_database_version
	get_software_version
}

__main__
