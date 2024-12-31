#!/bin/bash

NC='\033[0m'
CYAN='\033[0;36m'
RED='\033[0;31m'

# UI 目录
UI_DIR="/etc/sing-box/ui"

# 备份目录
BACKUP_DIR="/etc/sing-box/ui_backup"

# 临时目录
TEMP_DIR="/tmp/sing-box-ui"

# 确保目录存在
ensure_directories() {
    sudo mkdir -p "$UI_DIR"
    mkdir -p "$TEMP_DIR"
}

# 清理临时文件
cleanup() {
    rm -rf "${TEMP_DIR:?}"/*
}

# 从配置文件获取下载URL
get_download_url() {
    CONFIG_FILE="/etc/sing-box/config.json"
    DEFAULT_URL="https://ghproxy.cc/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
    
    if [ -f "$CONFIG_FILE" ]; then
        URL=$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "$CONFIG_FILE")
        echo "${URL:-$DEFAULT_URL}"
    else
        echo "$DEFAULT_URL"
    fi
}

# 使用busybox解压文件（不显示详细过程）
unzip_with_busybox() {
    busybox unzip "$1" -d "$2" > /dev/null 2>&1
}

# 备份UI目录
backup_ui() {
    echo "正在备份当前UI文件..."
    sudo rm -rf "$BACKUP_DIR"
    sudo cp -r "$UI_DIR" "$BACKUP_DIR"
}

# 还原UI目录
restore_ui() {
    echo -e "${RED}更新失败，正在还原备份...${NC}"
    sudo rm -rf "$UI_DIR"/*
    sudo cp -r "$BACKUP_DIR"/* "$UI_DIR"
}

# 下载并更新UI
update_ui() {
    echo -e "${CYAN}开始更新控制面板UI...${NC}"
    
    # 确保目录存在
    ensure_directories
    
    # 清理临时文件
    cleanup
    
    # 获取下载URL
    DOWNLOAD_URL=$(get_download_url)
    
    # 下载文件
    echo "正在下载UI文件..."
    curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/ui.zip"
    
    # 备份当前UI文件
    backup_ui
    
    # 清空原UI文件夹
    sudo rm -rf "$UI_DIR"/*
    
    # 解压文件
    echo "正在解压文件..."
    if unzip_with_busybox "$TEMP_DIR/ui.zip" "$TEMP_DIR"; then
        # 移动文件到UI目录
        sudo mv "$TEMP_DIR"/*/* "$UI_DIR"
        echo -e "${CYAN}控制面板UI更新完成,请刷新浏览器！${NC}"
    else
        # 还原备份
        restore_ui
    fi
}

update_ui