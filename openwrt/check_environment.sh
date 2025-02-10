#!/bin/bash

# 确保以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "错误: 此脚本需要 root 权限"
    exit 1
fi

# 检查sing-box是否已安装
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo "sing-box 已安装，版本：$current_version"
else
    echo "sing-box 未安装"
fi

# 检查并开启IP转发
ipv4_forward=$(uci get network.globals.forwarding 2>/dev/null)
ipv6_forward=$(uci get network.globals.forwarding6 2>/dev/null)

if [ "$ipv4_forward" == "1" ] && [ "$ipv6_forward" == "1" ]; then
    echo "IP 转发已开启"
else
    echo "开启 IP 转发..."
    uci set network.globals.forwarding=1
    uci set network.globals.forwarding6=1
    uci commit network
    /etc/init.d/network restart
    echo "IP 转发已成功开启"
fi