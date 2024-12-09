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
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')

if [ "$ipv4_forward" -eq 1 ] && [ "$ipv6_forward" -eq 1 ]; then
    echo "IP 转发已开启"
else
    echo "开启 IP 转发..."
    sudo sed -i '/net.ipv4.ip_forward/s/^#//;/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
    sudo sysctl -p
    echo "IP 转发已成功开启"
fi