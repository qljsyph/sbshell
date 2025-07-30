#!/bin/bash
#
# 一键申请 SSL 证书脚本 (默认使用 Let's Encrypt)
#

# --- 脚本设置与错误处理 ---
set -eEuo pipefail
# 在发生错误时，将错误信息输出到 stderr 并退出
# `$BASH_SOURCE` 和 `$LINENO` 用于指示错误发生的脚本文件和行号
trap 'echo -e "\033[31m❌ 脚本在 [\033[1m\$BASH_SOURCE:\$LINENO\033[0m\033[31m] 行发生错误\033[0m" >&2; exit 1' ERR

# --- ANSI 颜色代码 ---
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BOLD='\033[1m'
RESET='\033[0m'

# --- 全局变量 ---
DOMAIN=""
EMAIL=""
CA_SERVER="letsencrypt"
OS_TYPE=""
PKG_MANAGER=""
ACME_INSTALL_PATH="$HOME/.acme.sh"
CERT_KEY_DIR="" # 动态设置为 /etc/ssl/您的域名/
ACME_CMD="" # 动态查找的 acme.sh 命令路径

# --- 函数定义 ---

# 检查并确保以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ 错误：请使用 root 权限运行此脚本。${RESET}" >&2
        exit 1
    fi
    echo -e "${GREEN}✅ Root 权限检查通过。${RESET}"
}

# 获取用户输入并校验格式
get_user_input() {
    read -r -p "请输入域名: " DOMAIN
    if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo -e "${RED}❌ 错误：域名格式不正确！${RESET}" >&2; exit 1;
    fi

    read -r -p "请输入电子邮件地址: " EMAIL
    if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ 错误：电子邮件格式不正确！${RESET}" >&2; exit 1;
    fi

    echo -e "${GREEN}✅ 用户信息收集完成 (默认使用 Let's Encrypt)。${RESET}"
}

# 检测操作系统并设置相关变量
detect_os() {
    if grep -qi "ubuntu" /etc/os-release; then
        OS_TYPE="ubuntu"; PKG_MANAGER="apt"
    elif grep -qi "debian" /etc/os-release; then
        OS_TYPE="debian"; PKG_MANAGER="apt"
    elif grep -qi "centos" /etc/os-release; then
        OS_TYPE="centos"; PKG_MANAGER="yum"
    elif grep -qi "rhel" /etc/os-release; then
        OS_TYPE="rhel"; PKG_MANAGER="yum"
    else
        echo -e "${RED}❌ 错误：不支持的操作系统！${RESET}" >&2; exit 1
    fi
    echo -e "${GREEN}✅ 检测到操作系统: $OS_TYPE ($PKG_MANAGER)。${RESET}"
}

# 安装依赖
install_dependencies() {
    local dependencies=()

    if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then
        dependencies=("curl" "socat" "cron" "ufw")
    elif [[ "$OS_TYPE" == "centos" || "$OS_TYPE" == "rhel" ]]; then
        dependencies=("curl" "socat" "cronie" "firewalld")
    else
        echo -e "${RED}❌ 错误：不支持的操作系统！${RESET}" >&2
        exit 1
    fi

    for pkg in "${dependencies[@]}"; do
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            if ! dpkg -s "$pkg" &>/dev/null; then
                echo -e "${YELLOW}安装依赖: $pkg...${RESET}"
                sudo apt install -y "$pkg" >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：安装 $pkg 失败${RESET}" >&2; exit 1; }
            fi
        elif [[ "$PKG_MANAGER" == "yum" ]]; then
            if ! rpm -q "$pkg" &>/dev/null; then
                echo -e "${YELLOW}安装依赖: $pkg...${RESET}"
                sudo yum install -y "$pkg" >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：安装 $pkg 失败${RESET}" >&2; exit 1; }
            fi
        fi
    done
    echo -e "${GREEN}✅ 依赖安装完成。${RESET}"
}


