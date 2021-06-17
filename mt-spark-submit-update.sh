#!/bin/sh
BASE_DIR=/www/mt-spark-submit
BACKUP_DIR=/www/mt-spark-submit-backup
COMMAND_PATH=/usr/bin/datawork-client
waitProcessEnd() {
    process_name=$1
    if [ -z "$process_name" ]; then
        echo "请输入进程名"
        return 0
    fi
    echo "等待 $process_name 执行结束"
    running_count=$(ps -ef | grep $process_name | grep -v grep | wc -l)
    while [ $running_count -gt 1 ]; do
        echo "$process_name 在运行中,继续等待(休眠10s)..."
        sleep 10
        running_count=$(ps aux | grep $process_name | grep -v grep | wc -l)
    done
    echo "$process_name 全部运行结束"
}

uninstall() {
    sh ${BASE_DIR}/sbin/uninstall.sh
}

checkAndReplication() {
    if [ -d ${BASE_DIR} ]; then
        echo "发现旧的mt-spark-submit安装包,将执行备份卸载操作"
        $(rm -f ${COMMAND_PATH})
        echo "卸载完成"
        if [ -d ${BACKUP_DIR} ]; then
            today_time=$(date +"%Y%m%d%H%M")
            $(mv ${BACKUP_DIR} ${BACKUP_DIR}-${today_time})
        fi
        $(mv ${BASE_DIR} ${BACKUP_DIR})
        echo "备份完成"
    else
        echo "未发现旧的安装包，将直接执行安装流程."
    fi
}

install() {
    #rsync到/www目录下
    $(rm -rf /www/mt-spark-submit.tar.gz)
    echo "--------------开始拉取安装包:"
    rsync -av --progress bigdata@10.16.16.235::hw_bigdatabasics/mt-spark-submit.tar.gz /www
    if [ $? -ne 0 ]; then
        echo "拉取安装包失败,将退出安装."
        exit 1
    fi

    #等待所有datawork-client进程执行完成
    waitProcessEnd mt-spark-submit
    #备份旧目录并写在
    checkAndReplication
    #安装新的包
    if [ ! -f /www/mt-spark-submit.tar.gz ]; then
        echo "未发现mt-spark-submit.tar.gz安装包.退出安装"
        exit 1
    fi
    echo "--------------开始解压安装包:"
    tar xvf /www/mt-spark-submit.tar.gz -C /www
    echo "--------------执行安装脚本"
    sh /www/mt-spark-submit/sbin/install.sh
    echo "--------------安装完成"
}

rollback() {
    #等待所有datawork-client进程执行完成
    waitProcessEnd mt-spark-submit
    rollback_date=$1
    backup_dir=${BACKUP_DIR}
    if [ ! -z "$rollback_date" ]; then
        backup_dir=${BACKUP_DIR}-$rollback_date
    fi
    echo "--------------执行备份目录回滚：$backup_dir"
    if [ ! -d $backup_dir ]; then
        echo "该备份目录不存在"
        exit 1
    fi
    #卸载当前的目录
    uninstall
    mv $backup_dir ${BASE_DIR}
    sh ${BASE_DIR}/sbin/install.sh
}

checkUser() {
    if [ $(whoami) != "root" ]; then
        echo "请使用root用户操作此脚本"
        exit 1
    fi
}

#测试该服务器的java命令正常
checkJavaVersion() {
    echo "输出当前java版本:"
    $(java -version)
    if [ $? -ne 0 ]; then
        echo "未在该机器上找到java客户端!中断更新"
        exit 1
    fi
}

command=$1

case $command in
install)
    checkUser
    checkJavaVersion
    install
    ;;
rollback)
    checkUser
    rollback $2
    ;;
*)
    echo "$0:usage: install | rollback [date]"
    exit 1
    ;;
esac
