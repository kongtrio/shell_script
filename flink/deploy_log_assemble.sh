#!/bin/bash

# 检查是否传入IP参数
if [ $# -eq 0 ]; then
    echo "Usage: $0 <ip1> <ip2> ..."
    exit 1
fi

# 部署配置
TAR_FILE="hunter-log-assemble.tar.gz"
PACKAGE_PATH="/root/log-assemble/${TAR_FILE}"
REMOTE_DIR="/www"
AGENT_DIR="$REMOTE_DIR/hunter-log-assemble"

# 遍历所有IP
for ip in "$@"; do
    echo "====================Processing IP: $ip===================="

    # 传输安装包
    scp $PACKAGE_PATH root@$ip:$REMOTE_DIR/

    # SSH执行解压
    ssh root@$ip "
        cd ${REMOTE_DIR}
        [ -d ${AGENT_DIR} ] && ${AGENT_DIR}/bin/stop.sh && echo 'stop old process success'
        rm -rf  ${AGENT_DIR} && echo 'rm old directory success'
        tar xf ${REMOTE_DIR}/${TAR_FILE}  && echo 'tar file success'
        ${AGENT_DIR}/bin/start.sh
    "
    echo "====================Deployment completed for $ip===================="
done

echo "All deployments finished."
