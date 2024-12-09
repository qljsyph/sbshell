#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CONFIG_FILE="/etc/sing-box/config.json"

# 检查配置文件是否存在
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}检查配置文件 ${CONFIG_FILE} ...${NC}"
    # 验证配置文件
    if sing-box check -c "$CONFIG_FILE"; then
        echo -e "${CYAN}配置文件验证通过！${NC}"
    else
        echo -e "${RED}配置文件验证失败！${NC}"
        exit 1
    fi
else
    echo -e "${RED}配置文件 ${CONFIG_FILE} 不存在！${NC}"
    exit 1
fi
