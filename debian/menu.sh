#!/bin/bash

#################################################
# 描述: Debian/Ubuntu/Armbian 官方sing-box 全自动脚本
# 版本: 3.0.0
# 说明: Sing-box 服务管理脚本，提供客户端和服务端模式。
#################################################

# --- 1. 全局变量和颜色定义 ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
SCRIPT_DIR="/etc/sing-box/scripts"
INITIALIZED_FILE="$SCRIPT_DIR/.initialized"
ROLE_FILE="$SCRIPT_DIR/.role"
BASE_URL="https://ghfast.top/https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/3.0.0/debian"
ROLE="" # 运行角色: client 或 server

# 脚本功能列表，按功能分组
SCRIPTS=(
    # --- 核心与安装 ---
    "menu.sh"                  # 主菜单
    "install_singbox.sh"       # 安装/更新 sing-box
    "check_update.sh"          # 检查 sing-box 更新
    "update_scripts.sh"        # 更新所有管理脚本
    "update_ui.sh"             # 更新 Web 控制面板 (Yacd)

    # --- 客户端配置 ---
    "manual_input.sh"          # 手动输入订阅链接
    "manual_update.sh"         # 手动更新配置文件
    "auto_update.sh"           # 配置订阅自动更新
    "switch_mode.sh"           # 切换 TProxy / TUN 模式
    "configure_tproxy.sh"      # 配置 TProxy
    "configure_tun.sh"         # 配置 TUN

    # --- 服务端配置 ---
    "update_config.sh"         # 更新服务端配置文件
    "setup.sh"                 # (服务端) 依赖安装和证书申请
    "ufw.sh"                   # (服务端) 防火墙配置

    # --- 服务管理 ---
    "start_singbox.sh"         # 启动 sing-box
    "stop_singbox.sh"          # 停止 sing-box
    "manage_autostart.sh"      # 管理开机自启
    "check_config.sh"          # 检查配置文件语法

    # --- 系统与网络 ---
    "check_environment.sh"     # 检查系统环境
    "set_network.sh"           # 配置网络接口
    "clean_nft.sh"             # 清理 nftables 规则
    "kernel.sh"                # 更换/管理系统内核
    "optimize.sh"              # 网络性能优化
    "set_defaults.sh"          # 设置脚本默认参数
    "delaytest.sh"             # 外网延迟测试脚本
    "commands.sh"              # 常用命令速查
)

# --- 2. 辅助函数 ---

# 带有状态提示的脚本执行器
# 用法: run_script "提示信息" "脚本名" ["--quiet"]
run_script() {
    local message="$1"
    local script_name="$2"
    local quiet_mode="$3"
    
    echo -e "${CYAN}${message}...${NC}"
    if [ "$quiet_mode" == "--quiet" ]; then
        bash "$SCRIPT_DIR/$script_name" >/dev/null
    else
        bash "$SCRIPT_DIR/$script_name"
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}${message}失败！${NC}"
        return 1
    else
        # 对于非静默模式，成功信息由子脚本自己提供
        if [ "$quiet_mode" == "--quiet" ]; then
            echo -e "${GREEN}${message}成功。${NC}"
        fi
        return 0
    fi
}

# 带有状态提示的 systemctl 命令执行器
# 用法: run_systemctl "提示信息" "操作"
run_systemctl() {
    local message="$1"
    local action="$2"

    echo -e "${CYAN}${message}...${NC}"
    if sudo systemctl "$action" sing-box >/dev/null 2>&1; then
        echo -e "${GREEN}${message}成功。${NC}"
        return 0
    else
        echo -e "${RED}${message}失败！${NC}"
        return 1
    fi
}

# --- 3. 脚本下载与准备 ---

# 下载单个脚本
download_script() {
    local script="$1"
    local retries=3
    for ((i=1; i<=retries; i++)); do
        if wget -q -O "$SCRIPT_DIR/$script" "$BASE_URL/$script"; then
            chmod +x "$SCRIPT_DIR/$script"
            return 0
        fi
        sleep 2
    done
    echo -e "${YELLOW}下载 $script 失败 (尝试 $retries 次)。${NC}"
    return 1
}

