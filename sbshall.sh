#!/bin/bash

# 定义主脚本的下载URL
MAIN_SCRIPT_URL="https://ghproxy.cc/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/debian/menu.sh"

# 脚本下载目录
SCRIPT_DIR="/etc/sing-box/scripts"

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sudo 是否安装
if ! command -v sudo &> /dev/null; then
    echo -e "${RED}sudo 未安装。${NC}"
    read -rp "是否安装 sudo?(y/n): " install_sudo
    if [[ "$install_sudo" =~ ^[Yy]$ ]]; then
        apt-get update
        apt-get install -y sudo
        if ! command -v sudo &> /dev/null; then
            echo -e "${RED}安装 sudo 失败，请手动安装 sudo 并重新运行此脚本。${NC}"
            exit 1
        fi
        echo -e "${GREEN}sudo 安装成功。${NC}"
    else
        echo -e "${RED}由于未安装 sudo,脚本无法继续运行。${NC}"
        exit 1
    fi
fi

# 需要检测的依赖项列表
DEPENDENCIES=("wget" "nftables")

# 检查并安装缺失的依赖项
for DEP in "${DEPENDENCIES[@]}"; do
    if [ "$DEP" == "nftables" ]; then
        CHECK_CMD="nft --version"
    else
        CHECK_CMD="wget --version"
    fi

    if ! $CHECK_CMD &> /dev/null; then
        echo -e "${RED}$DEP 未安装。${NC}"
        read -rp "是否安装 $DEP?(y/n): " install_dep
        if [[ "$install_dep" =~ ^[Yy]$ ]]; then
            sudo apt-get update
            sudo apt-get install -y "$DEP"
            if ! $CHECK_CMD &> /dev/null; then
                echo -e "${RED}安装 $DEP 失败，请手动安装 $DEP 并重新运行此脚本。${NC}"
                exit 1
            fi
            echo -e "${GREEN}$DEP 安装成功。${NC}"
        else
            echo -e "${RED}由于未安装 $DEP,脚本无法继续运行。${NC}"
            exit 1
        fi
    fi
done

# 检查系统是否支持
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}当前系统不支持运行此脚本。${NC}"
    exit 1
fi

# 检查发行版
if grep -qi 'debian' /etc/os-release; then
    echo -e "${GREEN}系统为Debian,支持运行此脚本。${NC}"
elif grep -qi 'ubuntu' /etc/os-release; then
    echo -e "${GREEN}系统为Ubuntu,支持运行此脚本。${NC}"
elif grep -qi 'armbian' /etc/os-release; then
    echo -e "${GREEN}系统为Armbian,支持运行此脚本。${NC}"
elif grep -qi 'openwrt' /etc/os-release; then
    echo "系统为OpenWRT,未来版本支持。"
    # 在这里预留OpenWRT的操作
    echo -e "${RED}OpenWRT版本尚未支持,敬请期待。${NC}"
    exit 1
else
    echo -e "${RED}当前系统不是Debian/Ubuntu/Armbian,不支持运行此脚本。${NC}"
    exit 1
fi

# 确保脚本目录存在并设置权限
sudo mkdir -p "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"

# 下载并执行主脚本
wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"
echo -e "${GREEN}脚本下载中,请耐心等待...${NC}"
echo -e "${YELLOW}注意:安装更新singbox尽量使用代理环境,运行singbox切记关闭代理!${NC}"

if ! [ -f "$SCRIPT_DIR/menu.sh" ]; then
    echo -e "${RED}下载主脚本失败,请检查网络连接。${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/menu.sh"
bash "$SCRIPT_DIR/menu.sh"
