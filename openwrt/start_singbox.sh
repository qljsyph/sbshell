#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 检查当前模式
check_mode() {
    if nft list chain inet sing-box prerouting_tproxy &>/dev/null || nft list chain inet sing-box output_tproxy &>/dev/null; then
        echo "TProxy 模式"
    else
        echo "TUN 模式"
    fi
}

# 应用防火墙规则
apply_firewall() {
    MODE=$(grep -E '^MODE=' /etc/sing-box/mode.conf | sed 's/^MODE=//')
    if [ "$MODE" = "TProxy" ]; then
        bash "$SCRIPT_DIR/configure_tproxy.sh"
    elif [ "$MODE" = "TUN" ]; then
        bash "$SCRIPT_DIR/configure_tun.sh"
    fi
}

# 启动 sing-box 服务
start_singbox() {
    echo -e "${CYAN}检测是否处于非代理环境...${NC}"
    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo -e "${RED}当前网络处于代理环境, 启动 sing-box 需要直连!${NC}"
    else
        echo -e "${CYAN}当前网络环境非代理网络，可以启动 sing-box。${NC}"
    fi

    # 启动 sing-box 服务
    /etc/init.d/sing-box start

    sleep 2  # 等待 sing-box 启动
    

    if /etc/init.d/sing-box status | grep -q "running"; then
        echo -e "${GREEN}sing-box 启动成功${NC}"

        mode=$(check_mode)
        echo -e "${MAGENTA}当前启动模式: ${mode}${NC}"
    else
        echo -e "${RED}sing-box 启动失败，请检查日志${NC}"
    fi
}

# 提示用户确认是否启动
read -rp "是否启动 sing-box?(y/n): " confirm_start
if [[ "$confirm_start" =~ ^[Yy]$ ]]; then
    start_singbox
else
    echo -e "${CYAN}已取消启动 sing-box。${NC}"
    exit 0
fi
