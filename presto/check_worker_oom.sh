#!/bin/bash
alert_users="czw1@meitu.com,yjb1@meitu.com,pd1@meitu.com,yq2@meitu.com,wjl2@meitu.com"

# 获取当前时间的上一分钟时间
get_previous_minute() {
    date -d '1 minute ago' +"%Y-%m-%dT%H:%M"
}
previous_minute=$(get_previous_minute)

# 检查日志并输出告警
for now_worker in worker0 worker1 worker2 worker3 worker_reverse0 worker_reverse1 worker_reverse2 worker_reverse3; do
    real_worker=${now_worker}
    log_file="/var/log/Bigdata/presto/${now_worker}/server.log"
    # 如果文件不存在，跳过
    if [[ ! -f "${log_file}" ]]; then
        continue
    fi
    logs=$(grep -B 5 "OutOfMemoryError" "${log_file}" | grep "$previous_minute")
    if [[ -n "${logs}" ]]; then
        ip=$(hostname -I | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        curl http://notice.ops.m.com/send_wx -d "receiver=${alert_users}&subject=离线集群presto worker oom监控告警&content=${ip} ${real_worker} $previous_minute出现oom, 请查看原因并重启worker"
        echo "警告：${ip} ${real_worker} $previous_minute - 日志中出现了OutOfMemoryError！"
        echo "$logs"
    # else
    #     echo "$previous_minute - 没有出现OutOfMemoryError。"
    fi
done
