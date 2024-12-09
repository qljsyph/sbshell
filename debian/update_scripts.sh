#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 脚本的URL基础路径
BASE_URL="https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/debian"

# 初始下载菜单脚本的URL
MENU_SCRIPT_URL="$BASE_URL/menu.sh"

# 脚本列表
SCRIPTS=(
    "check_environment.sh"
    "set_network.sh"
    "check_update.sh"
    "install_singbox.sh"
    "manual_input.sh"
    "manual_update.sh"
    "auto_update.sh"
    "configure_tproxy.sh"
    "configure_tun.sh"
    "start_singbox.sh"
    "stop_singbox.sh"
    "clean_nft.sh"
    "set_defaults.sh"
    "commands.sh"
    "switch_mode.sh"
    "manage_autostart.sh"
    "check_config.sh"
    "update_scripts.sh"
    "menu.sh"
)

# 下载并设置单个脚本，带重试逻辑
function download_script() {
    local SCRIPT="$1"
    local RETRIES=3
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"
        if [ $? -eq 0 ]; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            sleep $RETRY_DELAY
        fi
    done

    echo -e "${RED}下载 $SCRIPT 失败，请检查网络连接。${NC}"
    return 1
}

# 并行下载脚本
function parallel_download_scripts() {
    local pids=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        download_script "$SCRIPT" &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait $pid
    done
}

# 常规更新
function regular_update() {
    echo -e "${CYAN}正在清理缓存，请耐心等待...${NC}"
    rm -f "$SCRIPT_DIR"/*.sh
    echo -e "${CYAN}正在进行常规更新，请耐心等待...${NC}"
    parallel_download_scripts
    echo -e "${CYAN}脚本常规更新完成。${NC}"
}

# 重置更新
function reset_update() {
    echo -e "${RED}即将停止 sing-box 并重置所有内容，请稍候...${NC}"
    sudo bash "$SCRIPT_DIR/clean_nft.sh"
    sudo rm -rf /etc/sing-box
    echo -e "${CYAN}sing-box 文件夹已删除。${NC}"
    echo -e "${CYAN}正在重新拉取脚本，请耐心等待...${NC}"
    bash <(curl -s "$MENU_SCRIPT_URL")
}

# 提示用户并确认选择
echo -e "${CYAN}请选择更新方式：${NC}"
echo -e "${GREEN}1. 常规更新${NC}"
echo -e "${GREEN}2. 重置更新${NC}"
read -p "请选择操作: " update_choice

case $update_choice in
    1)
        echo -e "${RED}常规更新只更新脚本内容,再次执行菜单内容才会执行新脚本.${NC}"
        read -p "是否继续常规更新？(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            regular_update
        else
            echo -e "${CYAN}常规更新已取消。${NC}"
        fi
        ;;
    2)
        echo -e "${RED}即将停止 sing-box 并重置所有内容,并初始化引导设置.${NC}"
        read -p "是否继续重置更新？(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            reset_update
        else
            echo -e "${CYAN}重置更新已取消。${NC}"
        fi
        ;;
    *)
        echo -e "${RED}无效的选择${NC}"
        ;;
esac
