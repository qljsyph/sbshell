# Sbshell
⚠️⚠️请注意禁止搬运到中国大陆，请遵守属地法律法律⚠️⚠️  
Sbshell 是一款针对 官方sing-box 的辅助运行脚本，旨在解决官方sing-box的使用不便：

- **系统支持**：支持系统为Debian/Ubuntu/Armbian以及OpenWrt。
- **辅助运行**：保持 sing-box 以官方裸核形式运行，追求极致精简与性能。
- **双模支持**：兼容 TUN 和 TProxy 模式，可随时一键切换，灵活适应不同需求。
- **版本管理**：支持一键切换稳定版与测试版内核，检测并更新至最新版本，操作简单高效。
- **灵活配置**：支持手动输入后端地址、订阅链接、配置文件链接，并可设置默认值，提升使用效率。
- **订阅管理**：支持手动更新、定时自动更新，确保订阅和配置始终保持最新。
- **启动控制**：支持手动启动、停止和开机自启管理，操作直观。
- **网络配置**：内置网络配置模块，可快速修改系统 IP、网关和 DNS，自动提示是否需要调整。
- **便捷命令**：集成常用命令，避免手动查找与复制的繁琐。
- **在线更新**：支持脚本在线更新，始终保持最新版本。
- **面板更新**：支持clash面板在线更新/切换。

## 设备支持：

目前支持系统为deiban/ubuntu/armbian以及openwrt！

## 一键脚本：(请自行安装curl和bash，如果缺少的话)
```
bash <(curl -sL https://gh-proxy.com/https://raw.githubusercontent.com/qljsyph/sbshell/blob/heads/main/sbshall.sh)
```
- 初始化运行结束，输入“**sb**”进入菜单
- 目前支持系统为deiban/ubuntu/armbian/openwrt。  
- 防火墙仅支持nftables，不支持iptables。

### 系统信息自动显示美化脚本： 
```
bash <(curl -sL https://gh-proxy.com/https://raw.githubusercontent.com/qljsyph/DPInfo-script/refs/heads/main/auto-sysinfo.sh)
```
  执行后每次进入ssh会自动显示很多必要信息！
  仓库：  
  https://github.com/qljsyph/DPInfo-script

## 适配配置文件：

### 稳定版(1.11)：  
tproxy：  
https://gh-proxy.com/https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/main/config_template/config_tproxy.json  

tun：  
https://gh-proxy.com/https://raw.githubusercontent.com/qljsyph/sbshell/refs/heads/main/config_template/config_tun.json  

## 其他问题：

**请查看[wiki](https://github.com/qljsyph/sbshell/wiki)**  


