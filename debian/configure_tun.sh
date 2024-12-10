#!/bin/bash

# 配置参数
TPROXY_PORT=7895  # 和 sing-box 中定义的一致
ROUTING_MARK=666  # 和 sing-box 中定义的一致
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# 读取当前模式
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# 清理 TProxy 模式的防火墙规则
clearTProxyRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev $INTERFACE table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "清理 TProxy 模式的防火墙规则"
}

if [ "$MODE" = "TUN" ]; then
    echo "应用 TUN 模式下的防火墙规则..."

    # 清理 TProxy 模式的防火墙规则
    clearTProxyRules

    # 确保目录存在
    sudo mkdir -p /etc/sing-box/tun

    # 设置 TUN 模式的具体配置
    cat > /etc/sing-box/tun/nftables.conf <<EOF
# 清除现有的 nftables 规则并应用新的配置
flush ruleset
table inet filter {
    chain input { type filter hook input priority 0; policy accept; }
    chain forward { type filter hook forward priority 0; policy accept; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF

    # 应用防火墙规则
    nft -f /etc/sing-box/tun/nftables.conf

    # 持久化防火墙规则
    nft list ruleset > /etc/nftables.conf

    echo "TUN 模式的防火墙规则已应用。"
else
    echo "当前模式不是 TUN 模式，跳过防火墙规则配置。" >/dev/null 2>&1
fi
