#!/bin/bash

# 定义颜色常量
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

# 获取脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置
base_dir="/www"
packages_dir="$script_dir"  # 默认使用脚本所在目录作为安装包目录
remote_dir="bigdata@10.16.16.235::hw_bigdatabasics"
verbose=false
log_file="$script_dir/setup_tools_$(date +%Y%m%d_%H%M%S).log"
force_install=false
selected_tools=()

# 安装JDK
function install_jdk() {
    log "INFO" "${BOLD}${MAGENTA}====== 开始处理 JDK 1.8.0_51 ======${RESET}"
    jdk_tar_name="jdk1.8.0_51.tar.gz"
    jdk_dir="$base_dir/jdk1.8.0_51"
    
    # 首先检查JAVA_HOME环境变量是否已经设置
    if [ -n "$JAVA_HOME" ] && ! $force_install; then
        log "INFO" "${YELLOW}JAVA_HOME环境变量已设置为: $JAVA_HOME，跳过JDK安装${RESET}"
        
        # 输出java版本
        if command -v java > /dev/null 2>&1; then
            java_version=$(java -version 2>&1)
            log "INFO" "${GREEN}当前JDK版本信息: ${RESET}"
            log "INFO" "$java_version"
        else
            log "WARN" "${YELLOW}JAVA_HOME已设置，但无法执行java命令${RESET}"
        fi
        
        return 0
    fi
    
    # 检查JDK是否已存在
    if [ -d "$jdk_dir" ] && ! $force_install; then
        log "INFO" "${YELLOW}$jdk_dir 已存在，无须重新安装${RESET}"
    else
        if $force_install && [ -d "$jdk_dir" ]; then
            log "WARN" "强制重新安装 JDK"
            rm -rf "$jdk_dir"
        fi
        
        log "INFO" "${CYAN}开始安装 JDK${RESET}"
        
        # 首先检查安装包目录下是否有安装包
        if [ -f "$packages_dir/$jdk_tar_name" ]; then
            log "INFO" "在安装包目录中找到 $jdk_tar_name"
        else
            log "INFO" "$jdk_tar_name 在安装包目录 $packages_dir 中不存在，尝试从远程拉取"
            rsync -av --progress $remote_dir/$jdk_tar_name $packages_dir
            # 检查rsync命令是否成功
            if ! check_command_result $? "从远程拉取 $jdk_tar_name 失败，请检查远程源是否可用或文件是否存在"; then
                return 1
            fi
        fi
        
        # 再次检查文件是否存在
        if [ ! -f "$packages_dir/$jdk_tar_name" ]; then
            log "ERROR" "$jdk_tar_name 文件不存在，无法继续安装"
            return 1
        fi
        
        # 创建安装目录（如果不存在）
        if [ ! -d "$base_dir" ]; then
            log "INFO" "创建安装目录 $base_dir"
            mkdir -p "$base_dir"
            if [ $? -ne 0 ]; then
                log "ERROR" "无法创建安装目录 $base_dir"
                return 1
            fi
        fi
        
        log "INFO" "解压 $jdk_tar_name"
        tar -zxf $packages_dir/$jdk_tar_name -C $base_dir > /dev/null 2>&1 &
        show_progress $! "解压 JDK"
        result=$?
        if ! check_command_result $result "解压 $jdk_tar_name 失败，请检查文件是否完整"; then
            return 1
        fi
        
        # 检查安装目录是否存在
        if [ ! -d "$jdk_dir" ]; then
            log "ERROR" "解压后未找到 $jdk_dir 目录，安装包可能损坏"
            return 1
        fi
        
        # 配置环境变量
        log "INFO" "配置JDK环境变量"
        
        # 检查是否已配置环境变量
        if grep -q "JAVA_HOME=$jdk_dir" /root/.bashrc; then
            log "INFO" "JAVA_HOME环境变量已存在，无需重复配置"
        else
            # 添加环境变量到root的.bashrc文件
            echo "" >> /root/.bashrc
            echo "# JDK环境变量配置" >> /root/.bashrc
            echo "export JAVA_HOME=$jdk_dir" >> /root/.bashrc
            echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /root/.bashrc
            
            # 使环境变量立即生效
            export JAVA_HOME=$jdk_dir
            export PATH=$JAVA_HOME/bin:$PATH
            
            log "INFO" "已配置JAVA_HOME=$jdk_dir"
            log "INFO" "已将JDK添加到PATH环境变量"
        fi
        
        # 验证JDK安装
        if command -v java > /dev/null 2>&1; then
            java_version=$(java -version 2>&1 | head -n 1)
            log "INFO" "${GREEN}JDK安装验证成功: $java_version${RESET}"
        else
            log "WARN" "JDK安装可能未成功，无法执行java命令"
        fi
        
        log "INFO" "${GREEN}${BOLD}JDK 安装完成${RESET}"
    fi
    return 0
}

