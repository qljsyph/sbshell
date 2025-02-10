#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 停止 sing-box 服务
stop_singbox() {
    /etc/init.d/sing-box stop

    if /etc/init.d/sing-box status | grep -q "not running"; then
        echo -e "${GREEN}sing-box 已停止${NC}"
    else
        echo -e "${CYAN}没有运行中的 sing-box 服务${NC}"
    fi

    # 提示用户确认是否清理防火墙规则
    read -rp "是否清理防火墙规则？(y/n): " confirm_cleanup
    if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}执行清理防火墙规则...${NC}"
        bash "$SCRIPT_DIR/clean_nft.sh"
        echo -e "${GREEN}防火墙规则清理完毕${NC}"
    else
        echo -e "${CYAN}已取消清理防火墙规则。${NC}"
    fi
}

# 提示用户确认是否停止
read -rp "是否停止 sing-box?(y/n): " confirm_stop
if [[ "$confirm_stop" =~ ^[Yy]$ ]]; then
    stop_singbox
else
    echo -e "${CYAN}已取消停止 sing-box。${NC}"
    exit 0
fi
