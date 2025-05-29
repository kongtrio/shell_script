# 每天自动生成markdown日志文件
diary_path=/Volumes/sn580/Documents/private_doc/diary
month_date=$(date +"%Y%m")
day_date=$(date +"%Y%m%d")
if [ ! -d $diary_path/$month_date ]; then
    mkdir $diary_path/$month_date
fi

today_diary_file=$diary_path/$month_date/$day_date.md
end_date=$(date -v+7d +"%Y%m%d")
if [ ! -f $today_diary_file ]; then
    touch $today_diary_file
    echo "[toc] \n ## ${day_date}~${end_date}" >$today_diary_file
else
    echo "$today_diary_file already created"
fi

echo "end execute"
