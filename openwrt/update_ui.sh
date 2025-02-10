#!/bin/bash

UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"
TEMP_DIR="/tmp/sing-box-ui"

ZASHBOARD_URL="https://ghfast.top/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD_URL="https://ghfast.top/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD_URL="https://ghfast.top/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 创建备份目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 检查依赖并安装
check_and_install_dependencies() {
    if ! command -v busybox &> /dev/null; then
        echo -e "\e[31mbusybox 未安装，正在安装...\e[0m"
        opkg update
        opkg install busybox
        export PATH=$PATH:/bin/busybox
        chmod +x /bin/busybox
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

    /etc/init.d/cron restart
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

    apply_firewall

    # 启动 sing-box 服务
    sing-box run -c /etc/sing-box/config.json &>/dev/null &

    sleep 2  # 等待 sing-box 启动

    if pgrep -x "sing-box" > /dev/null; then
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

update_ui