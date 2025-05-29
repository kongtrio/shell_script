backup_base_dir=/www
server_home="dist"
jar_name="dist.tar.gz"

backup() {
    #备份旧的目录
    echo "backup old directory"
    now_date=$(date +"%y%m%d%H%M")
    backup_dir=$backup_base_dir/$server_home-backup
    if [ -d $backup_dir ]; then
        mv $backup_dir $backup_dir-$now_date
    fi
    mv /usr/share/nginx/aigc $backup_dir
}

install() {
    if [ ! -f /www/${jar_name} ]; then
        echo "/www/${jar_name} not exist"
        exit 1
    fi
    echo "delete old dist dir"
    $(rm -rf /www/dist)
    echo "unzip dist.tar.gz"
    tar xvf /www/dist.tar.gz -C /www
    if [ $? -ne 0 ]; then
        echo "unzip fail.exit"
        exit 1
    fi

    #启动服务
    backup
    $(mv /www/dist /usr/share/nginx/aigc)
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

    #移动log目录
    rm -rf /usr/share/nginx/aigc
    mv $backup_dir /usr/share/nginx/aigc
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
