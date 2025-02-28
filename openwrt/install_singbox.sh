#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box 已安装,跳过安装步骤${NC}"
else
    # 更新包列表并安装必要的依赖和 sing-box
    echo "正在更新包列表并安装 sing-box, 请稍候..."
    opkg update >/dev/null 2>&1
    opkg install kmod-nft-tproxy >/dev/null 2>&1
    opkg install sing-box >/dev/null 2>&1

    if command -v sing-box &> /dev/null; then
        echo -e "${CYAN}sing-box 安装成功${NC}"
    else
        echo -e "${RED}sing-box 安装失败,请检查日志或网络配置${NC}"
        exit 1
    fi
fi

# 添加启动和停止命令到现有服务脚本
if [ -f /etc/init.d/sing-box ]; then
    sed -i '/start_service()/,/}/d' /etc/init.d/sing-box
    sed -i '/stop_service()/,/}/d' /etc/init.d/sing-box
fi

cat << 'EOF' >> /etc/init.d/sing-box

# 定义 PID 文件路径
PID_FILE="/var/run/sing-box.pid"

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
    procd_set_param respawn
    procd_set_param stderr 1
    procd_set_param stdout 1
    procd_close_instance
    
    # 等待服务完全启动
    sleep 3
    
    # 读取模式并应用防火墙规则
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        /etc/sing-box/scripts/configure_tun.sh
    fi

    # 获取 sing-box 进程 ID 并创建 PID 文件
    PID=$(pgrep -f "/usr/bin/sing-box")
    if [ -n "$PID" ]; then
        echo $PID > "$PID_FILE"
        echo -e "${CYAN}sing-box 启动成功,PID: $PID${NC}"
    else
        echo -e "${RED}sing-box 启动失败,未找到进程${NC}"
    fi
}

stop_service() {
    # 检查 PID 文件是否存在
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            echo -e "${CYAN}正在停止 sing-box,PID: $PID${NC}"
            kill $PID
            sleep 2

            # 确保服务已停止
            if ps -p $PID > /dev/null; then
                echo -e "${RED}sing-box 停止失败,请检查日志${NC}"
            else
                echo -e "${CYAN}sing-box 已成功停止${NC}"
                rm -f "$PID_FILE"  # 删除 PID 文件
            fi
        else
            echo -e "${RED}没有找到 sing-box 进程,PID 文件无效${NC}"
            rm -f "$PID_FILE"  # 如果进程不存在,删除 PID 文件
        fi
    else
        # 如果没有 PID 文件,尝试通过进程名停止服务
        PID=$(pgrep -f "/usr/bin/sing-box")
        if [ -n "$PID" ]; then
            echo -e "${CYAN}通过进程名停止 sing-box,PID: $PID${NC}"
            kill $PID
            sleep 2

            # 确保服务已停止
            if ps -p $PID > /dev/null; then
                echo -e "${RED}sing-box 停止失败,请检查日志${NC}"
            else
                echo -e "${CYAN}sing-box 已成功停止${NC}"
            fi
        else
            echo -e "${RED}未找到 sing-box 进程,无法停止服务${NC}"
        fi
    fi
}
EOF

# 确保服务脚本具有可执行权限
chmod +x /etc/init.d/sing-box

# 启用并启动 sing-box 服务
/etc/init.d/sing-box enable
/etc/init.d/sing-box start

echo -e "${CYAN}sing-box 服务已启用并启动${NC}"
