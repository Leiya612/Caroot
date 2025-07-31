#!/bin/bash

# Nezha Agent 安装脚本

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root用户或通过sudo运行此脚本"
    exit 1
fi

# 初始化变量
server_address=""
secret_key=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --server_address:*)
            server_address="${1#*:}"
            shift
            ;;
        --secret_key:*)
            secret_key="${1#*:}"
            shift
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 步骤1：创建用户组、用户和目录
echo "正在创建nezha用户组和用户..."
groupadd nezha
useradd -m -d /opt/nezha -s /bin/bash -c "哪吒探针" -g nezha nezha
mkdir -p /opt/nezha/agent
cd /opt/nezha/agent || exit

# 步骤2：下载并解压二进制文件
echo "正在下载Nezha Agent..."
wget https://github.com/nezhahq/agent/releases/download/v0.17.6/nezha-agent_linux_amd64.zip -O nezha-agent_linux_amd64.zip

# 检查是否安装unzip
if ! command -v unzip &> /dev/null; then
    echo "正在安装unzip..."
    apt-get update && apt-get install -y unzip
fi

echo "正在解压文件..."
unzip -o nezha-agent_linux_amd64.zip
chmod +x nezha-agent
chown -R nezha:nezha /opt/nezha

# 步骤3：创建systemd服务
echo "正在配置systemd服务..."

# 获取服务器地址和密钥（如果未通过参数指定）
if [ -z "$server_address" ]; then
    read -rp "请输入服务器地址: " server_address
fi

if [ -z "$secret_key" ]; then
    read -rp "请输入密钥: " secret_key
fi

# 构建ExecStart命令
exec_start="/opt/nezha/agent/nezha-agent -s \"$server_address\" -p \"$secret_key\""

# 选项配置
echo -e "\n请选择以下安全选项配置："

# 选项1
read -rp "1. 禁用强制更新 (--disable-force-update)(默认禁用更新-Y) [Y/n]: " disable_force_update
disable_force_update=${disable_force_update:-Y}
if [[ $disable_force_update =~ ^[Yy]$ ]]; then
    exec_start+=" --disable-force-update"
fi

# 选项2
read -rp "2. 禁用自动更新 (--disable-auto-update)(默认禁用更新-Y) [Y/n]: " disable_auto_update
disable_auto_update=${disable_auto_update:-Y}
if [[ $disable_auto_update =~ ^[Yy]$ ]]; then
    exec_start+=" --disable-auto-update"
fi

# 选项3
read -rp "3. 使用IPv6地址查询国家代码 (--use-ipv6-countrycode)(默认不使用-N) [y/N]: " use_ipv6
use_ipv6=${use_ipv6:-N}
if [[ $use_ipv6 =~ ^[Yy]$ ]]; then
    exec_start+=" --use-ipv6-countrycode"
fi

# 选项4
read -rp "4. 禁止执行定时任务和在线终端 (--disable-command-execute)(默认不禁止-N) [y/N]: " disable_command
disable_command=${disable_command:-N}
if [[ $disable_command =~ ^[Yy]$ ]]; then
    exec_start+=" --disable-command-execute"
fi

# 创建服务文件
cat > /etc/systemd/system/nezha-agent.service <<EOF
[Unit]
Description=Nezha Agent
After=syslog.target

[Service]
Type=simple
User=nezha
Group=nezha
WorkingDirectory=/opt/nezha/agent/
ExecStart=$exec_start
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd并启动服务
systemctl daemon-reload
systemctl enable nezha-agent
systemctl start nezha-agent

echo -e "\n安装完成！"
echo "Nezha Agent 已启动并设置为开机自启"
echo "服务配置选项：$exec_start"
echo -e "\n可以使用以下命令管理服务:"
echo "启动服务: systemctl start nezha-agent"
echo "停止服务: systemctl stop nezha-agent"
echo "查看状态: systemctl status nezha-agent"
echo "查看日志: journalctl -u nezha-agent -f"

# ./nezha-agent-install.sh --server_address:**.1166.xyz:5555  --secret_key:uGDaIXROX6V2iOz6ED