# 版本信息
VERSION="1.0.0"

# 记录日志
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO")
            local color=$GREEN
            ;;
        "WARN")
            local color=$YELLOW
            ;;
        "ERROR")
            local color=$RED
            ;;
        "DEBUG")
            local color=$BLUE
            ;;
        *)
            local color=$RESET
            ;;
    esac
    
    if $verbose; then
        echo -e "${color}[$timestamp] [$level] $message${RESET}"
    else
        # 非详细模式下，只显示INFO、WARN和ERROR
        if [[ "$level" != "DEBUG" ]]; then
            echo -e "${color}[$level] $message${RESET}"
        fi
    fi
    
    # 记录到日志文件
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# 显示进度条并检查执行结果
show_progress() {
    local pid=$1
    local message=$2
    local cmd_result_file=$(mktemp)
    local spin=('-' '\\' '|' '/')
    local i=0
    
    # 等待命令执行完成
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r${CYAN}[${spin[$i]}] $message...${RESET}"
        sleep 0.1
    done
    
    # 获取命令的退出状态
    wait $pid
    local exit_status=$?
    
    # 根据命令执行结果显示不同的标记
    if [ $exit_status -eq 0 ]; then
        printf "\r${GREEN}[✓] $message 完成${RESET}\n"
        return 0
    else
        printf "\r${RED}[✗] $message 失败${RESET}\n"
        return 1
    fi
}

# 检查命令执行结果并处理错误
check_command_result() {
    local result=$1
    local error_message=$2
    local exit_on_error=${3:-false}  # 默认不退出
    
    if [ $result -ne 0 ]; then
        log "ERROR" "$error_message"
        if $exit_on_error; then
            log "ERROR" "由于错误，安装过程已终止。请解决上述问题后重试。"
            exit 1
        fi
        return 1
    fi
    return 0
}

