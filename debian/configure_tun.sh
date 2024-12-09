#!/bin/bash

# 读取当前模式
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

if [ "$MODE" = "TUN" ]; then
    echo "应用 TUN 模式下的防火墙规则..."
    
    # 确保目录存在
    sudo mkdir -p /etc/sing-box/tun

    # 清理旧的规则
    nft flush ruleset >/dev/null 2>&1

    # 设置 Tun 模式的具体配置
    cat > /etc/sing-box/tun/nftables.conf <<EOF
# 清除现有的 nftables 规则并应用新的配置
flush ruleset
table inet filter {
    chain input { type filter hook input priority 0; policy accept; }
    chain forward { type filter hook forward priority 0; policy accept; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF

    # 创建防火墙和 IP 路由的清空脚本
    cat > /etc/sing-box/tun/nft-flush.sh <<EOF
#!/bin/sh
nft flush ruleset >/dev/null 2>&1
ip rule delete fwmark 1 table 100 2>/dev/null
ip route delete local default dev lo table 100 2>/dev/null
EOF

    chmod a+x /etc/sing-box/tun/nft-flush.sh

    # 应用防火墙清理规则
    sudo /etc/sing-box/tun/nft-flush.sh

    # 持久化防火墙规则
    nft list ruleset > /etc/nftables.conf

    echo "TUN 模式的防火墙规则已应用。"
else
    echo "当前模式不是 TUN 模式，跳过防火墙规则配置。" >/dev/null 2>&1
fi
