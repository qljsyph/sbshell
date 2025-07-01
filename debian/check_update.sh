#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "正在检测sing-box最新版本..."
sudo apt-get update -qq > /dev/null 2>&1

if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "${CYAN}当前安装的sing-box版本为:${NC} $current_version"
    
    stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
    beta_version=$(apt-cache policy sing-box-beta | grep Candidate | awk '{print $2}')
    
    echo -e "${CYAN}稳定版最新版本：${NC} $stable_version"
    echo -e "${CYAN}测试版最新版本：${NC} $beta_version"
    
    while true; do
        read -rp "是否切换版本(1: 稳定版, 2: 测试版） (当前版本: $current_version, 回车取消操作): " switch_choice
        case $switch_choice in
            1)
                echo "下载稳定版..."
                apt-get download sing-box
                sudo apt-get remove --auto-remove sing-box-beta -y
                sudo dpkg -i sing-box_*.deb
                rm -f sing-box_*.deb
                break
                ;;
            2)
                echo "下载测试版..."
                apt-get download sing-box-beta
                sudo apt-get remove --auto-remove sing-box -y
                sudo dpkg -i sing-box-beta_*.deb
                rm -f sing-box-beta_*.deb
                break
                ;;
            '')
                echo "不进行版本切换"
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1 或 2。${NC}"
                ;;
        esac
    done
else
    echo -e "${RED}sing-box 未安装${NC}"
fi