# 安装datawork-client，如果本地已经安装了，则跳过
function install_datawork_client() {
    log "INFO" "${BOLD}${MAGENTA}====== 开始处理 datawork-client ======${RESET}"
    datawork_client_tar_name="datawork-client.tar.gz"
    datawork_client_dir="$base_dir/datawork-client"
    local install_status=0

    # 检查datawork_client是否已存在
    if [ -d "$datawork_client_dir" ] && ! $force_install; then
        log "INFO" "${YELLOW}$datawork_client_dir 已存在，无须重新安装${RESET}"
        return 0
    else
        if $force_install && [ -d "$datawork_client_dir" ]; then
            log "WARN" "强制重新安装 datawork-client"
            rm -rf "$datawork_client_dir"
        fi
        
        log "INFO" "${CYAN}开始安装 datawork-client${RESET}"
        
        # 首先检查安装包目录下是否有安装包
        if [ -f "$packages_dir/$datawork_client_tar_name" ]; then
            log "INFO" "在安装包目录中找到 $datawork_client_tar_name"
        else
            log "INFO" "$datawork_client_tar_name 在安装包目录 $packages_dir 中不存在，尝试从远程拉取"
            rsync -av --progress $remote_dir/$datawork_client_tar_name $packages_dir
            # 检查rsync命令是否成功
            if ! check_command_result $? "从远程拉取 $datawork_client_tar_name 失败，请检查远程源是否可用或文件是否存在"; then
                return 1
            fi
        fi
        
        # 再次检查文件是否存在
        if [ ! -f "$packages_dir/$datawork_client_tar_name" ]; then
            log "ERROR" "$datawork_client_tar_name 文件不存在，无法继续安装"
            return 1
        fi
        
        # 创建安装目录（如果不存在）
        if [ ! -d "$base_dir" ]; then
            log "INFO" "创建安装目录 $base_dir"
            mkdir -p "$base_dir"
            if [ $? -ne 0 ]; then
                log "ERROR" "无法创建安装目录 $base_dir"
                return 1
            fi
        fi
        
        log "INFO" "解压 $datawork_client_tar_name"
        tar -zxf $packages_dir/$datawork_client_tar_name -C $base_dir > /dev/null 2>&1 &
        show_progress $! "解压 datawork-client"
        result=$?
        if ! check_command_result $result "解压 $datawork_client_tar_name 失败，请检查文件是否完整"; then
            return 1
        fi
        
        # 检查安装目录是否存在
        if [ ! -d "$datawork_client_dir" ]; then
            log "ERROR" "解压后未找到 $datawork_client_dir 目录，安装包可能损坏"
            return 1
        fi
        
        log "INFO" "开始安装 datawork-client"
        sh $datawork_client_dir/sbin/install.sh > /dev/null 2>&1 &
        show_progress $! "安装 datawork-client"
        result=$?
        if ! check_command_result $result "安装 datawork-client 失败，请检查安装脚本"; then
            return 1
        fi
        
        log "INFO" "${GREEN}${BOLD}datawork-client 安装完成${RESET}"
        return 0
    fi
}

function install_mt_spark_submit() {
    log "INFO" "${BOLD}${MAGENTA}====== 开始处理 mt-spark-submit ======${RESET}"
    mt_spark_submit_tar_name="mt-spark-submit.tar.gz"
    mt_spark_submit_dir="$base_dir/mt-spark-submit"

    # 检查mt_spark_submit是否已存在
    if [ -d "$mt_spark_submit_dir" ] && ! $force_install; then
        log "INFO" "${YELLOW}$mt_spark_submit_dir 已存在，无须重新安装${RESET}"
        return 0
    else
        if $force_install && [ -d "$mt_spark_submit_dir" ]; then
            log "WARN" "强制重新安装 mt-spark-submit"
            rm -rf "$mt_spark_submit_dir"
        fi
        
        log "INFO" "${CYAN}开始安装 mt-spark-submit${RESET}"
        
        # 首先检查安装包目录下是否有安装包
        if [ -f "$packages_dir/$mt_spark_submit_tar_name" ]; then
            log "INFO" "在安装包目录中找到 $mt_spark_submit_tar_name"
        else
            log "INFO" "$mt_spark_submit_tar_name 在安装包目录 $packages_dir 中不存在，尝试从远程拉取"
            rsync -av --progress $remote_dir/$mt_spark_submit_tar_name $packages_dir
            # 检查rsync命令是否成功
            if ! check_command_result $? "从远程拉取 $mt_spark_submit_tar_name 失败，请检查远程源是否可用或文件是否存在"; then
                return 1
            fi
        fi
        
        # 再次检查文件是否存在
        if [ ! -f "$packages_dir/$mt_spark_submit_tar_name" ]; then
            log "ERROR" "$mt_spark_submit_tar_name 文件不存在，无法继续安装"
            return 1
        fi
        
        # 创建安装目录（如果不存在）
        if [ ! -d "$base_dir" ]; then
            log "INFO" "创建安装目录 $base_dir"
            mkdir -p "$base_dir"
            if [ $? -ne 0 ]; then
                log "ERROR" "无法创建安装目录 $base_dir"
                return 1
            fi
        fi
        
        log "INFO" "解压 $mt_spark_submit_tar_name"
        tar -zxf $packages_dir/$mt_spark_submit_tar_name -C $base_dir > /dev/null 2>&1 &
        show_progress $! "解压 mt-spark-submit"
        result=$?
        if ! check_command_result $result "解压 $mt_spark_submit_tar_name 失败，请检查文件是否完整"; then
            return 1
        fi
        
        # 检查安装目录是否存在
        if [ ! -d "$mt_spark_submit_dir" ]; then
            log "ERROR" "解压后未找到 $mt_spark_submit_dir 目录，安装包可能损坏"
            return 1
        fi
        
        log "INFO" "开始安装 mt-spark-submit"
        sh $mt_spark_submit_dir/sbin/install.sh > /dev/null 2>&1 &
        show_progress $! "安装 mt-spark-submit"
        result=$?
        if ! check_command_result $result "安装 mt-spark-submit 失败，请检查安装脚本"; then
            return 1
        fi
        
        log "INFO" "${GREEN}${BOLD}mt-spark-submit 安装完成${RESET}"
        return 0
    fi
}