# 并行下载所有脚本
parallel_download_scripts() {
    echo -e "${CYAN}开始下载所有必需脚本...${NC}"
    local pids=()
    local failed_scripts=()
    for script in "${SCRIPTS[@]}"; do
        download_script "$script" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            failed_scripts+=("1")
        fi
    done
    if [ ${#failed_scripts[@]} -ne 0 ]; then
        echo -e "${RED}一个或多个脚本下载失败，请检查网络并重试。${NC}"
        return 1
    fi
    echo -e "${GREEN}所有脚本下载完成。${NC}"
    return 0
}

# 检查并按需下载缺失的脚本
check_and_download_scripts() {
    local missing_scripts=()
    for script in "${SCRIPTS[@]}"; do
        [ ! -f "$SCRIPT_DIR/$script" ] && missing_scripts+=("$script")
    done

    if [ ${#missing_scripts[@]} -ne 0 ]; then
        echo -e "${YELLOW}发现缺失脚本，正在尝试下载...${NC}"
        for script in "${missing_scripts[@]}"; do
            download_script "$script"
        done
    fi
}

# 清理旧脚本并下载最新版本
prepare_scripts() {
    echo -e "${CYAN}正在清理旧脚本...${NC}"
    find "$SCRIPT_DIR" -type f -name "*.sh" ! -name "menu.sh" -exec rm -f {} \;
    rm -f "$INITIALIZED_FILE"
    parallel_download_scripts
}

# --- 4. 初始化流程 ---

# 客户端初始化
client_initialize() {
    echo -e "${CYAN}--- 开始客户端初始化 ---${NC}"
    prepare_scripts || exit 1
    run_script "检查系统环境" "check_environment.sh" --quiet
    run_script "安装/更新 sing-box" "install_singbox.sh" --quiet
    run_script "配置代理模式" "switch_mode.sh"
    run_script "配置订阅链接" "manual_input.sh"
    run_script "启动 sing-box" "start_singbox.sh" --quiet
    echo -e "${GREEN}--- 客户端初始化完成 ---${NC}"
}

# 服务端初始化
server_initialize() {
    echo -e "${CYAN}--- 开始服务端初始化 ---${NC}"
    prepare_scripts || exit 1
    run_script "配置防火墙" "ufw.sh" "--auto"
    run_script "安装/更新 sing-box" "install_singbox.sh" --quiet
    run_script "更新服务端配置" "update_config.sh"
    run_systemctl "启动 sing-box 服务" "start"
    echo -e "${GREEN}--- 服务端初始化完成 ---${NC}"
}

# --- 5. 主逻辑 ---

# 角色选择
select_role() {
    echo -e "${CYAN}请选择运行角色: [1] 客户端 [2] 服务端${NC}"
    read -rp "输入数字选择: " role_choice
    case $role_choice in
        1) ROLE="client" ;;
        2) ROLE="server" ;;
        *) echo -e "${YELLOW}无效选择，默认为客户端。${NC}"; ROLE="client" ;;
    esac
    echo "$ROLE" > "$ROLE_FILE"
}

# 初始化检查与执行
run_initialization() {
    # 首先选择角色
    select_role

    echo -e "${YELLOW}为 '$ROLE' 角色进行首次初始化。${NC}"
    echo "初始化将自动完成环境检查、sing-box安装、配置等步骤。"
    read -rp "按回车开始，或输入 'skip' 仅下载脚本进入菜单: " init_choice
    
    if [[ "$init_choice" =~ ^[Ss]kip$ ]]; then
        echo -e "${CYAN}跳过初始化，仅下载脚本...${NC}"
        parallel_download_scripts
    else
        if [ "$ROLE" = "server" ]; then
            server_initialize
        else
            client_initialize
        fi
        touch "$INITIALIZED_FILE" # 成功后创建标记
    fi
}

# 创建别名
setup_alias() {
    if ! grep -q "alias sb=" ~/.bashrc; then
        echo -e "\n# sing-box 快捷方式\nalias sb='bash $SCRIPT_DIR/menu.sh'" >> ~/.bashrc
        echo -e "${GREEN}已添加 'sb' 快捷命令到 .bashrc，请运行 'source ~/.bashrc' 或重新登录生效。${NC}"
    fi
    if [ ! -f /usr/local/bin/sb ]; then
        echo -e '#!/bin/bash\nbash /etc/sing-box/scripts/menu.sh "$@"' | sudo tee /usr/local/bin/sb >/dev/null
        sudo chmod +x /usr/local/bin/sb
    fi
}

# --- 6. 菜单定义与处理 ---

# 客户端菜单
show_client_menu() {
    echo -e "\n${CYAN}================= 客户端管理菜单 =================${NC}"
    echo -e "${YELLOW}--- 配置管理 ---${NC}"
    echo -e "${GREEN} 1. 模式切换与配置${NC}"
    echo -e "${GREEN} 2. 手动更新配置${NC}"
    echo -e "${GREEN} 3. 自动更新配置${NC}"
    echo -e "${GREEN} 4. 设置默认参数${NC}"
    echo -e "${YELLOW}--- 服务控制 ---${NC}"
    echo -e "${GREEN} 5. 启动sing-box${NC}"
    echo -e "${GREEN} 6. 停止sing-box${NC}"
    echo -e "${GREEN} 7. 管理自启动${NC}"
    echo -e "${YELLOW}--- 更新与维护 ---${NC}"
    echo -e "${GREEN} 8. 更新sing-box${NC}"
    echo -e "${GREEN} 9. 更新脚本${NC}"
    echo -e "${GREEN}10. 更新面板${NC}"
    echo -e "${YELLOW}--- 系统与网络 ---${NC}"
    echo -e "${GREEN}11. 网络设置${NC}"
    echo -e "${GREEN}12. 常用命令${NC}"
    echo -e "${GREEN}13. 更换XanMod内核${NC}"
    echo -e "${GREEN}14. 网络优化${NC}"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    echo -e "${GREEN} 0. 退出${NC}"
    echo -e "${CYAN}====================================================${NC}"
}

handle_client_choice() {
    read -rp "请选择操作: " choice
    case $choice in
        1) run_script "配置代理模式" "switch_mode.sh"; run_script "配置订阅链接" "manual_input.sh"; run_script "启动 sing-box" "start_singbox.sh" --quiet ;;
        2) run_script "手动更新配置" "manual_update.sh" ;;
        3) run_script "自动更新配置" "auto_update.sh" ;;
        4) run_script "设置默认参数" "set_defaults.sh" ;;
        5) run_script "启动sing-box" "start_singbox.sh" --quiet ;;
        6) run_script "停止sing-box" "stop_singbox.sh" --quiet ;;
        7) run_script "管理自启动" "manage_autostart.sh" ;;
        8) if command -v sing-box &> /dev/null; then
               run_script "检查 sing-box 更新" "check_update.sh"
           else
               run_script "安装/更新 sing-box" "install_singbox.sh"
           fi
           ;;
        9) run_script "更新所有脚本" "update_scripts.sh" ;;
        10) run_script "更新控制面板" "update_ui.sh" ;;
        11) run_script "网络设置" "set_network.sh" ;;
        12) run_script "常用命令" "commands.sh" ;;
        13) run_script "更换XanMod内核" "kernel.sh" ;;
        14) run_script "网络优化" "optimize.sh" ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效的选择${NC}" ;;
    esac
}

