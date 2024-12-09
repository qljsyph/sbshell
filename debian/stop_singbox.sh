#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 停止 sing-box 服务
stop_singbox() {
    sudo systemctl stop sing-box

    if ! systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box 已停止${NC}"

        # 提示用户确认是否清理防火墙规则
        read -p "是否清理防火墙规则？(y/n): " confirm_cleanup
        if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}执行清理防火墙规则...${NC}"
            bash "$SCRIPT_DIR/clean_nft.sh"
            echo -e "${GREEN}防火墙规则清理完毕${NC}"
        else
            echo -e "${CYAN}已取消清理防火墙规则。${NC}"
        fi

    else
        echo -e "${RED}停止 sing-box 失败，请检查日志${NC}"
    fi
}

# 提示用户确认是否停止
read -p "是否停止 sing-box？(y/n): " confirm_stop
if [[ "$confirm_stop" =~ ^[Yy]$ ]]; then
    stop_singbox
else
    echo -e "${CYAN}已取消停止 sing-box。${NC}"
    exit 0
fi
