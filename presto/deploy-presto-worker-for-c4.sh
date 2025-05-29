#!/bin/bash
#检查入参是否大于1
if [ $# -lt 1 ]; then
  echo "ERROR! Wrong arguments. Example: $0 <ip list>..."
  exit 1
fi
HOME=$(dirname $0)
# 循环处理每个IP
for ip in "$@"; do
  echo "【$ip】"

  # 创建目录&传输文件
  ssh $ip "if [[ ! -d /www ]]; then mkdir -p /www && chmod 755 /www; fi"
  presto_jar_name='mrs_presto_0.216_worker.tar.gz'
  # 不存在则退出
  if [ ! -f $HOME/${presto_jar_name} ]; then
    echo "presto jar not exist,exit"
    exit 1
  fi
  # 复制presto包
  if ssh $ip "[ -e /www/${presto_jar_name} ]"; then
    echo "${presto_jar_name} exist,skip it"
  else
    scp $HOME/${presto_jar_name} $ip:/www
  fi

  # 复制jdk包
  jdk_jar_name='zing23.05.0.0-2-jdk11.0.19-linux_aarch64.tar.gz'
  if [ ! -f $HOME/${jdk_jar_name} ]; then
    echo "jdk jar not exist,exit"
    exit 1
  fi
  if ssh $ip "[ -e /www/${jdk_jar_name} ]"; then
    echo "${jdk_jar_name} exist,skip it"
  else
    scp $HOME/${jdk_jar_name} $ip:/www
  fi

  # 解压presto包并将jdk并移到指定目录下，更改权限
  echo "start to prepare presto dir and jdk env"
  ssh $ip "cd /www;tar zxf ${presto_jar_name};tar zxf ${jdk_jar_name} ;"

  # 复制core-site.xml和hdfs-site.xml到指定目录
  echo "start to copy core-site.xml and hdfs-site.xml"
  ssh $ip "if [[ ! -d /srv/BigData/hadoop/data1/Bigdata/presto/etc ]]; then mkdir -p /srv/BigData/hadoop/data1/Bigdata/presto/etc/;cp /www/mrs_presto_0.216/etc/core-site.xml /srv/BigData/hadoop/data1/Bigdata/presto/etc/;cp /www/mrs_presto_0.216/etc/hdfs-site.xml /srv/BigData/hadoop/data1/Bigdata/presto/etc/;chown -R omm:wheel /srv/BigData/hadoop/data1/Bigdata/presto; else echo 'hive hadoop conf dir exist';fi"

  # 部署多个实例
  for ((instance = 0; instance < 4; instance++)); do
    echo " Deploying $ip instance_$instance..."
    instance_name="c4_presto_$instance"
    instance_log_dir_name="c4_worker$instance"
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

    # 修改jvm.config配置文件，对应logs目录数量也要改成instance对应数量
    ssh $ip "sed -i 's|/var/log/Bigdata/presto/logs|/var/log/Bigdata/presto/${instance_log_dir_name}|g' /www/${instance_name}/etc/jvm.config"

    ssh $ip "sed -i 's|/opt/Bigdata/jdk-11.0.8-v2|/www/zing23.05.0.0-2-jdk11.0.19-linux_aarch64|g' /www/${instance_name}/etc/ENV_VARS"
    ssh $ip "sed -i 's|/opt/Bigdata/jdk-11.0.8-v2|/www/zing23.05.0.0-2-jdk11.0.19-linux_aarch64|g' /www/${instance_name}/bin/launcher"

    # 目录权限改为omm:ficommon
    ssh $ip "chown -R omm:ficommon /www/${instance_name}"
    echo " Deployment of $ip instance_$instance completed."
  done
done

if [ -f tmp.properties ]; then rm tmp.properties; fi