# 服务端菜单
show_server_menu() {
    echo -e "\n${CYAN}================= 服务端管理菜单 =================${NC}"
    echo -e "${YELLOW}--- 服务控制 ---${NC}"
    echo -e "${GREEN} 1. 启动sing-box${NC}"
    echo -e "${GREEN} 2. 停止sing-box${NC}"
    echo -e "${GREEN} 3. 重启sing-box${NC}"
    echo -e "${GREEN} 4. 设为自启${NC}"
    echo -e "${GREEN} 5. 查看日志${NC}"
    echo -e "${YELLOW}--- 配置与更新 ---${NC}"
    echo -e "${GREEN} 6. 更新配置文件${NC}"
    echo -e "${GREEN} 7. 更新sing-box${NC}"
    echo -e "${GREEN} 8. 更新脚本${NC}"
    echo -e "${GREEN} 9. 证书申请${NC}"
    echo -e "${YELLOW}--- 系统与网络 ---${NC}"
    echo -e "${GREEN}10. 更换XanMod内核${NC}"
    echo -e "${GREEN}11. 网络优化${NC}"
    echo -e "${GREEN}12. 手动配置防火墙${NC}"
    echo -e "${CYAN}----------------------------------------------------${NC}"
    echo -e "${GREEN} 0. 退出${NC}"
    echo -e "${CYAN}====================================================${NC}"
}

