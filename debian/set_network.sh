#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 捕获 Ctrl+C 信号并处理
trap "echo -e '\n${RED}操作已取消，返回到网络设置菜单。${NC}'; exit 1" SIGINT

# 获取当前系统的 IP 地址、网关和 DNS
CURRENT_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
CURRENT_GATEWAY=$(ip route show default | awk '{print $3}')
CURRENT_DNS=$(cat /etc/resolv.conf | grep 'nameserver' | awk '{print $2}')

echo -e "${YELLOW}当前 IP 地址: $CURRENT_IP${NC}"
echo -e "${YELLOW}当前网关地址: $CURRENT_GATEWAY${NC}"
echo -e "${YELLOW}当前 DNS 服务器: $CURRENT_DNS${NC}"

# 获取网卡名称
INTERFACE=$(ip -br link show | awk '{print $1}' | grep -v "lo" | head -n 1)
[ -z "$INTERFACE" ] && { echo -e "${RED}未找到网络接口，程序退出。${NC}"; exit 1; }

echo -e "${YELLOW}检测到的网络接口是: $INTERFACE${NC}"

while true; do
    # 提示用户输入静态 IP 地址、网关和 DNS
    read -p "请输入静态 IP 地址: " IP_ADDRESS
    read -p "请输入网关地址: " GATEWAY
    read -p "请输入 DNS 服务器地址 (多个地址用空格分隔): " DNS_SERVERS

    echo -e "${YELLOW}你输入的配置信息如下:${NC}"
    echo -e "IP 地址: $IP_ADDRESS"
    echo -e "网关地址: $GATEWAY"
    echo -e "DNS 服务器: $DNS_SERVERS"

    read -p "是否确认上述配置信息? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # 配置文件路径
        INTERFACES_FILE="/etc/network/interfaces"
        RESOLV_CONF_FILE="/etc/resolv.conf"

        # 更新网络配置
        cat > $INTERFACES_FILE <<EOL
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
EOL

        # 更新 resolv.conf 文件
        echo > $RESOLV_CONF_FILE
        for dns in $DNS_SERVERS; do
            echo "nameserver $dns" >> $RESOLV_CONF_FILE
        done

        # 重启网络服务
        sudo systemctl restart networking

        # 输出配置结果
        echo -e "${GREEN}静态 IP 地址和 DNS 配置完成！${NC}"
        break
    else
        echo -e "${RED}请重新输入配置信息。${NC}"
    fi
done
