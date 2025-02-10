#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 手动输入的配置文件
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# 获取当前模式
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# 提示用户输入参数的函数
prompt_user_input() {
    while true; do
        read -rp "请输入后端地址(不填使用默认值): " BACKEND_URL
        if [ -z "$BACKEND_URL" ]; then
            BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$BACKEND_URL" ]; then
                echo -e "${RED}未设置默认值，请在菜单中设置！${NC}"
                continue
            fi
            echo -e "${CYAN}使用默认后端地址: $BACKEND_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "请输入订阅地址(不填使用默认值): " SUBSCRIPTION_URL
        if [ -z "$SUBSCRIPTION_URL" ]; then
            SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$SUBSCRIPTION_URL" ]; then
                echo -e "${RED}未设置默认值，请在菜单中设置！${NC}"
                continue
            fi
            echo -e "${CYAN}使用默认订阅地址: $SUBSCRIPTION_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "请输入配置文件地址(不填使用默认值): " TEMPLATE_URL
        if [ -z "$TEMPLATE_URL" ]; then
            if [ "$MODE" = "TProxy" ]; then
                TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}未设置默认值，请在菜单中设置！${NC}"
                    continue
                fi
                echo -e "${CYAN}使用默认 TProxy 配置文件地址: $TEMPLATE_URL${NC}"
            elif [ "$MODE" = "TUN" ]; then
                TEMPLATE_URL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}未设置默认值，请在菜单中设置！${NC}"
                    continue
                fi
                echo -e "${CYAN}使用默认 TUN 配置文件地址: $TEMPLATE_URL${NC}"
            else
                echo -e "${RED}未知的模式: $MODE${NC}"
                exit 1
            fi
        fi
        break
    done
}

while true; do
    prompt_user_input

    # 显示用户输入的配置信息
    echo -e "${CYAN}你输入的配置信息如下:${NC}"
    echo "后端地址: $BACKEND_URL"
    echo "订阅地址: $SUBSCRIPTION_URL"
    echo "配置文件地址: $TEMPLATE_URL"

    read -rp "确认输入的配置信息？(y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # 更新手动输入的配置文件
        cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

        echo "手动输入的配置已更新"

        # 构建完整的配置文件URL
        FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
        echo "生成完整订阅链接: $FULL_URL"

        while true; do
            # 下载并验证配置文件
            if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
                echo "配置文件下载完成，并验证成功！"
                if ! sing-box check -c /etc/sing-box/config.json; then
                    echo "配置文件验证失败"
                    exit 1
                fi
                break
            else
                echo "配置文件下载失败"
                read -rp "下载失败，是否重试？(y/n): " retry_choice
                if [[ "$retry_choice" =~ ^[Nn]$ ]]; then
                    exit 1
                fi
            fi
        done

        break
    else
        echo -e "${RED}请重新输入配置信息。${NC}"
    fi
done
