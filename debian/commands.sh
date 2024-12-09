#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 查看防火墙规则
function view_firewall_rules() {
    echo -e "${YELLOW}查看防火墙规则...${NC}"
    sudo nft list ruleset
    read -p "按回车键返回二级菜单..."
}

# 显示日志
function view_logs() {
    echo -e "${YELLOW}显示日志...${NC}"
    sudo journalctl -u sing-box --output cat -e
    read -p "按回车键返回二级菜单..."
}

# 实时日志
function live_logs() {
    echo -e "${YELLOW}实时日志...${NC}"
    sudo journalctl -u sing-box --output cat -f
    read -p "按回车键返回二级菜单..."
}

# 检查配置文件
function check_config() {
    echo -e "${YELLOW}检查配置文件...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -p "按回车键返回二级菜单..."
}

# 二级菜单选项
function show_submenu() {
    echo -e "${CYAN}=========== 二级菜单选项 ===========${NC}"
    echo -e "${MAGENTA}1. 查看防火墙规则${NC}"
    echo -e "${MAGENTA}2. 显示日志${NC}"
    echo -e "${MAGENTA}3. 实时日志${NC}"
    echo -e "${MAGENTA}4. 检查配置文件${NC}"
    echo -e "${MAGENTA}0. 返回主菜单${NC}"
    echo -e "${CYAN}=========== 作者：七尺宇 ===========${NC}"
}

# 处理用户输入
function handle_submenu_choice() {
    while true; do
        read -p "请选择操作: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) view_logs ;;
            3) live_logs ;;
            4) check_config ;;
            0) return 0 ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
        show_submenu
    done
}

# 显示并处理二级菜单
while true; do
    show_submenu
    handle_submenu_choice
    [[ $? -eq 0 ]] && break
done
