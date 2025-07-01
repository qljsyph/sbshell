#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box 已安装，跳过安装步骤${NC}"
else
    # 添加官方 GPG 密钥和仓库
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
" | sudo tee /etc/apt/sources.list.d/sagernet.sources > /dev/null

    # 始终更新包列表
    echo "正在更新包列表，请稍候..."
    sudo apt-get update -qq > /dev/null 2>&1

    # 选择安装稳定版或测试版
    while true; do
        read -rp "请选择安装版本(1: 稳定版, 2: 测试版): " version_choice
        case $version_choice in
            1)
                echo "安装稳定版..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                echo "安装已完成"
                break
                ;;
            2)
                echo "安装测试版..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                echo "安装已完成"
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1 或 2。${NC}"
                ;;
        esac
    done

    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box 安装成功，版本：${NC} $sing_box_version"
         
        if ! id sing-box &>/dev/null; then
            echo "正在创建 sing-box 系统用户"
            sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
        fi
        echo "正在设置sing-box权限..."
        sudo mkdir -p /var/lib/sing-box
        sudo chown -R sing-box:sing-box /var/lib/sing-box
        sudo chown -R sing-box:sing-box /etc/sing-box
    else
        echo -e "${RED}sing-box 安装失败，请检查日志或网络配置${NC}"
    fi
fi
