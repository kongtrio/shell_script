# 大数据基础工具安装脚本

## 简介

这是一个用于安装大数据基础工具的自动化脚本，支持安装以下组件：

- datawork-client：提交sql执行客户端
- mt-spark-submit：Spark提交工具
- sven-hadoop：Hadoop工具
- scheduler-d-agent-cloud：调度器agent

脚本具有丰富的命令行参数，彩色输出，详细的日志记录，以及灵活的安装包管理功能。

## 安装逻辑

### 基本流程

1. **参数解析**：解析命令行参数，确定安装目录、安装包目录、要安装的组件等
2. **环境检查**：检查安装环境，确保安装目录可用,默认安装目录为 /www
3. **组件安装**：按照选择的组件列表依次安装
4. **结果统计**：显示安装结果摘要，包括成功和失败的组件

### 组件安装流程

每个组件的安装流程如下：

1. **检查是否已安装**：如果组件已经存在且不是强制安装模式，则跳过
2. **获取安装包**：
   - 首先检查安装包目录下是否有对应安装包
   - 如果没有，则尝试从远程源拉取到安装包目录,跳板机为10.16.16.235:/hw_bigdatabasics
3. **解压安装包**：将安装包解压到安装目录
4. **执行安装脚本**：运行组件自带的安装脚本完成安装

### 错误处理

- 每个关键步骤都有错误检查
- 如果某个组件安装失败，会记录错误但不影响其他组件的安装
- 安装结束后会显示详细的成功/失败统计

## 使用方法

### 基本用法

```bash
./bigdata_infra_setup_tools.sh [选项] [工具名称...]
```

### 选项说明

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息并退出 |
| `-v, --verbose` | 显示详细输出信息 |
| `-f, --force` | 强制重新安装，即使工具已经存在 |
| `-d, --dir DIR` | 指定安装目录 (默认: /www) |
| `-p, --packages DIR` | 指定安装包目录 (默认: 脚本所在目录) |
| `-r, --remote URL` | 指定远程源地址 |
| `--version` | 显示版本信息并退出 |

### 可用工具

| 工具名称 | 说明 |
|---------|------|
| `datawork` | 安装 datawork-client |
| `spark` | 安装 mt-spark-submit |
| `hadoop` | 安装 sven-hadoop |
| `scheduler` | 安装 scheduler-d-agent-cloud |
| `all` | 安装所有工具 (默认) |

### 使用示例

1. **显示帮助信息**
   ```bash
   ./bigdata_infra_setup_tools.sh
   ```

2. **安装所有工具**
   ```bash
   ./bigdata_infra_setup_tools.sh all
   ```

3. **只安装特定工具**
   ```bash
   ./bigdata_infra_setup_tools.sh datawork spark
   ```

4. **强制重新安装所有工具**
   ```bash
   ./bigdata_infra_setup_tools.sh -f all
   ```

5. **指定安装目录**
   ```bash
   ./bigdata_infra_setup_tools.sh -d /opt/bigdata all
   ```

6. **指定安装包目录**
   ```bash
   ./bigdata_infra_setup_tools.sh -p /path/to/packages all
   ```

7. **组合使用多个参数**
   ```bash
   ./bigdata_infra_setup_tools.sh -p /path/to/packages -d /opt/bigdata -f datawork spark
   ```

## 注意事项

1. 安装目录需要有写入权限
2. 如果使用远程源，需要确保网络连接正常
3. 安装包可以预先下载到指定目录，避免重复下载
4. 日志文件会记录详细的安装过程，便于排查问题

## 脚本结构

- 颜色和常量定义
- 参数解析和帮助显示
- 日志记录和进度显示
- 安装函数（每个组件一个）
- 主函数和执行逻辑

## 自定义和扩展

如需添加新的组件，只需按照现有模式添加新的安装函数，并在主函数中调用即可。
