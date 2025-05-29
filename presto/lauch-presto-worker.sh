#!/bin/bash
MASTER="10.16.17.78"

action=$1
node_ip_path=$2
shift
shift
if [[ $action != "start" && $action != "stop" && $action != "status" ]]; then
    echo "ERROR! Wrong arguments. Example: $0 [start|stop|status] [node_ip_path]..."
    exit 1
fi

if [ -z "$node_ip_path" ]; then
    echo "请指定要部署的节点ip文件路径,文件内容格式:每行一个ip"
    echo "ERROR! Wrong arguments. Example: $0 [start|stop|status] [node_ip_path]..."
    exit 1
fi

#user=`whoami`
#if [[ $user == root ]]; then
#	cmd="su - omm -c '$cmd'"
#elif [[  $user != omm ]]; then
#	echo "ERROR! only root/omm can execute"
#	exit 2
#fi

# start coordinator
# ssh $MASTER $cmd

# start worker
for ip in $(cat $node_ip_path); do
    echo "【$ip】"
    for ((instance = 0; instance < 4; instance++)); do
        echo "$ip instance_$instance execute $action..."
        if [[ $action == "start" ]]; then
            ssh $ip "/www/presto_$instance/bin/launcher $action -Dwork_seq=$instance --server-log-file /var/log/Bigdata/presto/worker$instance/server.log"
        else
            ssh $ip "/www/presto_$instance/bin/launcher $action"
        fi
        echo "$ip instance_$instance execute success..."
    done
done
