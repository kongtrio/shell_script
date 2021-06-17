#!/bin/sh

#本脚本提供批量ssh命令执行以及scp功能
#ssh 和 scp 命令执行时都是串行执行的
#sshv2和scpv2则是多线程模式，CONCURRENCY为并行度设置
#如果目标host没有免密要登陆，只能使用ssh和scp命令。因为需要输入密码，因此多线程模式执行的话会有问题

#并行度设置
CONCURRENCY=5

printHelp() {
    echo 'usage:sh remote_tool.sh [ssh | scp | sshv2 | scpv2] $targetHostFilePath [$command | $sourceFile] [$targetPath]'
    echo 'demo: sh remote_tool.sh ssh /tmp/hosts "echo hello"'
    echo 'demo: sh remote_tool.sh scp /tmp/hosts /tmp/test.txt /tmp'
}

checkHostFile() {
    targetHostFilePath=$1
    if [ -z "$targetHostFilePath" ]; then
        echo "please input target host file path:one host per row"
        printHelp
        exit 1
    fi

    if [ ! -f $targetHostFilePath ]; then
        echo "$targetHostFilePath doesn't exist"
        exit 1
    fi
}

parrallSshCommand() {
    checkHostFile $1
    targetHostFilePath=$1
    shift
    command=$@
    if [ -z "$command" ]; then
        echo "please input ssh command"
        exit 1
    fi

    echo "-------------------begin exec command:${command}-------------------"

    array[0]=0
    running=0
    for ip in $(cat ${targetHostFilePath}); do
        ssh root@$ip "${command}" &
        running=$(($running + 1))
        array[$running]=$ip
        if [[ $running -eq $CONCURRENCY ]]; then
            for ((j = 1; j <= $running; j++)); do
                wait "%$j"
                js=$?
                if [ $js -ne 0 ]; then
                    echo -e "\t[${array[j]}] FAILED"
                else
                    echo -e "\t[${array[j]}] SUCCESSED"
                fi

            done
            running=0
        fi
    done

    for ((j = 1; j <= $running; j++)); do
        wait "%$j"
        js=$?
        if [ $js -ne 0 ]; then
            echo -e "\t[${array[j]}] FAILED"
        else
            echo -e "\t[${array[j]}] SUCCESSED"
        fi
    done
    echo "-------------------exec command finish-------------------"
}

sshCommand() {
    checkHostFile $1
    targetHostFilePath=$1
    shift
    command=$@
    if [ -z "$command" ]; then
        echo "please input ssh command"
        exit 1
    fi

    echo "-------------------begin exec command:${command}-------------------"
    for ip in $(cat ${targetHostFilePath}); do
        ssh root@$ip "${command}"
        if [ $? -ne 0 ]; then
            echo -e "\t[${ip}] FAILED"
        else
            echo -e "\t[${ip}] SUCCESSED"
        fi
    done
    echo "-------------------exec command finish-------------------"
}

parrallScpCommand() {
    checkHostFile $1
    targetHostFilePath=$1
    sourceFile=$2
    targetPath=$3

    if [ -z "$sourceFile" ]; then
        echo "please input source file path"
        exit 1
    fi

    if [ ! -f $sourceFile ]; then
        echo "$sourceFile doesn't exist"
        exit 1
    fi

    if [ -z "$targetPath" ]; then
        echo "please input target path"
        exit 1
    fi

    echo "-------------------begin copy file ${sourceFile} to ${targetPath}-------------------"

    array[0]=0
    running=0
    for ip in $(cat ${targetHostFilePath}); do
        scp $sourceFile root@$ip:${targetPath} &
        running=$(($running + 1))
        array[$running]=$ip
        if [[ $running -eq $CONCURRENCY ]]; then
            for ((j = 1; j <= $running; j++)); do
                wait "%$j"
                js=$?
                if [ $js -ne 0 ]; then
                    echo -e "\t[${array[j]}] FAILED"
                else
                    echo -e "\t[${array[j]}] SUCCESSED"
                fi

            done
            running=0
        fi
    done

    for ((j = 1; j <= $running; j++)); do
        wait "%$j"
        js=$?
        if [ $js -ne 0 ]; then
            echo -e "\t[${array[j]}] FAILED"
        else
            echo -e "\t[${array[j]}] SUCCESSED"
        fi
    done
    echo "-------------------copy file finish-------------------"
}

scpCommand() {
    checkHostFile $1
    targetHostFilePath=$1
    sourceFile=$2
    targetPath=$3

    if [ -z "$sourceFile" ]; then
        echo "please input source file path"
        exit 1
    fi

    if [ ! -f $sourceFile ]; then
        echo "$sourceFile doesn't exist"
        exit 1
    fi

    if [ -z "$targetPath" ]; then
        echo "please input target path"
        exit 1
    fi

    echo "-------------------begin copy file ${sourceFile} to ${targetPath}-------------------"
    for ip in $(cat ${targetHostFilePath}); do
        scp $sourceFile root@$ip:${targetPath}
        if [ $? -ne 0 ]; then
            echo -e "\t[${ip}] FAILED"
        else
            echo -e "\t[${ip}] SUCCESSED"
        fi
    done
    echo "-------------------copy file finish-------------------"
}

command=$1
shift
case $command in
ssh)
    sshCommand $@
    ;;
sshv2)
    parrallSshCommand $@
    ;;
scp)
    scpCommand $@
    ;;
scpv2)
    parrallScpCommand $@
    ;;
*)
    printHelp
    exit 1
    ;;
esac
