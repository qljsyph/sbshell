#!/bin/bash

# 停止 sing-box 服务
/etc/init.d/sing-box stop

# 清理 sing-box 相关的防火墙规则
nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box

echo "sing-box 服务已停止, sing-box 相关的防火墙规则已清理."