configure_firewall() {
    local firewall_cmd=""
    local firewall_service_name=""
    local ssh_port=""

    # 提示用户输入 SSH 端口
    read -r -p "请输入需要开放的 SSH 端口,否则可能导致SSH无法连接（默认 22）: " ssh_port
    ssh_port=${ssh_port:-22} # 如果用户未输入，默认使用 22 端口

    if [[ "$OS_TYPE" == "ubuntu" || "$OS_TYPE" == "debian" ]]; then
        firewall_cmd="ufw"
        firewall_service_name="ufw"
        if sudo "$firewall_cmd" status | grep -q "inactive"; then
            echo "y" | sudo "$firewall_cmd" enable >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：UFW 启用失败${RESET}" >&2; exit 1; }
        fi
        # 检查并开放用户指定的 SSH 端口
        if ! sudo "$firewall_cmd" status | grep -q "$ssh_port/tcp"; then
            sudo "$firewall_cmd" allow "$ssh_port"/tcp comment 'Allow SSH' >/dev/null || echo -e "${YELLOW}警告: 无法添加 UFW $ssh_port/tcp 规则。${RESET}" >&2
        fi
        # 检查并开放 HTTP 和 HTTPS 端口
        if ! sudo "$firewall_cmd" status | grep -q "80/tcp"; then
            sudo "$firewall_cmd" allow 80/tcp comment 'Allow HTTP' >/dev/null || echo -e "${YELLOW}警告: 无法添加 UFW 80/tcp 规则。${RESET}" >&2
        fi
        if ! sudo "$firewall_cmd" status | grep -q "443/tcp"; then
            sudo "$firewall_cmd" allow 443/tcp comment 'Allow HTTPS' >/dev/null || echo -e "${YELLOW}警告: 无法添加 UFW 443/tcp 规则。${RESET}" >&2
        fi
        echo -e "${GREEN}✅ UFW 已配置开放 $ssh_port, 80 和 443 端口。${RESET}"

    elif [[ "$OS_TYPE" == "centos" || "$OS_TYPE" == "rhel" ]]; then
        firewall_cmd="firewall-cmd"
        firewall_service_name="firewalld"
        sudo systemctl is-active --quiet "$firewall_service_name" || { echo "  启动 Firewalld..."; sudo systemctl start "$firewall_service_name" >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：Firewalld 启动失败${RESET}" >&2; exit 1; }; }
        # 检查并开放用户指定的 SSH 端口
        if ! sudo "$firewall_cmd" --query-port="$ssh_port"/tcp >/dev/null 2>&1; then
            sudo "$firewall_cmd" --zone=public --add-port="$ssh_port"/tcp --permanent >/dev/null || echo -e "${YELLOW}警告: 无法添加 Firewalld $ssh_port/tcp 规则。${RESET}" >&2
        fi
        # 检查并开放 HTTP 和 HTTPS 端口
        if ! sudo "$firewall_cmd" --query-port=80/tcp >/dev/null 2>&1; then
            sudo "$firewall_cmd" --zone=public --add-port=80/tcp --permanent >/dev/null || echo -e "${YELLOW}警告: 无法添加 Firewalld 80/tcp 规则。${RESET}" >&2
        fi
        if ! sudo "$firewall_cmd" --query-port=443/tcp >/dev/null 2>&1; then
            sudo "$firewall_cmd" --zone=public --add-port=443/tcp --permanent >/dev/null || echo -e "${YELLOW}警告: 无法添加 Firewalld 443/tcp 规则。${RESET}" >&2
        fi
        sudo "$firewall_cmd" --reload >/dev/null || echo -e "${YELLOW}警告: Firewalld 配置重载失败。${RESET}" >&2
        echo -e "${GREEN}✅ Firewalld 已配置开放 $ssh_port, 80 和 443 端口。${RESET}"

    else
        echo -e "${YELLOW}警告: 未识别的防火墙服务，请手动开放端口 $ssh_port, 80 和 443。${RESET}" >&2
    fi
}

# 下载安装 acme.sh
download_acme() {
    if [ ! -d "$ACME_INSTALL_PATH" ]; then
        curl -fsSL https://get.acme.sh | sh -s -- home "$ACME_INSTALL_PATH" >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：下载 acme.sh 失败，请检查网络连接${RESET}" >&2; exit 1; }
        echo -e "${GREEN}✅ acme.sh 下载完成。${RESET}"
    else
        true
    fi
}

# 查找 acme.sh 命令路径
find_acme_cmd() {
    export PATH="$ACME_INSTALL_PATH:$PATH"
    ACME_CMD=$(command -v acme.sh)
    if [ -z "$ACME_CMD" ]; then
        echo -e "${RED}❌ 错误：找不到 acme.sh 命令。请检查安装或 PATH。${RESET}" >&2
        exit 1
    fi
    echo -e "${GREEN}✅ 找到 acme.sh 可执行文件。${RESET}"
}

# 更新 acme.sh
update_acme() {
    "$ACME_CMD" --upgrade >/dev/null 2>&1 || echo -e "${YELLOW}警告：acme.sh 更新失败${RESET}" >&2
    "$ACME_CMD" --update-account --days 60 >/dev/null 2>&1 || echo -e "${YELLOW}警告：acme.sh 账户信息更新失败${RESET}" >/dev/null
    echo -e "${GREEN}✅ acme.sh 更新完成。${RESET}"
}

# 申请 SSL 证书
issue_cert() {
    # !!! 请注意: --pre-hook 和 --post-hook 适用于常见的 Web 服务器 (nginx, apache2)。
    # !!! 如果您使用其他 Web 服务器或不需要停止/启动，请根据实际情况修改或移除这些 hook。
    # !!! Standalone 模式需要确保 80 端口在验证时可用。
    # !!! 添加 --force 参数以强制覆盖可能已存在的域密钥
    if ! "$ACME_CMD" --issue --standalone -d "$DOMAIN" --server "$CA_SERVER" --force \
        --pre-hook "systemctl stop nginx 2>/dev/null || systemctl stop apache2 2>/dev/null || true" \
        --post-hook "systemctl start nginx 2>/dev/null || systemctl start apache2 2>/dev/null || true" >/dev/null 2>&1; then
        echo -e "${RED}❌ 错误：证书申请失败。${RESET}" >&2
        echo "  正在进行清理..." >&2
        "$ACME_CMD" --revoke -d "$DOMAIN" --server "$CA_SERVER" >/dev/null 2>&1 || true
        "$ACME_CMD" --remove -d "$DOMAIN" --server "$CA_SERVER" >/dev/null 2>&1 || true
        exit 1
    fi
    echo -e "${GREEN}✅ 证书申请成功！${RESET}"
}

# 安装证书
install_cert() {
    # 设置统一的证书安装目录
    CERT_KEY_DIR="/etc/ssl/$DOMAIN"
    sudo mkdir -p "$CERT_KEY_DIR" >/dev/null 2>&1 || { echo -e "${RED}❌ 错误：创建证书目录失败${RESET}" >&2; exit 1; }

    # 使用动态找到的 acme.sh 命令进行安装到统一目录
    # !!! 注意 reloadcmd 需要根据 Web 服务器修改
    if sudo "$ACME_CMD" --installcert -d "$DOMAIN" \
        --key-file       "${CERT_KEY_DIR}/${DOMAIN}.key" \
        --fullchain-file "${CERT_KEY_DIR}/${DOMAIN}.crt" \
        --reloadcmd "systemctl reload nginx 2>/dev/null || systemctl reload apache2 2>/dev/null || true" >/dev/null 2>&1; then

        sudo chmod 600 "${CERT_KEY_DIR}/${DOMAIN}.key" >/dev/null 2>&1 || echo -e "${YELLOW}警告：设置私钥文件权限失败。${RESET}" >&2
        sudo chown root:root "${CERT_KEY_DIR}/${DOMAIN}.key" >/dev/null 2>&1 || echo -e "${YELLOW}警告：设置私钥文件所有者失败。${RESET}" >&2
        echo -e "${GREEN}✅ 证书安装完成。${RESET}"
    else
        echo -e "${RED}❌ 错误：证书安装失败！${RESET}" >&2
        exit 1
    fi
}

# --- 主体逻辑 ---

check_root
get_user_input
detect_os

echo "➡️ 依赖安装中..." >&2
install_dependencies
configure_firewall # 配置防火墙开放端口

download_acme
find_acme_cmd # 在调用 acme.sh 之前查找命令

update_acme # 更新 acme.sh

echo "➡️ 证书申请中..." >&2
issue_cert # 申请证书
install_cert # 安装证书并设置权限

echo "➡️ 配置自动续期..." >&2
# 调用 acme.sh 内置的安装 cronjob 功能，会自动设置定时任务
sudo "$ACME_CMD" --install-cronjob >/dev/null 2>&1 || echo -e "${YELLOW}警告：配置 acme.sh 自动续期任务失败。请手动运行 'sudo \$HOME/.acme.sh/acme.sh --install-cronjob' 进行配置。${RESET}" >&2

echo -e "${GREEN}✅ 自动续期已通过 acme.sh 内置功能配置。${RESET}" >&2 


echo "==============================================="
echo -e "${GREEN}✅ 脚本执行完毕。${RESET}"
echo "==============================================="
echo -e "${GREEN}证书文件: ${BOLD}${CERT_KEY_DIR}/${DOMAIN}.crt${RESET}"
echo -e "${GREEN}私钥文件: ${BOLD}${CERT_KEY_DIR}/${DOMAIN}.key${RESET}"
echo -e "${GREEN}自动续期已通过 acme.sh 内置功能配置完成。"
echo -e "${YELLOW}提示: 您可以通过 'sudo crontab -l'来检查任务是否成功设置。${RESET}" >&2

echo "==============================================="

exit 0