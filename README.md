# sbshell

**sing-box 全自动脚本:**  
```
bash <(curl -sL https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/sbshall.sh)
```
目前支持系统为deiban/ubuntu/armbian, 后续有时间可能会去支持openwrt  

测试版：  
tproxy模式配置文件地址：https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/config_template/config_tproxy_dev.json  

tun模式配置文件地址：https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/config_template/config_tun_dev.json  

稳定版：  
tproxy模式配置文件地址：https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/config_template/config_tproxy.json  

tun模式配置文件地址：https://ghp.ci/https://raw.githubusercontent.com/qichiyuhub/sbshell/refs/heads/master/config_template/config_tun.json  

**使用说明**：输入 sb  进入菜单  

**菜单：**
1. Tproxy/Tun模式切换
2. 手动更新配置文件
3. 自动更新配置文件
4. 手动启动 sing-box
5. 手动停止 sing-box
6. 安装/更新 sing-box
7. 修改默认配置参数
8. 设置自启动
9. 网络设置
10. 常用命令
11. 更新脚本
0. 退出


**注意事项**：
- 使用脚本需要root登录ssh，如普通用户登录再切换可能会有问题。
- 默认为禁用开机自启动，可在菜单中开启自启动，如果禁用自启动需要重启。
- 默认后端、订阅、规则 需要在菜单中自行设置。
- 如果使用自己的配置文件需要注意tproxy配置文件中需要定义两个参数和脚本中一致：  
  入站中的tproxy监听端口必须为：`"listen_port": 7895,`，route模块必须添加mark标记：`"default_mark": 666,`
  