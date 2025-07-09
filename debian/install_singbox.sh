#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box 已安装，跳过安装步骤${NC}"
else
    # 添加官方 GPG 密钥和仓库
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
" | sudo tee /etc/apt/sources.list.d/sagernet.sources > /dev/null

    # 始终更新包列表
    echo "正在更新包列表，请稍候..."
    sudo apt-get update -qq > /dev/null 2>&1

    # 选择安装稳定版或测试版
    while true; do
        read -rp "请选择安装版本(1: 稳定版, 2: 测试版): " version_choice
        case $version_choice in
            1)
                echo "安装稳定版..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                echo "安装已完成"
                break
                ;;
            2)
                echo "安装测试版..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                echo "安装已完成"
                break
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1 或 2。${NC}"
                ;;
        esac
    done

    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box 安装成功，版本：${NC} $sing_box_version"
         
        if ! id sing-box &>/dev/null; then
            echo "正在创建 sing-box 系统用户"
            sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
        fi
        echo "正在设置sing-box权限..."
        sudo mkdir -p /var/lib/sing-box
        sudo chown -R sing-box:sing-box /var/lib/sing-box
        sudo chown -R sing-box:sing-box /etc/sing-box
        sudo chmod 770 /etc/sing-box
        
        #if [ -f /etc/sing-box/cache.db ]; then
        #    sudo chown sing-box:sing-box /etc/sing-box/cache.db
        #    sudo chmod 660 /etc/sing-box/cache.db
        #else
        #    sudo -u sing-box touch /etc/sing-box/cache.db
        #    sudo chown sing-box:sing-box /etc/sing-box/cache.db
        #    sudo chmod 660 /etc/sing-box/cache.db
        #fi
        # 获取 sing-box 的版本号
        version_output=$(sing-box version 2>/dev/null)
        version=$(echo "$version_output" | grep -oE '1\.11\.[0-9]+')

        # 检查是否为 1.11.x 版本
        if [[ -n "$version" ]]; then
            echo "检测到 sing-box 版本为 $version"

            service_file="/lib/systemd/system/sing-box.service"

            if [[ -f "$service_file" ]]; then
                echo "已找到服务文件"

                has_user=$(grep -E '^\s*User=sing-box' "$service_file")
                has_state=$(grep -E '^\s*StateDirectory=sing-box' "$service_file")

                if [[ -n "$has_user" && -n "$has_state" ]]; then
                    echo -e "${RED}服务已有无需设置${NC}"
                else
                    echo "准备插入缺失配置..."

                    awk -v add_user="$([[ -z "$has_user" ]] && echo 1 || echo 0)" \
                        -v add_state="$([[ -z "$has_state" ]] && echo 1 || echo 0)" '
                        BEGIN { in_service=0 }
                        {
                            print
                            if ($0 ~ /^\[Service\]/) {
                                in_service = 1
                                next
                            }

                            if (in_service == 1) {
                                if (add_user == 1) {
                                    print "User=sing-box"
                                    if (add_state == 1) {
                                        print "StateDirectory=sing-box"
                                        add_state = 0
                                    }
                                    add_user = 0
                                } else if (add_state == 1 && $0 ~ /^User=sing-box/) {
                                    print
                                    print "StateDirectory=sing-box"
                                    add_state = 0
                                    next
                                }
                            }
                        }
                    ' "$service_file" > "${service_file}.tmp" && mv "${service_file}.tmp" "$service_file"

                    echo "修改完成，执行 systemctl daemon-reexec"
                    systemctl daemon-reexec
                fi
            else
                echo "未找到服务文件：$service_file"
            fi
        else
            echo "当前 sing-box 版本非 1.11.x，跳过处理。"
    fi 
        # 重启 sing-box 服务
        sudo systemctl daemon-reload
        sudo systemctl restart sing-box

        echo -e "${CYAN}sing-box 服务已重启${NC}"      
    else
        echo -e "${RED}sing-box 安装失败，请检查日志或网络配置${NC}"
    fi
fi
