#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"
TEMP_DIR="/tmp/sing-box"

# 脚本的URL基础路径
BASE_URL="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/main/openwrt"

# 初始下载菜单脚本的URL
MENU_SCRIPT_URL="$BASE_URL/menu.sh"

# 提示用户正在检测版本
echo -e "${CYAN}正在检测版本，请耐心等待...${NC}"

# 确保脚本目录和临时目录存在并设置权限
mkdir -p "$SCRIPT_DIR"
mkdir -p "$TEMP_DIR"
chown "$(id -u)":"$(id -g)" "$SCRIPT_DIR"
chown "$(id -u)":"$(id -g)" "$TEMP_DIR"

# 下载远程脚本到临时目录
wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"

# 检查下载是否成功
if ! [ -f "$TEMP_DIR/menu.sh" ]; then
    echo -e "${RED}下载远程脚本失败，请检查网络连接。${NC}"
    exit 1
fi

# 获取本地和远程脚本版本
LOCAL_VERSION=$(grep '^# 版本:' "$SCRIPT_DIR/menu.sh" | awk '{print $3}')
REMOTE_VERSION=$(grep '^# 版本:' "$TEMP_DIR/menu.sh" | awk '{print $3}')

# 检查远程版本是否为空
if [ -z "$REMOTE_VERSION" ]; then
    echo -e "${RED}远程版本获取失败，请检查网络连接。${NC}"
    read -rp "是否重试？(y/n): " retry_choice
    if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
        wget -q -O "$TEMP_DIR/menu.sh" "$MENU_SCRIPT_URL"
        REMOTE_VERSION=$(grep '^# 版本:' "$TEMP_DIR/menu.sh" | awk '{print $3}')
        if [ -z "$REMOTE_VERSION" ]; then
            echo -e "${RED}远程版本获取失败，请检查网络连接后再试。返回菜单。${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}请检查网络连接后再试。返回菜单。${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# 输出检测到的版本
echo -e "${CYAN}检测到的版本：本地版本 $LOCAL_VERSION, 远程版本 $REMOTE_VERSION${NC}"

# 比较版本号
if [ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}脚本版本为最新，无需升级。${NC}"
    read -rp "是否强制更新？(y/n): " force_update
    if [[ "$force_update" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}正在强制更新...${NC}"
    else
        echo -e "${CYAN}返回菜单。${NC}"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
else
    echo -e "${RED}检测到新版本，准备升级。${NC}"
fi

# 脚本列表
SCRIPTS=(
    "check_environment.sh"
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
    "update_ui.sh"
    "menu.sh"
)

# 下载并设置单个脚本，带重试逻辑
download_script() {
    local SCRIPT="$1"
    local RETRIES=3
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            sleep "$RETRY_DELAY"
        fi
    done

    echo -e "${RED}下载 $SCRIPT 失败，请检查网络连接。${NC}"
    return 1
}

# 并行下载脚本
parallel_download_scripts() {
    local pids=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        download_script "$SCRIPT" &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
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
    bash "$SCRIPT_DIR/clean_nft.sh"
    rm -rf /etc/sing-box
    echo -e "${CYAN}sing-box 文件夹已删除。${NC}"
    echo -e "${CYAN}正在重新拉取脚本，请耐心等待...${NC}"
    bash <(curl -s "$MENU_SCRIPT_URL")
}

# 提示用户并确认选择
echo -e "${CYAN}请选择更新方式：${NC}"
echo -e "${GREEN}1. 常规更新${NC}"
echo -e "${GREEN}2. 重置更新${NC}"
read -rp "请选择操作: " update_choice

case $update_choice in
    1)
        echo -e "${RED}常规更新只更新脚本内容, 再次执行菜单内容才会执行新脚本。${NC}"
        read -rp "是否继续常规更新？(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            regular_update
        else
            echo -e "${CYAN}常规更新已取消。${NC}"
        fi
        ;;
    2)
        echo -e "${RED}即将停止 sing-box 并重置所有内容, 并初始化引导设置。${NC}"
        read -rp "是否继续重置更新？(y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            reset_update
        else
            echo -e "${CYAN}重置更新已取消。${NC}"
        fi
        ;;
    *)
        echo -e "${RED}无效的选择。${NC}"
        ;;
esac

# 清理临时目录
rm -rf "$TEMP_DIR"
