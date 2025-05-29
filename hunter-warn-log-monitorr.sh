#!/bin/bash
# 该脚本主要用于每天监控一次hunter日志，发现有warning日志则告警
# 日志存放目录
log_path=/www/hunter-server-test/logs
# 获取昨天的时间，主要用于读取昨天的压缩日志
now_date=$(date -d "-1 days" +"%Y-%m-%d")
# 昨天的日志文件路径
yeaterday_file_path=${log_path}/server.${now_date}.log.gz
# 告警发送邮箱的接受者
alarm_reciever=yjb1@meitu.com
# 告警邮件中的服务名
service_name="hunter-prod"

check_error() {
    warn_count=$(zcat ${yeaterday_file_path}  | grep "WARN" | wc -l);
    if [ $warn_count -gt 0 ]; then
        echo 'hunter warn log find ${warn_count}'
        subject="${service_name}昨天发现有warn日志"
        content="发现warn日志${warn_count}条,详情请查看日志"
        send_alarm $subject $content
    fi
}

send_alarm() {
    subject=$1
    content=$2
    curl http://notice.ops.m.com/send_wx -d "receiver=${alarm_reciever}&subject=${subject}&content=${content}"
}

check_error
