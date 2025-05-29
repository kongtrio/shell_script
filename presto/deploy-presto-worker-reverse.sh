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
  ssh $ip "if [[ ! -d /www ]]; then mkdir -p /www && chmod 755 /www; fi"
  scp $HOME/mrs_presto_0.216_worker.tar.gz $ip:/www
  scp $HOME/presto_jdk.tar.gz $ip:/www

  # 解压presto包并将jdk并移到指定目录下，更改权限
  echo "start to prepare presto dir and jdk env"
  ssh $ip "cd /www;tar zxf mrs_presto_0.216_worker.tar.gz;tar zxf presto_jdk.tar.gz ; mv -n jdk-11.0.8-v2 /opt/Bigdata/ ; chown -R omm:ficommon /opt/Bigdata/jdk-11.0.8-v2 ; rm -f mrs_presto_0.216_worker.tar.gz; rm -f presto_jdk.tar.gz"

  # 复制core-site.xml和hdfs-site.xml到指定目录
  echo "start to copy core-site.xml and hdfs-site.xml"
  ssh $ip "if [[ ! -d /srv/BigData/hadoop/data1/Bigdata/presto/etc ]]; then mkdir -p /srv/BigData/hadoop/data1/Bigdata/presto/etc/;cp /www/mrs_presto_0.216/etc/core-site.xml /srv/BigData/hadoop/data1/Bigdata/presto/etc/;cp /www/mrs_presto_0.216/etc/hdfs-site.xml /srv/BigData/hadoop/data1/Bigdata/presto/etc/;chown -R omm:wheel /srv/BigData/hadoop/data1/Bigdata/presto; else echo 'hive hadoop conf dir exist';fi"

  # 部署多个实例
  for ((instance = 0; instance < 4; instance++)); do
    echo " Deploying $ip instance_$instance..."
    instance_name="presto_reverse_$instance"
    instance_log_dir_name="worker_reverse$instance"
    # 将presto拷贝到/www/presto_$instance并创建对应日志目录
    if_exist=$(ssh $ip "if [[ ! -d /www/${instance_name} ]]; then mkdir -p /www/${instance_name} && chmod 755 /www; else echo 'dir exists';fi")
    if [ "$if_exist" = "dir exists" ]; then
      echo "/www/${instance_name} exist,skip it"
      continue
    fi

    ssh $ip "cp -r /www/mrs_presto_0.216/etc/ /www/${instance_name}/;cp -r /www/mrs_presto_0.216/bin/ /www/${instance_name}/;ln -s /www/mrs_presto_0.216/lib/ /www/${instance_name}/;ln -s /www/mrs_presto_0.216/plugin/ /www/${instance_name}/;ln -s /www/mrs_presto_0.216/udf/ /www/${instance_name}/;ln -s /www/mrs_presto_0.216/checker/ /www/${instance_name}/;ln -s /www/mrs_presto_0.216/version.properties /www/${instance_name}/;mkdir -p /var/log/Bigdata/presto/${instance_log_dir_name}; chown -R omm:ficommon /var/log/Bigdata/presto/${instance_log_dir_name}"

    cat >tmp.properties <<EOF
    node.id = $(echo "Worker-$ip-$instance" | sed 's/\./-/g')
    node.data-dir = /srv/BigData/hadoop/data1/Bigdata/${instance_name}
    node.bind-ip = $ip
    node.environment = mrs
EOF

    # 修改node.properties配置文件，ip唯一
    scp tmp.properties $ip:/www/${instance_name}/etc/node.properties

    # 修改config.properties配置文件，将http-server.http.port改成对应instance数量=》http-server.http.port = 1253$instance
    ssh $ip "sed -i \"s/^http-server.http.port = .*/http-server.http.port = 1253$instance/\" /www/${instance_name}/etc/config.properties"
    # 修改Coordinator的地址到presto集群，反向扩容presto集群的机器
    ssh $ip "sed -i \"s/10.16.17.58/10.16.19.219/\" /www/${instance_name}/etc/config.properties"

    # 修改jvm.config配置文件，对应logs目录数量也要改成instance对应数量
    ssh $ip "sed -i 's|/var/log/Bigdata/presto/logs|/var/log/Bigdata/presto/${instance_log_dir_name}|g' /www/${instance_name}/etc/jvm.config"

    # 目录权限改为omm:ficommon
    ssh $ip "chown -R omm:ficommon /www/${instance_name}"
    echo " Deployment of $ip instance_$instance completed."
  done
done

if [ -f tmp.properties ]; then rm tmp.properties; fi