handle_server_choice() {
    read -rp "请选择操作: " choice
    case $choice in
        1) run_systemctl "启动sing-box" "start" ;;
        2) run_systemctl "停止sing-box" "stop" ;;
        3) run_systemctl "重启sing-box" "restart" ;;
        4) run_systemctl "设置开机自启" "enable" ;;
        5) sudo journalctl -u sing-box --output cat -f ;;
        6) run_script "更新服务端配置文件" "update_config.sh" ;;
        7) if command -v sing-box &> /dev/null; then
               run_script "检查 sing-box 更新" "check_update.sh"
           else
               run_script "安装/更新 sing-box" "install_singbox.sh"
           fi
           ;;
        8) run_script "更新脚本" "update_scripts.sh" ;;
        9) run_script "证书申请" "setup.sh" ;;
        10) run_script "更换XanMod内核" "kernel.sh" ;;
        11) run_script "网络优化" "optimize.sh" ;;
        12) run_script "手动配置防火墙" "ufw.sh" ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效的选择${NC}" ;;
    esac
}

# --- 7. 脚本入口 ---

main() {
    # 确保脚本目录存在
    sudo mkdir -p "$SCRIPT_DIR"
    sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"
    cd "$SCRIPT_DIR" || exit 1

    # 如果通过快捷方式 sb 调用，则第一个参数可能是菜单选项
    if [ "$1" == "menu" ]; then
        shift
    fi

    # 检查是否已经初始化过
    if [ ! -f "$INITIALIZED_FILE" ]; then
        run_initialization
    else
        # 如果已经初始化，加载角色并检查脚本
        if [ -f "$ROLE_FILE" ]; then
            ROLE=$(cat "$ROLE_FILE")
        else
            # 兼容旧版本，如果 .initialized 存在但 .role 不存在
            echo -e "${YELLOW}角色文件丢失，将引导您重新初始化。${NC}"
            sudo rm -f "$INITIALIZED_FILE"
            run_initialization
        fi
        check_and_download_scripts
    fi

    # 如果初始化流程被跳过或失败，ROLE 可能为空
    if [ -z "$ROLE" ]; then
        # 尝试从文件再次加载角色，以防 'skip' 初始化后直接运行
        if [ -f "$ROLE_FILE" ]; then
            ROLE=$(cat "$ROLE_FILE")
        else
            echo -e "${RED}未设置角色，无法继续。请重新运行以完成初始化。${NC}"
            exit 1
        fi
    fi

    # 设置别名
    setup_alias

    # 进入主循环
    if [ "$ROLE" = "server" ]; then
        while true; do show_server_menu; handle_server_choice; done
    else
        while true; do show_client_menu; handle_client_choice; done
    fi
}

# 执行主函数
main "$@"