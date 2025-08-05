#!/bin/bash

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"
TEMP_DIR="/tmp/sing-box-ui"

ZASHBOARD_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD_URL="https://ghfast.top/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD_URL="https://ghfast.top/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 检查依赖并安装
check_and_install_dependencies() {
    if ! command -v busybox &> /dev/null; then
        echo -e "\e[31mbusybox 未安装，正在安装...\e[0m"
        sudo apt-get update
        sudo apt-get install -y busybox
        export PATH=$PATH:/bin/busybox
        sudo chmod +x /bin/busybox
    fi
}

unzip_with_busybox() {
    busybox unzip "$1" -d "$2" > /dev/null 2>&1
}

get_download_url() {
    CONFIG_FILE="/etc/sing-box/config.json"
    DEFAULT_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
    
    if [ -f "$CONFIG_FILE" ]; then
        URL=$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "$CONFIG_FILE")
        echo "${URL:-$DEFAULT_URL}"
    else
        echo "$DEFAULT_URL"
    fi
}

backup_and_remove_ui() {
    if [ -d "$UI_DIR" ]; then
        echo -e "备份当前ui文件夹..."
        mv "$UI_DIR" "$BACKUP_DIR/$(date +%Y%m%d%H%M%S)_ui"
        echo -e "已备份至 $BACKUP_DIR"
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
        echo -e "\e[31m下载失败,正在还原备份...\e[0m"
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
        echo -e "\e[32m面板安装完成\e[0m"
        return 0
    else
        echo -e "\e[31m解压失败,正在还原备份...\e[0m"
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
        echo -e "\e[32mui面板已安装\e[0m"
    else
        echo -e "\e[31mui面板未安装或为空\e[0m"
    fi
}

setup_auto_update_ui() {
    local schedule_choice
    while true; do
        echo "请选择自动更新频率："
        echo "1. 每周一"
        echo "2. 每月1号"
        read -rp "请输入选项(1/2, 默认为1): " schedule_choice
        schedule_choice=${schedule_choice:-1}

        if [[ "$schedule_choice" =~ ^[12]$ ]]; then
            break
        else
            echo -e "\e[31m输入无效,请输入1或2。\e[0m"
        fi
    done

    if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-ui.sh'; then
        echo -e "\e[31m检测到已有自动更新任务。\e[0m"
        read -rp "是否重新设置自动更新任务？(y/n): " confirm_reset
        if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-ui.sh' | crontab -
            echo "已删除旧的自动更新任务。"
        else
            echo -e "\e[36m保持已有的自动更新任务。返回菜单。\e[0m"
            return
        fi
    fi

    # 创建自动更新脚本
    cat > /etc/sing-box/update-ui.sh <<EOF
#!/bin/bash

CONFIG_FILE="/etc/sing-box/config.json"
DEFAULT_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
URL=\$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "\$CONFIG_FILE")
URL="\${URL:-\$DEFAULT_URL}"

TEMP_DIR="/tmp/sing-box-ui"
UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"

# 创建备份目录
mkdir -p "\$BACKUP_DIR"
mkdir -p "\$TEMP_DIR"

# 备份当前ui文件夹
if [ -d "\$UI_DIR" ]; then
    mv "\$UI_DIR" "\$BACKUP_DIR/\$(date +%Y%m%d%H%M%S)_ui"
fi

# 下载并解压新ui
curl -L "\$URL" -o "\$TEMP_DIR/ui.zip"
if busybox unzip "\$TEMP_DIR/ui.zip" -d "\$TEMP_DIR"; then
    mkdir -p "\$UI_DIR"
    rm -rf "\${UI_DIR:?}"/*
    mv "\$TEMP_DIR"/*/* "\$UI_DIR"
else
    echo "解压失败，正在还原备份..."
    [ -d "\$BACKUP_DIR" ] && mv "\$BACKUP_DIR/"* "\$UI_DIR" 2>/dev/null
fi

EOF

    chmod a+x /etc/sing-box/update-ui.sh

    if [ "$schedule_choice" -eq 1 ]; then
        (crontab -l 2>/dev/null; echo "0 0 * * 1 /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32m定时更新任务已设置,每周一执行一次\e[0m"
    else
        (crontab -l 2>/dev/null; echo "0 0 1 * * /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32m定时更新任务已设置,每月1号执行一次\e[0m"
    fi

    systemctl restart cron
}

update_ui() {
    check_and_install_dependencies  # 检查并安装依赖
    while true; do
        echo "请选择功能："
        echo "1. 默认ui(依据配置文件）"
        echo "2. 安装/更新自选ui"
        echo "3. 检查是否存在ui面板"
        echo "4. 设置定时自动更新面板"
        read -r -p "请输入选项(1/2/3/4)或按回车键退出: " choice

        if [ -z "$choice" ]; then
            echo "退出程序。"
            exit 0
        fi

        case "$choice" in
            1)
                install_default_ui
                exit 0  # 更新结束后退出菜单
                ;;
            2)
                echo "请选择面板安装："
                echo "1. zashboard面板"
                echo "2. metacubexd面板"
                echo "3. yacd面板"
                read -r -p "请输入选项(1/2/3): " ui_choice

                case "$ui_choice" in
                    1)
                        install_selected_ui "$ZASHBOARD_URL"
                        ;;
                    2)
                        install_selected_ui "$METACUBEXD_URL"
                        ;;
                    3)
                        install_selected_ui "$YACD_URL"
                        ;;
                    *)
                        echo -e "\e[31m无效选项,返回上级菜单。\e[0m"
                        ;;
                esac
                exit 0  # 更新结束后退出菜单
                ;;
            3)
                check_ui
                ;;
            4)
                setup_auto_update_ui
                ;;
            *)
                echo -e "\e[31m无效选项,返回主菜单\e[0m"
                ;;
        esac
    done
}

update_ui