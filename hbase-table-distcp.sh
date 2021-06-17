HBASE_BASE_PATH="/hbase/data"
targetHdfsAddress=$1
table=$2
namespace=$3

if [ -z "$targetHdfsAddress" ]; then
    echo "please input target hdfs address"
    echo 'usage:sh command $targetHdfsAddress $table [namespace]'
    echo 'demo: sh command 10.0.0.1:9820 yjbtest default'
    exit 1
fi

if [ -z "$table" ]; then
    echo "please input table name"
    echo 'usage:sh command $targetHdfsAddress $table [namespace]'
    echo 'demo: sh command 10.0.0.1:9820 yjbtest default'
    exit 1
fi

if [ -z "$namespace" ]; then
    namespace="default"
fi

echo "begin to copy table $table"

#.tabledesc和.tmp文件原先hbase目录就自带,其中.tmp是空目录
all_region=$(hadoop fs -ls ${HBASE_BASE_PATH}/${namespace}/${table} | grep -v tabledesc | grep -v tmp | awk '{print $8}')

echo "$all_region"
$(hadoop distcp -overwrite -m 1 hdfs://hacluster/hbase/data/default/$table/.tabledesc hdfs://10.16.19.48:9820/hbase/data/default/$table/.tabledesc)
echo "copy tabledesc success"

#分批传输region，防止region在传输过程中失败，后面捞出这些失败region特殊处理
for region in $all_region; do
    cmd=$(hadoop distcp -overwrite -m 100 hdfs://hacluster${region} hdfs://${targetHdfsAddress}${region})
    if [ $? == 0 ]; then
        echo "$region :copy success"
    else
        echo "$region :copy fail"
    fi
done
