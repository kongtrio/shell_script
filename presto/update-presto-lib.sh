#!/bin/bash
node_ip_path=$1
if [ -z "$node_ip_path" ]; then
  echo "请指定要部署的节点ip文件路径,文件内容格式:每行一个ip"
  echo "sh deploy.sh [node_ip_path]"
  exit 1
fi
HOME=$(dirname $0)
# 循环处理每个IP
for ip in $(cat $node_ip_path); do
  echo "【$ip】"

  # 创建目录&传输文件
  scp $HOME/mrs_presto_0.216_worker.tar.gz $ip:/www
  
   # 解压presto包并将jdk并移到指定目录下，更改权限
  echo "start to prepare presto dir"
  ssh $ip "rm -rf /www/mrs_presto_0.216;cd /www;tar zxf mrs_presto_0.216_worker.tar.gz;rm -f mrs_presto_0.216_worker.tar.gz"
done
