#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m' # 无颜色

echo -e "${MAGENTA}运行 auto_update.sh...${NC}"

# 手动输入的配置文件
MANUAL_FILE="/etc/sing-box/manual.conf"

# 创建定时更新脚本
cat > /etc/sing-box/update-singbox.sh <<EOF
#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "\${MAGENTA}运行 update-singbox.sh...${NC}"

# 停止 sing-box 服务
systemctl stop sing-box

# 读取手动输入的配置参数
BACKEND_URL=\$(grep BACKEND_URL $MANUAL_FILE | cut -d'=' -f2-)
SUBSCRIPTION_URL=\$(grep SUBSCRIPTION_URL $MANUAL_FILE | cut -d'=' -f2-)
TEMPLATE_URL=\$(grep TEMPLATE_URL $MANUAL_FILE | cut -d'=' -f2-)

# 构建完整的配置文件URL
FULL_URL="\${BACKEND_URL}/config/\${SUBSCRIPTION_URL}&file=\${TEMPLATE_URL}"
echo "生成完整订阅链接: \$FULL_URL"

[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup
if curl -L --connect-timeout 10 --max-time 30 "\$FULL_URL" -o /etc/sing-box/config.json; then
    echo "配置文件下载成功"
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo "配置文件验证失败，正在还原备份"
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
        exit 1
    fi
else
    echo "配置文件下载失败"
    exit 1
fi
sleep 5
systemctl start sing-box
EOF

chmod a+x /etc/sing-box/update-singbox.sh

# 提供菜单选项调整间隔时间
read -p "请输入更新间隔小时数 (默认为12小时): " interval_choice
interval_choice=${interval_choice:-12}

# 检查是否已有定时任务
if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
    echo -e "${RED}检测到已有自动更新任务。${NC}"
    read -p "是否重新设置自动更新任务？(y/n): " confirm_reset
    if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
        crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
        echo "已删除旧的自动更新任务。"
    else
        echo -e "${CYAN}保持已有的自动更新任务。返回菜单。${NC}"
        exit 0
    fi
fi

# 添加新的定时任务
(crontab -l 2>/dev/null; echo "0 */$interval_choice * * * /etc/sing-box/update-singbox.sh") | crontab -
systemctl restart cron

echo "定时更新任务已设置，每 $interval_choice 小时执行一次"