function install_sven_hadoop() {
    log "INFO" "${BOLD}${MAGENTA}====== 开始处理 sven-hadoop ======${RESET}"
    sven_hadoop_tar_name="sven-hadoop.tar.gz"
    sven_hadoop_dir="$base_dir/sven-hadoop"

    # 检查sven_hadoop是否已存在
    if [ -d "$sven_hadoop_dir" ] && ! $force_install; then
        log "INFO" "${YELLOW}$sven_hadoop_dir 已存在，无须重新安装${RESET}"
        return 0
    else
        if $force_install && [ -d "$sven_hadoop_dir" ]; then
            log "WARN" "强制重新安装 sven-hadoop"
            rm -rf "$sven_hadoop_dir"
        fi
        
        log "INFO" "${CYAN}开始安装 sven-hadoop${RESET}"
        
        # 首先检查安装包目录下是否有安装包
        if [ -f "$packages_dir/$sven_hadoop_tar_name" ]; then
            log "INFO" "在安装包目录中找到 $sven_hadoop_tar_name"
        else
            log "INFO" "$sven_hadoop_tar_name 在安装包目录 $packages_dir 中不存在，尝试从远程拉取"
            rsync -av --progress $remote_dir/$sven_hadoop_tar_name $packages_dir
            # 检查rsync命令是否成功
            if ! check_command_result $? "从远程拉取 $sven_hadoop_tar_name 失败，请检查远程源是否可用或文件是否存在"; then
                return 1
            fi
        fi
        
        # 再次检查文件是否存在
        if [ ! -f "$packages_dir/$sven_hadoop_tar_name" ]; then
            log "ERROR" "$sven_hadoop_tar_name 文件不存在，无法继续安装"
            return 1
        fi
        
        # 创建安装目录（如果不存在）
        if [ ! -d "$base_dir" ]; then
            log "INFO" "创建安装目录 $base_dir"
            mkdir -p "$base_dir"
            if [ $? -ne 0 ]; then
                log "ERROR" "无法创建安装目录 $base_dir"
                return 1
            fi
        fi
        
        log "INFO" "解压 $sven_hadoop_tar_name"
        tar -zxf $packages_dir/$sven_hadoop_tar_name -C $base_dir > /dev/null 2>&1 &
        show_progress $! "解压 sven-hadoop"
        result=$?
        if ! check_command_result $result "解压 $sven_hadoop_tar_name 失败，请检查文件是否完整"; then
            return 1
        fi
        
        # 检查安装目录是否存在
        if [ ! -d "$sven_hadoop_dir" ]; then
            log "ERROR" "解压后未找到 $sven_hadoop_dir 目录，安装包可能损坏"
            return 1
        fi
        
        log "INFO" "开始安装 sven-hadoop"
        sh $sven_hadoop_dir/sbin/install.sh > /dev/null 2>&1 &
        show_progress $! "安装 sven-hadoop"
        result=$?
        if ! check_command_result $result "安装 sven-hadoop 失败，请检查安装脚本"; then
            return 1
        fi
        
        log "INFO" "${GREEN}${BOLD}sven-hadoop 安装完成${RESET}"
        return 0
    fi
}

