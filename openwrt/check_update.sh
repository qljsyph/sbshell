#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "正在检测sing-box最新版本..."
# 更新包信息
sudo apt-get update -qq > /dev/null 2>&1

# 检查sing-box版本
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "${CYAN}当前安装的sing-box版本为:${NC} $current_version"
    
    # 获取最新稳定版本和测试版本信息
    stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
    beta_version=$(apt-cache policy sing-box-beta | grep Candidate | awk '{print $2}')
    
    echo -e "${CYAN}稳定版最新版本：${NC} $stable_version"
    echo -e "${CYAN}测试版最新版本：${NC} $beta_version"
    
    # 提供切换版本的选项
    while true; do
        read -rp "是否切换版本(1: 稳定版, 2: 测试版） (当前版本: $current_version, 回车取消操作): " switch_choice
        case $switch_choice in
            1)
                echo "选择了切换到稳定版"
                sudo apt-get install sing-box -y
                break
                ;;
            2)
                echo "选择了切换到测试版"
                sudo apt-get install sing-box-beta -y
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
