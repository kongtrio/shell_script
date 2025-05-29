#!/bin/bash
#检查入参是否大于1
if [ $# -lt 1 ]; then
    echo "ERROR! Wrong arguments. Example: $0 <ip list>..."
    exit 1
fi
# 检查机器下的presto反向扩容worker进程是否存在，如果不存在则启动
for ip in "$@"; do
    echo "【$ip】"
    for ((instance = 0; instance < 4; instance++)); do
        instance_name="presto_reverse_$instance"
        instance_log_dir_name="worker_reverse$instance"
        remote_pid=$(ssh ${ip} pgrep -f "$instance_name")

        if [ -z "$remote_pid" ]; then
            echo "$instance_name is not running on $ip. Starting it..."
            # Start the process on the remote server
            ssh $ip "/www/${instance_name}/bin/launcher start -Dwork_seq=$instance --server-log-file /var/log/Bigdata/presto/${instance_log_dir_name}/server.log"
        else
            echo "$instance_name is already running on $ip (PID: $remote_pid)."
        fi
    done
done
