#!/bin/bash

function grepLog() {
    host=$1
    appId=$2
    filterKey=$3
    containerlogsPath1=/srv/BigData/hadoop/data1/nm/containerlogs/${appId}
    containerlogsList=$(ssh $host "ls ${containerlogsPath1}")
    for readLogPath in ${containerlogsList}; do
        #echo "ssh ${host} \"grep -rF '${filterKey}' ${containerlogsPath1}/${readLogPath}\""
        result=$(ssh ${host} "grep -rF '${filterKey}' ${containerlogsPath1}/${readLogPath}")
        if [ ! -z "${result}" ]; then
            echo ”“$result
        fi
    done

    containerlogsPath2=/srv/BigData/hadoop/data2/nm/containerlogs/${appId}
    containerlogsList=$(ssh $host "ls ${containerlogsPath2}")
    for readLogPath in ${containerlogsList}; do
        result=$(ssh ${host} "grep -rF '${filterKey}' ${containerlogsPath2}/${readLogPath}")
        if [ ! -z "${result}" ]; then
            echo $result
        fi
    done
}

hostListFile=$1
appId=$2
filterKey=$3
if [ -z "$hostListFile" ]; then
    echo "请输入host文件"
    echo "入参：host文件路径 appId 过滤Key"
    exit 0
fi

hostList=$(cat $hostListFile)
if [ $?!=0 ]; then
    echo "${hostListFile}文件不存在"
    exit 0
fi

if [ -z "$appId" ]; then
    echo "请输入appId"
    echo "入参：host文件路径 appId 过滤Key"
    exit 0
fi

if [ -z "$filterKey" ]; then
    echo "请输入过滤的key"
    echo "入参：host文件路径 appId 过滤Key"
    exit 0
fi

for host in ${hostList}; do
    grepLog $host $appId $filterKey
done
