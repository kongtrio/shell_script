#!/bin/bash

prg_dir=$(dirname $0)
cd $prg_dir >/dev/null 2>&1

# 告警
function notify() {
    curl http://notice.data.m.com/notice-center/message/weixin -d "subject=【Presto集群进程GC告警】%0a&clientId=infra:cluster:monitor:pah&receiver=yjb1@meitu.com&flag=4&content=时间范围: [$1]%0a$2"
}

# 常量
INTERVAL='5m'
GC_THRESHOLD_SEC=0.000001
STALL_THRESHOLD_MILLIS=5
PARALLEL=20

worker_list=(worker1 worker2 worker3 worker0 worker_reverse0 worker_reverse1 worker_reverse2 worker_reverse3)
root="/var/log/Bigdata/presto/"

ltime=()

function fetch_time_range() {
    index=$1
    ip=$2
    path=$3

    st=${ltime[$index]:-$(date +'%Y-%m-%dT%H:%M:%S')}
    et=$(ssh $ip "ls -t $path | grep 'gc' | head -1 | xargs -I {} tail -1 $path/{} | cut -d '[' -f 2 | cut -d '+' -f 1")
    if [[ -z $et ]]; then
        return 1
    fi
    ltime[$index]=$et
    if [[ $st == $et ]]; then
        return 2
    else
        return 0
    fi
}

function detect() {
    ip=$1
    id=$2
    path=$3
    st=$4
    et=$5

    gc_stop=$(ssh $ip "ls -t $path | grep 'gc' | head -1 | xargs -I {} sed -n \"/$st/,/$et/p\" $path/{} | grep 'Total time for which application threads were stopped' | cut -d ':' -f4 | cut -d 's' -f1 | sort -nr | head -1")
    gc_stall_info=$(ssh $ip "ls -t $path | grep 'gc' | head -1 | xargs -I {} sed -n \"/$st/,/$et/p\" $path/{} | grep 'Allocation Stall (' | cut -d 'l' -f5| head | sort -t ')' -k2 -nr | head -1")

    echo "$ip-$id-[$st, $et]-$gc_stop"
    echo "$ip-$id-[$st, $et]-$gc_stall_info"

    if [[ ! -z $gc_stop ]] && (($(echo "$gc_stop >= $GC_THRESHOLD_SEC" | bc) == 1)); then
        notify "$st, $et" "$id 出现长停顿，最长停顿时间: ${gc_stop}s"
    fi
    if [[ ! -z $gc_stall_info ]]; then
        gc_stall_time=$(echo $gc_stall_info | cut -d ')' -f2 | cut -d 'm' -f1)
        if (($(echo "$gc_stall_time >= $STALL_THRESHOLD_MILLIS" | bc) == 1)); then
            notify "$st, $et" "$id 出现线程停顿，最长停顿：%0a${gc_stall_info}"
        fi
    fi
}

function check_coordinator_alive() {
    ip=$1

    coordinator_alive_number=$(ssh $ip "ps -ef | grep Coordinator | grep -v grep | wc -l")

    if [[ $coordinator_alive_number -eq 0 ]]; then
        notify "Coordinator($ip) 进程挂了" "Coordinator($ip) 进程挂了"
    fi

    keepalive_number=$(ssh $ip "ps -ef | grep keepalive | grep -v grep | wc -l")
    if [[ $keepalive_number -eq 0 ]]; then
        notify "$ip keepalive 进程挂了" "$ip keepalive 进程挂了"
    fi
}

while [[ '2' -gt '1' ]]; do
    i=0

    running_nums=0
    # coordinator
    for ip in $(cat coordinator.ip); do
        echo $ip
        path=$root/

        if fetch_time_range $i $ip $path; then
            check_coordinator_alive $ip
            ((running_nums += 1))
            detect $ip "Coordinator($ip)" $path $st $et &
        fi
        ((i += 1))

    done

    # worker
    if [ -f worker.ip ]; then
        for ip in $(cat worker.ip); do
            for w in ${worker_list[@]}; do
                echo "$ip-$w"

                path=$root/$w

                if (($running_nums >= $PARALLEL)); then
                    echo "等待上一批结束"
                    wait
                    running_nums=0
                fi

                if fetch_time_range $i $ip $path; then
                    ((running_nums += 1))
                    detect $ip "$ip-$w" $path $st $et &
                fi
                ((i += 1))

            done
        done
    else
        echo "worker.ip not exist"
    fi

    wait
    echo "一轮结束"
    sleep ${INTERVAL:-'15s'}
done
