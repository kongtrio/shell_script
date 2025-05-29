# 每隔一段时间将a表的数据拷贝到b表的指定路径
# 主要用于模拟表的增量写入
period=60
batch_number=37
namespace=obs://mt-bigdata
source_hive_data_path=/var/hive/warehouse/stat_sdk.db/sdk_srz_source_data
target_hive_data_path=/var/hive/warehouse/bigdata_test.db/testacid
partition_path=date_p=20221102/app_key_p=F9CC8787275D8691

if [ ! -z $1 ]; then
    batch_number=$1
    echo "specify batchNumber is $batch_number"
fi

if [ ! -z $2 ]; then
    partition_path=$2
    echo "specify partition_path is $partition_path"
fi

source_list=($(hadoop fs -ls $namespace/$source_hive_data_path/$partition_path | sort -k 7 | awk '{print $8}' | grep obs))
cursor=0
echo "source file list size is ${#source_list[*]}"

while [ $cursor -lt ${#source_list[*]} ]; do
    echo "begin new turn copy file"
    turn_begin_time=$(date +"%s")
    copy_string=""
    for ((i = 1; i <= $batch_number; i = i + 1)); do
        file_path=${source_list[$cursor]}
        copy_string=${copy_string}" "${file_path}
        #cursor=$((cursor + 1))
        let "cursor++"
        if [ $cursor -ge ${#source_list[*]} ]; then
            break
        fi
    done
    $(hadoop fs -cp ${copy_string} $namespace/$target_hive_data_path/$partition_path)
    turn_end_time=$(date +"%s")
    eplapse_time=$(($turn_end_time - $turn_begin_time))
    echo "this turn use time:$eplapse_time"
    need_sleep_time=$(($period - $eplapse_time))
    if [ $need_sleep_time -gt 0 ]; then
        sleep $period
    fi
done
echo "end copy"
