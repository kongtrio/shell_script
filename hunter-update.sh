backup_base_dir=/srv/BigData/hunter-update
server_home="hunter-server"
jar_name="$server_home.tar.gz"

stop_server() {
    #停止服务
    echo "stop hunter server"
    /www/${server_home}/bin/stop.sh
    if [ $? -ne 0 ]; then
        echo "停止hunter服务失败"
        exit 1
    fi
}

backup() {
    #备份旧的目录
    echo "backup old directory"
    now_date=$(date +"%y%m%d%H%M")
    backup_dir=$backup_base_dir/$server_home-backup
    if [ -d $backup_dir ]; then
        mv $backup_dir $backup_dir-$now_date
    fi
    mv /www/${server_home} $backup_dir
}

install() {
    echo "----------------begin to get archive:"
    rm -rf ${backup_base_dir}/${jar_name}
    rsync -av --progress bigdata@10.16.16.235::hw_data_dev_upload/${jar_name} ${backup_base_dir}
    if [ $? -ne 0 ]; then
        echo "rsync archive fail."
        exit 1
    fi

    #如果有旧的目录则需要中断并更新
    if [ -d /www/${server_home} ]; then
        stop_server
        backup
    else
        echo "未发现旧的安装目录"
    fi

    tar xvf ${backup_base_dir}/${jar_name} -C /www
    if [ $? -ne 0 ]; then
        echo "tar archive fail.exit"
        exit 1
    fi

    #移动logs目录回来
    if [ -d $backup_base_dir/$server_home-backup/logs ]; then
        mv $backup_base_dir/$server_home-backup/logs /www/${server_home}
    fi
    #启动服务
    sh /www/${server_home}/bin/start.sh
}

rollback() {
    rollback_date=$1
    backup_dir=$backup_base_dir/$server_home-backup
    if [ ! -z "$rollback_date" ]; then
        backup_dir=$backup_base_dir/$server_home-backup
    fi
    echo "--------------执行备份目录回滚：$backup_dir"
    if [ ! -f $backup_dir ]; then
        echo "该备份目录不存在"
        exit 1
    fi

    #停止在运行的hunter服务
    stop_server
    #移动log目录
    mv /www/${server_home}/logs $backup_dir
    rm -rf /www/${server_home}
    mv $backup_dir /www/${server_home}
    #启动新的服务
    /www/${server_home}/bin/start.sh
}

command=$1

case $command in
install)
    install
    ;;
rollback)
    rollback $2
    ;;
*)
    echo "$0:usage: install | rollback [date]"
    exit 1
    ;;
esac
