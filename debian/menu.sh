#!/bin/bash

#################################################
# 描述: Debian/Ubuntu/Armbian 官方sing-box 全自动脚本
# 版本: 2.1.1
#################################################

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 脚本下载目录和初始化标志文件
SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"

# 确保脚本目录存在并设置权限
sudo mkdir -p "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"

# 脚本的URL基础路径
BASE_URL="https://gh-proxy.com/https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/main/debian"
                               
# 脚本列表
SCRIPTS=(
    "check_environment.sh"     # 检查系统环境
    "set_network.sh"           # 配置网络设置
    "check_update.sh"          # 检查可用更新
    "install_singbox.sh"       # 安装 Sing-box
    "manual_input.sh"          # 手动输入配置
    "manual_update.sh"         # 手动更新配置
    "auto_update.sh"           # 自动更新配置
    "configure_tproxy.sh"      # 配置 TProxy 模式
    "configure_tun.sh"         # 配置 TUN 模式
    "start_singbox.sh"         # 手动启动 Sing-box
    "stop_singbox.sh"          # 手动停止 Sing-box
    "clean_nft.sh"             # 清理 nftables 规则
    "set_defaults.sh"          # 设置默认配置
    "commands.sh"              # 常用命令
    "switch_mode.sh"           # 切换代理模式
    "manage_autostart.sh"      # 设置自启动
    "check_config.sh"          # 检查配置文件
    "update_scripts.sh"        # 更新脚本
    "update_ui.sh"             # 控制面板安装/更新/检查
    "menu.sh"                  # 主菜单
)

# 下载并设置单个脚本，带重试和日志记录逻辑
download_script() {
    local SCRIPT="$1"
    local RETRIES=5  # 增加重试次数
    local RETRY_DELAY=5

    for ((i=1; i<=RETRIES; i++)); do
        if wget -q -O "$SCRIPT_DIR/$SCRIPT" "$BASE_URL/$SCRIPT"; then
            chmod +x "$SCRIPT_DIR/$SCRIPT"
            return 0
        else
            echo -e "${YELLOW}下载 $SCRIPT 失败，重试 $i/${RETRIES}...${NC}"
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

# 检查脚本完整性并下载缺失的脚本
check_and_download_scripts() {
    local missing_scripts=()
    for SCRIPT in "${SCRIPTS[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$SCRIPT" ]; then
            missing_scripts+=("$SCRIPT")
        fi
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        echo -e "${CYAN}正在下载脚本，请耐心等待...${NC}"
        for SCRIPT in "${missing_scripts[@]}"; do
            download_script "$SCRIPT" || {
                echo -e "${RED}下载 $SCRIPT 失败，是否重试？(y/n): ${NC}"
                read -r retry_choice
                if [[ "$retry_choice" =~ ^[Yy]$ ]]; then
                    download_script "$SCRIPT"
                else
                    echo -e "${RED}跳过 $SCRIPT 下载。${NC}"
                fi
            }
        done
    fi
}

# 初始化操作
initialize() {
    # 检查是否存在旧脚本
    if ls "$SCRIPT_DIR"/*.sh 1> /dev/null 2>&1; then
        find "$SCRIPT_DIR" -type f -name "*.sh" ! -name "menu.sh" -exec rm -f {} \;
        rm -f "$INITIALIZED_FILE"
    fi

    # 重新下载脚本
    parallel_download_scripts
    # 进行首次运行的其他初始化操作
    auto_setup
    touch "$INITIALIZED_FILE"
}

# 自动引导设置
auto_setup() {
    systemctl is-active --quiet sing-box && sudo systemctl stop sing-box
    bash "$SCRIPT_DIR/check_environment.sh"
    command -v sing-box &> /dev/null || bash "$SCRIPT_DIR/install_singbox.sh" || bash "$SCRIPT_DIR/check_update.sh"
    bash "$SCRIPT_DIR/switch_mode.sh"
    bash "$SCRIPT_DIR/manual_input.sh"
    bash "$SCRIPT_DIR/start_singbox.sh"
}

# 检查是否需要初始化
if [ ! -f "$INITIALIZED_FILE" ]; then
    echo -e "${CYAN}回车进入初始化引导设置,输入skip跳过引导${NC}"
    read -r init_choice
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        echo -e "${CYAN}跳过初始化引导，直接进入菜单...${NC}"
    else
        initialize
    fi
fi

# 添加别名到 .bashrc，如果已存在则不再添加
if ! grep -q "alias sb=" ~/.bashrc; then
    echo "alias sb='bash $SCRIPT_DIR/menu.sh menu'" >> ~/.bashrc
fi

# 创建快捷脚本
if [ ! -f /usr/local/bin/sb ]; then
    echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh menu' | sudo tee /usr/local/bin/sb >/dev/null
    sudo chmod +x /usr/local/bin/sb
fi

# 菜单显示
show_menu() {
    echo -e "${CYAN}=========== Sbshell 管理菜单 ===========${NC}"
    echo -e "${GREEN}1. Tproxy/Tun模式切换${NC}"
    echo -e "${GREEN}2. 手动更新配置文件${NC}"
    echo -e "${GREEN}3. 自动更新配置文件${NC}"
    echo -e "${GREEN}4. 手动启动 sing-box${NC}"
    echo -e "${GREEN}5. 手动停止 sing-box${NC}"
    echo -e "${GREEN}6. 安装/更新 sing-box${NC}"
    echo -e "${GREEN}7. 默认参数设置${NC}"
    echo -e "${GREEN}8. 设置自启动${NC}"
    echo -e "${GREEN}9. 网络设置(只支持debian)${NC}"
    echo -e "${GREEN}10. 常用命令${NC}"
    echo -e "${GREEN}11. 更新脚本${NC}"
    echo -e "${GREEN}12. 更新控制面板${NC}"
    echo -e "${GREEN}0. 退出${NC}"
    echo -e "${CYAN}=======================================${NC}"
}

# 处理用户选择
handle_choice() {
    read -rp "请选择操作: " choice
    case $choice in
        1)
            bash "$SCRIPT_DIR/switch_mode.sh"
            bash "$SCRIPT_DIR/manual_input.sh"
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/manual_update.sh"
            ;;
        3)
            bash "$SCRIPT_DIR/auto_update.sh"
            ;;
        4)
            bash "$SCRIPT_DIR/start_singbox.sh"
            ;;
        5)
            bash "$SCRIPT_DIR/stop_singbox.sh"
            ;;
        6)
            if command -v sing-box &> /dev/null; then
                bash "$SCRIPT_DIR/check_update.sh"
            else
                bash "$SCRIPT_DIR/install_singbox.sh"
            fi
            ;;
        7)
            bash "$SCRIPT_DIR/set_defaults.sh"
            ;;
        8)
            bash "$SCRIPT_DIR/manage_autostart.sh"
            ;;
        9)
            bash "$SCRIPT_DIR/set_network.sh"
            ;;
        10)
            bash "$SCRIPT_DIR/commands.sh"
            ;;
        11)
            bash "$SCRIPT_DIR/update_scripts.sh"
            ;;
        12)
            bash "$SCRIPT_DIR/update_ui.sh"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac
}

# 主循环
while true; do
    show_menu
    handle_choice
done