function install_scheduler_d_agent() {
    log "INFO" "${BOLD}${MAGENTA}====== 开始处理 scheduler-d-agent-cloud ======${RESET}"
    scheduler_d_agent_cloud_tar_name="scheduler-d-agent-cloud.tar.gz"
    scheduler_d_agent_cloud_dir="$base_dir/scheduler-d-agent-cloud"

    # 检查scheduler_d_agent_cloud是否已存在
    if [ -d "$scheduler_d_agent_cloud_dir" ] && ! $force_install; then
        log "INFO" "${YELLOW}$scheduler_d_agent_cloud_dir 已存在，无须重新安装${RESET}"
        return 0
    else
        if $force_install && [ -d "$scheduler_d_agent_cloud_dir" ]; then
            log "WARN" "强制重新安装 scheduler-d-agent-cloud"
            rm -rf "$scheduler_d_agent_cloud_dir"
        fi
        
        log "INFO" "${CYAN}开始安装 scheduler-d-agent-cloud${RESET}"
        
        # 首先检查安装包目录下是否有安装包
        if [ -f "$packages_dir/$scheduler_d_agent_cloud_tar_name" ]; then
            log "INFO" "在安装包目录中找到 $scheduler_d_agent_cloud_tar_name"
        else
            log "INFO" "$scheduler_d_agent_cloud_tar_name 在安装包目录 $packages_dir 中不存在，尝试从远程拉取"
            rsync -av --progress $remote_dir/$scheduler_d_agent_cloud_tar_name $packages_dir
            # 检查rsync命令是否成功
            if ! check_command_result $? "从远程拉取 $scheduler_d_agent_cloud_tar_name 失败，请检查远程源是否可用或文件是否存在"; then
                return 1
            fi
        fi
        
        # 再次检查文件是否存在
        if [ ! -f "$packages_dir/$scheduler_d_agent_cloud_tar_name" ]; then
            log "ERROR" "$scheduler_d_agent_cloud_tar_name 文件不存在，无法继续安装"
            return 1
        fi
        
        # 创建安装目录（如果不存在）
        if [ ! -d "$base_dir" ]; then
            log "INFO" "创建安装目录 $base_dir"
            mkdir -p "$base_dir"
            if [ $? -ne 0 ]; then
                log "ERROR" "无法创建安装目录 $base_dir"
                return 1
            fi
        fi
        
        log "INFO" "解压 $scheduler_d_agent_cloud_tar_name"
        tar -zxf $packages_dir/$scheduler_d_agent_cloud_tar_name -C $base_dir > /dev/null 2>&1 &
        show_progress $! "解压 scheduler-d-agent-cloud"
        result=$?
        if ! check_command_result $result "解压 $scheduler_d_agent_cloud_tar_name 失败，请检查文件是否完整"; then
            return 1
        fi
        
        # 检查安装目录是否存在
        if [ ! -d "$scheduler_d_agent_cloud_dir" ]; then
            log "ERROR" "解压后未找到 $scheduler_d_agent_cloud_dir 目录，安装包可能损坏"
            return 1
        fi
        
        log "INFO" "开始安装 scheduler-d-agent-cloud"
        sh $scheduler_d_agent_cloud_dir/bin/start.sh > /dev/null 2>&1 &
        show_progress $! "安装 scheduler-d-agent-cloud"
        result=$?
        if ! check_command_result $result "安装 scheduler-d-agent-cloud 失败，请检查安装脚本"; then
            return 1
        fi
        
        log "INFO" "${GREEN}${BOLD}scheduler-d-agent-cloud 安装完成${RESET}"
        return 0
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${BOLD}${BLUE}大数据基础工具安装脚本 v${VERSION}${RESET}"
    echo -e "${CYAN}用法:${RESET} $0 [选项] [工具名称...]"
    echo 
    echo -e "${CYAN}选项:${RESET}"
    echo -e "  ${GREEN}-h, --help${RESET}         显示此帮助信息并退出"
    echo -e "  ${GREEN}-v, --verbose${RESET}      显示详细输出信息"
    echo -e "  ${GREEN}-f, --force${RESET}        强制重新安装，即使工具已经存在"
    echo -e "  ${GREEN}-d, --dir${RESET} DIR      指定安装目录 (默认: $base_dir)"
    echo -e "  ${GREEN}-p, --packages${RESET} DIR  指定安装包目录 (默认: $packages_dir)"
    echo -e "  ${GREEN}-r, --remote${RESET} URL   指定远程源地址 (默认: $remote_dir)"
    echo -e "  ${GREEN}--version${RESET}          显示版本信息并退出"
    echo 
    echo -e "${CYAN}可用工具:${RESET}"
    echo -e "  ${YELLOW}datawork${RESET}           安装 datawork-client"
    echo -e "  ${YELLOW}spark${RESET}              安装 mt-spark-submit"
    echo -e "  ${YELLOW}hadoop${RESET}             安装 sven-hadoop"
    echo -e "  ${YELLOW}scheduler${RESET}          安装 scheduler-d-agent-cloud"
    echo -e "  ${YELLOW}all${RESET}                安装所有工具 (默认)"
    echo 
    echo -e "${CYAN}示例:${RESET}"
    echo -e "  $0                          # 显示帮助信息"
    echo -e "  $0 all                      # 安装所有工具"
    echo -e "  $0 datawork spark           # 只安装 datawork-client 和 mt-spark-submit"
    echo -e "  $0 -f all                   # 强制重新安装所有工具"
    echo -e "  $0 -d /opt/bigdata          # 指定安装目录为 /opt/bigdata"
    echo -e "  $0 -p /path/to/packages all # 从指定目录加载安装包"
}

