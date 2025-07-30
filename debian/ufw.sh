#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 非交互式/自动模式 ---
if [ "$1" == "--auto" ]; then
    # 确保 UFW 已安装
    if ! command -v ufw &>/dev/null; then
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install -y ufw >/dev/null 2>&1
    fi
    # 应用基本规则
    sudo ufw default deny incoming >/dev/null
    sudo ufw default allow outgoing >/dev/null
    sudo ufw allow ssh >/dev/null
    sudo ufw allow http >/dev/null
    sudo ufw allow https >/dev/null
    # 强制启用
    sudo ufw --force enable >/dev/null
    exit 0
fi

# --- 交互式模式 ---

# 1. 更新和安装
echo -e "${CYAN}正在更新软件包列表...${NC}"
sudo apt-get update >/dev/null 2>&1

if ! command -v ufw &>/dev/null; then
    echo -e "${CYAN}正在安装 UFW 防火墙...${NC}"
    if sudo apt-get install -y ufw >/dev/null 2>&1; then
        echo -e "${GREEN}UFW 安装成功。${NC}"
    else
        echo -e "${RED}UFW 安装失败！请检查 apt 源或手动安装。${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}UFW 已安装，跳过安装步骤。${NC}"
fi

# 2. 手动放行端口
echo -e "\n${CYAN}请输入需要放行的端口（支持多个，用空格或英文逗号分隔）：${NC}"
read -rp "要放行的端口: " ports_input

# 处理输入，替换逗号为空格
ports=$(echo "$ports_input" | tr ',' ' ')

if [ -n "$ports" ]; then
    for port in $ports; do
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            sudo ufw allow "$port"/tcp >/dev/null
            sudo ufw allow "$port"/udp >/dev/null
            echo -e "${GREEN}已放行端口 $port (TCP/UDP)。${NC}"
        else
            echo -e "${YELLOW}已跳过无效输入: $port${NC}"
        fi
    done
else
    echo -e "${YELLOW}未输入任何端口，跳过此步骤。${NC}"
fi

# 3. 启用 UFW
echo -e "\n${CYAN}正在启用 UFW 防火墙...${NC}"
sudo ufw --force enable >/dev/null

# 4. 修改 SSH 端口 (可选)
echo -e "\n${CYAN}是否需要修改 SSH 端口？(y/n)${NC}"
read -rp "选择 [n]: " ssh_modify

if [[ "$ssh_modify" =~ ^[Yy]$ ]]; then
    read -rp "请输入新的 SSH 端口 (1025-65535): " new_ssh_port
    if [[ "$new_ssh_port" =~ ^[0-9]+$ ]] && [ "$new_ssh_port" -gt 1024 ] && [ "$new_ssh_port" -le 65535 ]; then
        # 修改 sshd_config
        sudo sed -i "s/^#*Port .*/Port $new_ssh_port/" /etc/ssh/sshd_config
        echo -e "${GREEN}SSH 配置文件已更新为端口 $new_ssh_port。${NC}"
        
        # 在防火墙中允许新端口
        sudo ufw allow "$new_ssh_port"/tcp >/dev/null
        echo -e "${GREEN}防火墙已放行新 SSH 端口 $new_ssh_port。${NC}"
        
        # 重启 SSH 服务
        sudo systemctl restart sshd
        echo -e "${GREEN}SSH 服务已重启，新端口已生效。${NC}"
        echo -e "${YELLOW}请记得使用新端口 ($new_ssh_port) 重新连接！${NC}"
    else
        echo -e "${RED}端口输入无效，未修改 SSH 端口。${NC}"
    fi
else
    echo -e "${CYAN}未修改 SSH 端口。${NC}"
fi

echo -e "\n${GREEN}UFW 防火墙配置完成。${NC}"
