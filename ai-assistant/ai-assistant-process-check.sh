#!/bin/bash
# 监控hunter进程
# 不执行下面的语句会导致ifconfig命令找不到
source ~/.bashrc

process_name="ai-assistant-api"
local_ip=`/sbin/ifconfig | grep inet | awk '{print $2}' | head -1`
alarm_reciever=yjb1@meitu.com,czw1@meitu.com

check_process(){
    process_count=`ps -ef | grep -v grep | grep ${process_name} | wc -l`
    if [ ${process_count} -eq 0 ];then
        echo "${process_name} process down"
        subject="${process_name}服务下线"
        content="${process_name}服务可能挂了，请前往服务器${local_ip}查看"
        send_alarm $subject $content
    elif [ ${process_count} -gt 1 ];then
        echo "${process_name} process number larger than 1"
        process_info=`ps -ef | grep -v grep | grep ${process_name}`
        echo "all process info is ${process_info}"
    else
        pid=`ps -ef | grep -v grep | grep ${process_name} | awk '{print $2}'`
        echo "${process_name} is running,pid is ${pid}"
    fi
}

send_alarm() {
    subject=$1
    content=$2
    curl http://notice.ops.m.com/send_wx -d "receiver=${alarm_reciever}&subject=${subject}&content=${content}"
}

check_process