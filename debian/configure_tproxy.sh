#!/bin/sh

# 配置参数
TPROXY_PORT=7895  # 与 sing-box 中定义的一致
ROUTING_MARK=666  # 与 sing-box 中定义的一致
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5}')

# 保留 IP 地址集合
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.18.0.0/15, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16 }'  # 自定义绕过的 IP 地址集合

# 读取当前模式
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# 检查指定规则是否存在
check_rule_exists() {
    ip rule show | grep -q "$1"
    return $?
}

# 检查指定路由是否存在
check_route_exists() {
    ip route show table "$1" | grep -q "^local default"
    return $?
}

# 应用 nftables 配置
apply_nftables_config() {
    cat > /etc/sing-box/nft/nftables.conf <<EOF
# 定义 sing-box 表和相关规则
# 该规则用于 TProxy 模式流量重定向和过滤


table inet sing-box {
    set RESERVED_IPSET {
        type ipv4_addr
        flags interval
        auto-merge
        elements = $ReservedIP4
    }

    chain prerouting_tproxy {
        type filter hook prerouting priority mangle; policy accept;

         # DNS 请求重定向到本地 TProxy 端口
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # 自定义绕过地址
        ip daddr $CustomBypassIP accept

        # 拒绝访问本地 TProxy 端口
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable

        # 本地地址绕过
        fib daddr type local accept

        # 保留地址绕过
        ip daddr @RESERVED_IPSET accept

        # 优化已建立的 TCP 连接
        meta l4proto tcp socket transparent 1 meta mark set $PROXY_FWMARK accept

        # 重定向剩余流量到 TProxy 端口并设置标记
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;

        # 放行本地回环接口流量
        meta oifname "lo" accept

        # 本地 sing-box 发出的流量绕过
        meta mark $ROUTING_MARK accept

        # DNS 请求标记
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # 绕过 NBNS 流量
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept

        # 自定义绕过地址
        ip daddr $CustomBypassIP accept

        # 本地地址绕过
        fib daddr type local accept

         # 保留地址绕过
        ip daddr @RESERVED_IPSET accept

        # 标记并重定向剩余流量
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    if nft -f /etc/sing-box/nft/nftables.conf; then
        echo "nftables 规则应用成功。"
    else
        echo "nftables 规则应用失败。"
        exit 1
    fi
}

# 清理现有 sing-box 防火墙规则
clearSingboxRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    if check_rule_exists "lookup $PROXY_ROUTE_TABLE"; then
        ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null || echo "删除规则失败"
    fi
    if check_route_exists "$PROXY_ROUTE_TABLE"; then
        ip route del local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE 2>/dev/null || echo "删除路由失败"
    fi
    echo "清理 sing-box 相关的防火墙规则"
}

# 依据当前模式应用防火墙规则
if [ "$MODE" = "TProxy" ]; then
    echo "应用 TProxy 模式下的防火墙规则..."
    clearSingboxRules

    if ! check_rule_exists "lookup $PROXY_ROUTE_TABLE"; then
        ip -f inet rule add fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE || echo "添加规则失败"
    fi

    if ! check_route_exists "$PROXY_ROUTE_TABLE"; then
        ip -f inet route add local default dev "$INTERFACE" table $PROXY_ROUTE_TABLE || echo "添加路由失败"
    fi

# 启用 IP 转发
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
# /etc/sing-box/nft 目录存在
    sudo mkdir -p /etc/sing-box/nft
# 应用 nftables 配置
    apply_nftables_config

    if ! check_rule_exists "fwmark $PROXY_FWMARK"; then
        ip rule add fwmark $PROXY_FWMARK table $PROXY_ROUTE_TABLE || echo "添加 fwmark 规则失败"
    fi

    if ! check_route_exists "$PROXY_ROUTE_TABLE"; then
        ip route add local default dev lo table $PROXY_ROUTE_TABLE || echo "添加 lo 路由失败"
    fi
    # 持久化防火墙规则
    nft list ruleset > /etc/nftables.conf
    echo "TProxy 模式的防火墙规则已应用。"
else
    echo "当前模式为 TUN 模式，不需要应用防火墙规则。" >/dev/null 2>&1
fi