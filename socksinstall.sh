#!/bin/bash

DEFAULT_START_PORT=20000                         # 默认起始端口
IP_ADDRESSES=($(hostname -I))

generate_random_string() {
    # 随机生成8位字符串（包含字母和数字）
    tr -dc A-Za-z0-9 </dev/urandom | head -c 8
}

install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.json
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    mkdir -p /etc/xrayL
    users_file="/etc/xrayL/users.txt"
    >"$users_file"  # 清空或创建用户记录文件

    read -p "每个 IP 创建多少个用户: " USERS_PER_IP
    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    config_content='{ "inbounds": ['

    for ((ip_idx = 0; ip_idx < ${#IP_ADDRESSES[@]}; ip_idx++)); do
        ip="${IP_ADDRESSES[ip_idx]}"
        accounts=""

        # 为当前 IP 生成多个用户账号和密码
        for ((user_idx = 0; user_idx < USERS_PER_IP; user_idx++)); do
            USERNAME=$(generate_random_string)
            PASSWORD=$(generate_random_string)

            echo "IP: $ip -> 用户 $((user_idx + 1)) -> 账号: $USERNAME, 密码: $PASSWORD, 端口: $((START_PORT + ip_idx))" >>"$users_file"

            accounts+=$(cat <<EOF
{ "user": "$USERNAME", "pass": "$PASSWORD" }
EOF
)
            if ((user_idx < USERS_PER_IP - 1)); then
                accounts+=','
            fi
        done

        # 为每个 IP 生成一个 inbound 配置
        config_content+=$(cat <<EOF
{
    "port": $((START_PORT + ip_idx)),
    "protocol": "socks",
    "tag": "tag_$((ip_idx + 1))",
    "settings": {
        "auth": "password",
        "udp": true,
        "accounts": [$accounts]
    },
    "listen": "$ip"
}
EOF
)
        if ((ip_idx < ${#IP_ADDRESSES[@]} - 1)); then
            config_content+=','
        fi
    done

    config_content+='], "outbounds": [{ "protocol": "freedom", "tag": "outbound" }] }'

    echo "$config_content" >/etc/xrayL/config.json
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 socks 配置完成"
    echo "起始端口: $START_PORT"
    echo "用户信息已保存到 $users_file"
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray
}
main "$@"
