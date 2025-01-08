#!/bin/bash

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/etc/sing-box/ui_backup"
TEMP_DIR="/tmp/sing-box-ui"

METACUBEXD_URL="https://ghproxy.cc/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
ZASHBOARD_URL="https://ghproxy.cc/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
YACD_URL="https://ghproxy.cc/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

unzip_with_busybox() {
    busybox unzip "$1" -d "$2" > /dev/null 2>&1
}

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

backup_and_remove_ui() {
    if [ -d "$UI_DIR" ]; then
        echo "备份当前ui文件夹..."
        mv "$UI_DIR" "$BACKUP_DIR/$(date +%Y%m%d%H%M%S)_ui"
        echo "已备份至 $BACKUP_DIR"
    fi
}

download_and_process_ui() {
    local url="$1"
    local temp_file="$TEMP_DIR/ui.zip"
    
    # 清理临时目录
    rm -rf "${TEMP_DIR:?}"/*
    
    echo "正在下载面板..."
    curl -L "$url" -o "$temp_file"
    if [ $? -ne 0 ]; then
        echo "下载失败，正在还原备份..."
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi

    # 解压文件
    echo "解压中..."
    if unzip_with_busybox "$temp_file" "$TEMP_DIR"; then
        # 确保目标目录存在
        mkdir -p "$UI_DIR"
        rm -rf "${UI_DIR:?}"/*
        mv "$TEMP_DIR"/*/* "$UI_DIR"
        echo "面板安装完成"
        return 0
    else
        echo "解压失败，正在还原备份..."
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi
}

install_default_ui() {
    echo "正在安装默认ui面板..."
    DOWNLOAD_URL=$(get_download_url)
    backup_and_remove_ui
    download_and_process_ui "$DOWNLOAD_URL"
}

install_selected_ui() {
    local url="$1"
    backup_and_remove_ui
    download_and_process_ui "$url"
}

check_ui() {
    if [ -d "$UI_DIR" ] && [ "$(ls -A "$UI_DIR")" ]; then
        echo -e "\e[32mui面板已安装\e[0m"  # 绿色
    else
        echo -e "\e[31mui面板未安装或为空\e[0m"  # 红色
    fi
}

update_ui() {
    while true; do
        echo "请选择功能："
        echo "1. 默认ui（依据配置文件）"
        echo "2. 安装/更新自选ui"
        echo "3. 检查是否存在ui面板"
        echo "按回车键退出"
        read -r -p "请输入选项（1/2/3）或按回车键退出: " choice

        if [ -z "$choice" ]; then
            echo "退出程序。"
            exit 0
        fi

        case "$choice" in
            1)
                install_default_ui
                ;;
            2)
                echo "请选择面板安装："
                echo "1. metacubexd面板"
                echo "2. zashboard面板"
                echo "3. yacd面板"
                read -r -p "请输入选项（1/2/3）: " ui_choice

                case "$ui_choice" in
                    1)
                        install_selected_ui "$METACUBEXD_URL"
                        ;;
                    2)
                        install_selected_ui "$ZASHBOARD_URL"
                        ;;
                    3)
                        install_selected_ui "$YACD_URL"
                        ;;
                    *)
                        echo -e "\033[31m无效选项，返回上级菜单。\033[0m"
                        ;;
                esac
                ;;
            3)
                check_ui
                ;;
            *)
                echo "无效选项，返回主菜单"
                ;;
        esac
    done
}

update_ui