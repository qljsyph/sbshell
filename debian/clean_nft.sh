#!/bin/bash

# 清理防火墙规则并停止服务
sudo systemctl stop sing-box
nft flush ruleset

echo "sing-box 服务已停止,防火墙规则已清理."
