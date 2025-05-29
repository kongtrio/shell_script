#!/bin/sh

#本脚本用于操作presto服务的Coordinator服务

#并行度设置
CONCURRENCY=5

printHelp() {
    echo 'usage:sh restart-presto.sh ip [sleep_time:0s]'
}

restart() {
    ip=$1
    if [ -z "$ip" ]; then
        echo "ERROR!please input presto node ip"
        printHelp
        exit 1
    fi
    sleep_time=$2
    if [ -z "$sleep_time" ]; then
        sleep_time="0"
    fi

    echo "deal ip:$ip"
    echo "begin stop presto process"
    ssh -i ~/.ssh/only-bigdata-cluster.pem root@$ip "/www/presto-server-0.216/bin/launcher stop"
    # 判断是否停止成功
    if [ $? -ne 0 ]; then
        echo "ERROR!stop presto process failed"
        exit 1
    fi

    echo "begin start coordiantor"
    ssh -i ~/.ssh/only-bigdata-cluster.pem root@$ip "/www/presto-server-0.216/bin/launcher start"
    if [ $? -ne 0 ]; then
        echo "ERROR!start presto process failed"
        exit 1
    fi

    #检查是不是Coordinator节点
    is_coordinator=`grep -rF "$ip" ./coordinator.ip`
    if [ -z "$is_coordinator" ]; then
        echo "$ip is coordinator node,begin to restart keepalived"
        service keepalived restart
    fi
}

restart $@