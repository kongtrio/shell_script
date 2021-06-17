expire_days=30
check_dir=/srv/BigData/hadoop/data1/kyuubiserver/logs/

expire_files=`find ${check_dir} -ctime +${expire_days}`

for expire_file in ${expire_files}
do
    echo "delete:::"${expire_file}
done
