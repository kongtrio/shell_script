backup_base_dir=/www/bistoury-update
base_dir=/www
ui_server_home=bistoury-ui-bin
ui_jar_name="bistoury-ui-bin.tar.gz"

stop_bistoury_ui() {
    #停止服务
    echo "stop bistoury_ui"
    sh /www/bistoury-ui-bin/bin/bistoury-ui.sh stop
    if [ $? -ne 0 ]; then
        echo "停止bistoury服务失败"
    fi
}

start_bistoury_ui() {
    sh ${base_dir}/${ui_server_home}/bin/bistoury-ui.sh start prod
}

backup() {
    #备份旧的目录
    echo "backup old directory"
    backup_server_home=$1
    backup_dir=$backup_base_dir/${backup_server_home}-backup
    if [ -d $backup_dir ]; then
        rm -rf $backup_dir
    fi
    mv /www/${backup_server_home} $backup_dir
}

update_bistoury_ui() {
    echo "----------------begin to get archive:"
    if [ ! -d ${backup_base_dir} ]; then
        mkdir ${backup_base_dir}
    fi
    rm -rf ${backup_base_dir}/${ui_jar_name}
    rsync -av --progress bigdata@10.16.16.235::hw_data_dev_upload/${ui_jar_name} ${backup_base_dir}
    if [ $? -ne 0 ]; then
        echo "rsync archive fail."
        exit 1
    fi

    #如果有旧的目录则需要中断
    if [ -d ${base_dir}/${ui_server_home} ]; then
        stop_bistoury_ui
        backup ${ui_server_home}
    else
        echo "未发现旧的安装目录"
    fi

    mkdir ${base_dir}/${ui_server_home}
    tar xvf ${backup_base_dir}/${ui_jar_name} -C ${base_dir}/${ui_server_home}
    if [ $? -ne 0 ]; then
        echo "tar archive fail.exit"
        exit 1
    fi

    #移动logs目录回来
    if [ -d $backup_base_dir/${ui_server_home}-backup/logs ]; then
        mv $backup_base_dir/${ui_server_home}-backup/logs ${base_dir}/${ui_server_home}
    fi
    #启动服务
    start_bistoury_ui
}

rollbackCommand() {
    backup_dir=$backup_base_dir/$ui_server_home-backup
    echo "--------------执行备份目录回滚：$backup_dir"
    if [ ! -d $backup_dir ]; then
        echo "${backup_dir} 备份目录不存在"
        exit 1
    fi

    #停止在运行的hunter服务
    stop_bistoury_ui
    #移动log目录
    mv ${base_dir}/${ui_server_home}/logs $backup_dir
    rm -rf ${base_dir}/${ui_server_home}
    mv $backup_dir ${base_dir}/${ui_server_home}
    #启动新的服务
    start_bistoury_ui
}

command=$1

case $command in
update)
    update_bistoury_ui
    ;;
rollback)
    rollbackCommand
    ;;
*)
    echo "$0:usage: update | rollback"
    exit 1
    ;;
esac
