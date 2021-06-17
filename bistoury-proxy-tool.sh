backup_base_dir="/www/bistoury-update"
base_dir="/www"
server_home="bistoury-proxy-bin"
full_server_path=${base_dir}/${server_home}
jar_name="bistoury-proxy-bin.tar.gz"

stop_server() {
    #停止服务
    echo "--------------执行关闭服务操作"
    sh ${full_server_path}/bin/bistoury-proxy.sh stop
    if [ $? -ne 0 ]; then
        echo "停止bistoury proxy服务失败"
    else
        echo "停止bistoury proxy服务成功"
    fi
}

start_server() {
    echo "--------------执行启动服务操作"
    sh ${full_server_path}/bin/bistoury-proxy.sh start prod
}

backup() {
    #备份旧的目录
    echo "--------------执行备份目录操作"
    backup_server_home=$1
    backup_dir=$backup_base_dir/${backup_server_home}-backup
    if [ -d $backup_dir ]; then
        echo "发现旧的备份目录 ${backup_dir},执行删除操作"
        rm -rf $backup_dir
    fi
    mv ${full_server_path} $backup_dir
}

update_server() {
    echo "----------------begin to get archive:"
    if [ ! -d ${backup_base_dir} ]; then
        mkdir ${backup_base_dir}
    fi
    rm -rf ${backup_base_dir}/${jar_name}
    rsync -av --progress bigdata@10.16.16.235::hw_data_dev_upload/${jar_name} ${backup_base_dir}
    if [ $? -ne 0 ]; then
        echo "rsync archive fail."
        exit 1
    fi

    #如果有旧的目录则需要中断
    if [ -d ${full_server_path} ]; then
        stop_server
        backup ${server_home}
    else
        echo "未发现旧的安装目录，直接解压然后启动服务"
    fi

    mkdir ${full_server_path}
    tar xvf ${backup_base_dir}/${jar_name} -C ${full_server_path}
    if [ $? -ne 0 ]; then
        echo "tar archive fail.exit"
        exit 1
    fi

    #移动logs目录回来
    if [ -d $backup_base_dir/${server_home}-backup/logs ]; then
        mv $backup_base_dir/${server_home}-backup/logs ${full_server_path}
    fi
    #启动服务
    start_server
}

rollback_command() {
    backup_dir=$backup_base_dir/$server_home-backup
    echo "--------------执行备份目录回滚：$backup_dir"
    if [ ! -d $backup_dir ]; then
        echo "${backup_dir} 备份目录不存在"
        exit 1
    fi

    #停止在运行的hunter服务
    stop_server
    #移动log目录
    mv ${base_dir}/${server_home}/logs $backup_dir
    rm -rf ${base_dir}/${server_home}
    mv $backup_dir ${base_dir}/${server_home}
    #启动新的服务
    start_server
}

command=$1

case $command in
update)
    update_server
    ;;
rollback)
    rollback_command
    ;;
stopServer)
    stop_server
    ;;
startServer)
    start_server
    ;;
*)
    echo "$0:usage: update | rollback | stopServer | startServer"
    exit 1
    ;;
esac
