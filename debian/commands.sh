#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色


function view_firewall_rules() {
    echo -e "${YELLOW}查看防火墙规则...${NC}"
    sudo nft list ruleset
    read -rp "按回车键返回二级菜单..."
}

function view_logs() {
    echo -e "${YELLOW}显示日志...${NC}"
    sudo journalctl -u sing-box --output cat -e
    read -rp "按回车键返回二级菜单..."
}

function live_logs() {
    echo -e "${YELLOW}实时日志...${NC}"
    sudo journalctl -u sing-box -f --output=cat
    read -rp "按回车键返回二级菜单..."
}

function check_config() {
    echo -e "${YELLOW}检查配置文件...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -rp "按回车键返回二级菜单..."
}

function setup_singbox_permissions() {
    echo -e "${YELLOW}正在设置 sing-box 权限与服务...${NC}"

    if ! id sing-box &>/dev/null; then
        echo "正在创建 sing-box 系统用户"
        sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
    fi

    echo "正在设置 sing-box 权限..."
    sudo mkdir -p /var/lib/sing-box
    sudo chown -R sing-box:sing-box /var/lib/sing-box
    sudo chown -R sing-box:sing-box /etc/sing-box
    sudo chmod 770 /etc/sing-box

    version_output=$(sing-box version 2>/dev/null)
    version=$(echo "$version_output" | grep -oE '1\.11\.[0-9]+')

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
                ' "$service_file" > "${service_file}.tmp" && sudo mv "${service_file}.tmp" "$service_file"

                echo "修改完成，执行 systemctl daemon-reexec"
                sudo systemctl daemon-reexec
            fi
        else
            echo "未找到服务文件：$service_file"
        fi
    else
        echo "当前 sing-box 版本非 1.11.x，跳过处理。"
    fi

    read -rp "按回车键返回二级菜单..."
}

function show_submenu() {
    echo -e "${CYAN}=========== 二级菜单选项 ===========${NC}"
    echo -e "${MAGENTA}1. 查看防火墙规则${NC}"
    echo -e "${MAGENTA}2. 显示日志${NC}"
    echo -e "${MAGENTA}3. 实时日志${NC}"
    echo -e "${MAGENTA}4. 检查配置文件${NC}"
    echo -e "${MAGENTA}5. 设置 sing-box 权限与服务（执行前查阅wiki）${NC}"
    echo -e "${MAGENTA}0. 返回主菜单${NC}"
    echo -e "${CYAN}===================================${NC}"
}

function handle_submenu_choice() {
    while true; do
        read -rp "请选择操作: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) view_logs ;;
            3) live_logs ;;
            4) check_config ;;
            5) setup_singbox_permissions ;;
            0) return 0 ;;
            *) echo -e "${RED}无效的选择${NC}" ;;
        esac
        show_submenu
    done
    return 0  # 确保函数结束时返回 0
}

menu_active=true
while $menu_active; do
    show_submenu
    handle_submenu_choice
    choice_returned=$?  # 捕获函数返回值
    if [[ $choice_returned -eq 0 ]]; then
        menu_active=false
    fi
done