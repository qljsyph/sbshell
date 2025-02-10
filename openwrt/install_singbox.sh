#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box 已安装，跳过安装步骤${NC}"
else
    # 更新包列表并安装必要的依赖和 sing-box
    echo "正在更新包列表并安装 sing-box，请稍候..."
    opkg update
    opkg install kmod-inet-diag kmod-netlink-diag kmod-tun iptables-nft
    opkg install sing-box

    if command -v sing-box &> /dev/null; then
        echo -e "${CYAN}sing-box 安装成功${NC}"
    else
        echo -e "${RED}sing-box 安装失败，请检查日志或网络配置${NC}"
        exit 1
    fi
fi

# 创建 /etc/init.d/sing-box 服务脚本
cat > /etc/init.d/sing-box <<EOF
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

#####  ONLY CHANGE THIS BLOCK  ######
PROG=/usr/bin/sing-box 
RES_DIR=/etc/sing-box/ # resource dir / working dir / the dir where you store ip/domain lists
CONF=./config.json   # where is the config file, it can be a relative path to \$RES_DIR
#####  ONLY CHANGE THIS BLOCK  ######

start_service() {
  sleep 10 
  procd_open_instance
  procd_set_param command \$PROG run -D \$RES_DIR -c \$CONF

  procd_set_param user root
  procd_set_param limits core="unlimited"
  procd_set_param limits nofile="1000000 1000000"
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn "\${respawn_threshold:-3600}" "\${respawn_timeout:-5}" "\${respawn_retry:-5}"
  procd_close_instance
  nft add rule inet filter forward oifname "tun+" accept
  echo "sing-box is started!"
}

stop_service() {
  service_stop \$PROG
  nft delete rule inet filter forward oifname "tun+"
  echo "sing-box is stopped!"
}

reload_service() {
  stop
  sleep 5s
  echo "sing-box is restarted!"
  start
}
EOF

# 确保服务脚本具有可执行权限
chmod +x /etc/init.d/sing-box

# 启用并启动 sing-box 服务
/etc/init.d/sing-box enable
/etc/init.d/sing-box start

echo -e "${CYAN}sing-box 服务已启用并启动${NC}"
