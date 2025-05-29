# 每天自动生成markdown日志文件
diary_path=/Users/yangjiebin/Documents/private_blog/englilsh/routine
month_date=$(date +"%Y%m")
day_date=$1
if [ "$day_date" == "" ];then
  day_date=$(date +"%Y%m%d")
fi

today_diary_file=$diary_path/$month_date/$day_date.md
result=`cat $today_diary_file | grep "|" | grep -v "-" | awk -F'|' '{print $2,$4}' | tr '\n' ' '`
echo $result