# 显示版本信息
show_version() {
    echo -e "${BOLD}大数据基础工具安装脚本 v${VERSION}${RESET}"
}

# 解析命令行参数
parse_args() {
    # 如果没有传入任何参数，直接显示帮助信息并退出
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            -d|--dir)
                base_dir="$2"
                shift 2
                ;;
            -p|--packages)
                packages_dir="$2"
                shift 2
                ;;
            -r|--remote)
                remote_dir="$2"
                shift 2
                ;;
            --version)
                show_version
                exit 0
                ;;
            datawork|spark|hadoop|scheduler|all)
                selected_tools+=("$1")
                shift
                ;;
            *)
                log "ERROR" "未知选项或工具: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定工具，默认安装所有工具
    if [ ${#selected_tools[@]} -eq 0 ]; then
        selected_tools+=("all")
    fi
}

# 显示安装摘要
show_summary() {
    echo -e "\n${BOLD}${BLUE}=== 安装摘要 ===${RESET}"
    echo -e "${CYAN}安装目录:${RESET} $base_dir"
    echo -e "${CYAN}安装包目录:${RESET} $packages_dir"
    echo -e "${CYAN}远程源:${RESET} $remote_dir"
    echo -e "${CYAN}日志文件:${RESET} $log_file"
    echo -e "${CYAN}强制安装:${RESET} $(if $force_install; then echo "是"; else echo "否"; fi)"
    echo -e "${CYAN}详细模式:${RESET} $(if $verbose; then echo "是"; else echo "否"; fi)"
    echo -e "${CYAN}选择的工具:${RESET} ${selected_tools[*]}"
    echo -e "${BOLD}${BLUE}================${RESET}\n"
}

# 检查安装环境
check_environment() {
    log "INFO" "检查安装环境"
    
    # 检查安装目录
    if [ ! -d "$base_dir" ]; then
        log "WARN" "安装目录 $base_dir 不存在，尝试创建"
        mkdir -p "$base_dir" || { log "ERROR" "无法创建安装目录 $base_dir"; exit 1; }
    fi
    
    # 检查rsync命令
    if ! command -v rsync &> /dev/null; then
        log "ERROR" "未找到rsync命令，请先安装rsync"
        exit 1
    fi
    
    # 检查远程连接
    log "INFO" "测试远程连接"
    if ! rsync --dry-run $remote_dir &> /dev/null; then
        log "ERROR" "无法连接到远程源 $remote_dir"
        exit 1
    fi
    
    log "INFO" "环境检查通过"
}

# 全局变量记录各组件安装结果
declare -A install_results

# 安装组件并记录结果
install_component() {
    local component=$1
    local install_function=$2
    
    log "INFO" "${BOLD}${BLUE}开始安装 $component${RESET}"
    
    # 执行安装函数
    $install_function
    local result=$?
    
    # 记录安装结果
    if [ $result -eq 0 ]; then
        install_results["$component"]="成功"
        log "INFO" "${GREEN}$component 安装成功${RESET}"
    else
        install_results["$component"]="失败"
        log "WARN" "${RED}$component 安装失败，继续安装其他组件${RESET}"
    fi
    
    # 添加分隔线
    log "INFO" "${BOLD}${BLUE}------------------------------${RESET}"
    
    return $result
}

# 显示安装结果摘要
show_install_summary() {
    local success_count=0
    local failed_count=0
    
    echo -e "\n${BOLD}${BLUE}=== 安装结果摘要 ===${RESET}"
    
    # 遍历安装结果
    for component in "${!install_results[@]}"; do
        local status=${install_results["$component"]}
        
        if [ "$status" == "成功" ]; then
            echo -e "${component}: ${GREEN}成功${RESET}"
            ((success_count++))
        else
            echo -e "${component}: ${RED}失败${RESET}"
            ((failed_count++))
        fi
    done
    
    # 显示统计信息
    echo -e "\n${CYAN}成功:${RESET} ${GREEN}$success_count${RESET}"
    echo -e "${CYAN}失败:${RESET} ${RED}$failed_count${RESET}"
    echo -e "${CYAN}总计:${RESET} $((success_count + failed_count))"
    
    # 如果有失败的组件，显示提示信息
    if [ $failed_count -gt 0 ]; then
        echo -e "\n${YELLOW}注意: 部分组件安装失败，请查看日志文件 $log_file 获取详细信息${RESET}"
    fi
    
    echo -e "${BOLD}${BLUE}================${RESET}\n"
}

# 主函数
function main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 显示安装摘要
    show_summary
    
    # 检查安装环境
    check_environment
    
    # 安装JDK
    log "INFO" "${BOLD}${BLUE}开始安装 JDK${RESET}"
    install_jdk
    if [ $? -eq 0 ]; then
        install_results["JDK"]="成功"
        log "INFO" "${GREEN}JDK 安装成功${RESET}"
    else
        install_results["JDK"]="失败"
        log "ERROR" "${RED}JDK 安装失败，可能会影响其他组件的安装${RESET}"
    fi
    log "INFO" "${BOLD}${BLUE}------------------------------${RESET}"
    
    # 开始时间
    start_time=$(date +%s)
    
    # 根据选择的工具进行安装
    if [[ " ${selected_tools[@]} " =~ " all " ]]; then
        # 如果选择了all，则安装所有工具
        log "INFO" "安装所有工具"
        install_component "datawork-client" install_datawork_client
        install_component "mt-spark-submit" install_mt_spark_submit
        install_component "sven-hadoop" install_sven_hadoop
        install_component "scheduler-d-agent-cloud" install_scheduler_d_agent
    else
        # 否则只安装选择的工具
        for tool in "${selected_tools[@]}"; do
            case $tool in
                datawork)
                    install_component "datawork-client" install_datawork_client
                    ;;
                spark)
                    install_component "mt-spark-submit" install_mt_spark_submit
                    ;;
                hadoop)
                    install_component "sven-hadoop" install_sven_hadoop
                    ;;
                scheduler)
                    install_component "scheduler-d-agent-cloud" install_scheduler_d_agent
                    ;;
                *)
                    log "WARN" "未知工具: $tool，跳过"
                    ;;
            esac
        done
    fi
    
    # 结束时间
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # 显示安装结果
    echo -e "\n${BOLD}${GREEN}=== 安装完成 ===${RESET}"
    echo -e "${CYAN}总耗时:${RESET} ${duration}秒"
    echo -e "${CYAN}日志文件:${RESET} $log_file"
    echo -e "${BOLD}${GREEN}================${RESET}\n"
    
    # 显示安装结果摘要
    show_install_summary
}

# 执行主函数，传递所有命令行参数
main "$@"
