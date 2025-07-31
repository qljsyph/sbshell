#!/bin/bash

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CONFIG_URL_FILE="${CONFIG_DIR}/config.url"
DEFAULT_CONFIG_URL="https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/3.0.0/config_template/server/config.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${RED}sing-box 未安装或配置文件目录不存在，请先执行安装。${NC}"
    exit 1
fi

config_url=""
if [ -s "$CONFIG_URL_FILE" ]; then
    config_url=$(cat "$CONFIG_URL_FILE")
    echo -e "${YELLOW}当前配置链接为: ${NC}$config_url"
    read -rp "是否更换配置链接? (y/N): " change_url
    if [[ "$change_url" =~ ^[Yy]$ ]]; then
        read -rp "请输入新的配置链接: " config_url
    fi
else
    read -rp "首次使用,请输入配置链接 [回车使用默认]: " config_url
    [ -z "$config_url" ] && config_url="$DEFAULT_CONFIG_URL"
fi

if [ -z "$config_url" ]; then
    echo -e "${RED}配置链接不能为空，操作已取消。${NC}"
    exit 1
fi

echo -e "${CYAN}正在从以下链接下载配置文件: ${NC}$config_url"
if wget -O "$CONFIG_FILE" --no-check-certificate "$config_url"; then
    echo -e "${GREEN}配置文件下载成功！${NC}"
    echo "$config_url" > "$CONFIG_URL_FILE"
    echo -e "${CYAN}正在重启 sing-box 服务...${NC}"
    systemctl restart sing-box
    echo -e "${GREEN}服务已重启。${NC}"
else
    echo -e "${RED}配置文件下载失败，请检查链接是否正确或网络连接。${NC}"
    exit 1
fi
