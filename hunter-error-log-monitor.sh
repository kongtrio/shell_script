#!/bin/bash
# 该脚本主要用于每个小时监控一次hunter日志，发现有错误日志则告警
# 日志存放目录
log_path=/www/hunter-server-test/logs
# 日志路径
log_file_path=${log_path}/server.log
# 获取昨天的时间，主要用于读取昨天的压缩日志
now_date=$(date -d "-1 days" +"%Y-%m-%d")
# 昨天的日志文件路径
yeaterday_file_path=${log_path}/server.${now_date}.log.gz
# 告警发送邮箱的接受者
alarm_reciever=yjb1@meitu.com
# 告警邮件中的服务名
service_name="hunter-prod"
# 匹配的规则串
error_match_pattern="ERROR"
# 要过滤的字符串
pass_log="hiveServer/kobeServer/prestoServer"

check_error() {
    now_hour=$(date +"%H")
    check_begin_time=$(date -d '-1 hour' +"%Y-%m-%d %H")
    check_end_time=$(date +"%Y-%m-%d %H")
    echo "check_begin_time:${check_begin_time}"
    echo "check_end_time:${check_end_time}"

    # cat /srv/BigData/hunter/logs/server.log | sed -n "/^2022-05-05 14/,/^2022-05-05 15/p" | egrep "ERROR" | grep -v "hiveServer/kobeServer/prestoServer" | wc -l
    if [ "${now_hour}" == "00" ];then
        error_count=$(zcat ${yeaterday_file_path} | sed -n "/^${check_begin_time}/,/^${check_end_time}/p" | egrep "${error_match_pattern}" | grep -v "${pass_log}" | wc -l)
    else
        error_count=$(cat ${log_file_path} | sed -n "/^${check_begin_time}/,/^${check_end_time}/p" | egrep "${error_match_pattern}" | grep -v "${pass_log}" | wc -l)
    fi
    echo "find error count is ${error_count}"

    if [ $error_count -gt 0 ]; then
        echo 'hunter error'
        subject="${service_name}近一个小时有错误日志"
        content="发现错误日志${error_count}条,请及时前往服务器查看详情"
        send_alarm $subject $content
    fi
}

send_alarm() {
    subject=$1
    content=$2
    curl http://notice.ops.m.com/send_wx -d "receiver=${alarm_reciever}&subject=${subject}&content=${content}"
}

check_error
