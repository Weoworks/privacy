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
    config_type=$1
    mkdir -p /etc/xrayL
    users_file="/etc/xrayL/users.txt"
    >"$users_file"  # 清空或创建用户记录文件

    read -p "需要创建多少个用户: " USER_COUNT
    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    config_content='{ "inbounds": ['
    for ((i = 0; i < USER_COUNT; i++)); do
        USERNAME=$(generate_random_string)
        PASSWORD=$(generate_random_string)

        echo "用户 $((i + 1)) -> 账号: $USERNAME, 密码: $PASSWORD, 端口: $((START_PORT + i))" >>"$users_file"

        config_content+=$(cat <<EOF
{
    "port": $((START_PORT + i)),
    "protocol": "$config_type",
    "tag": "tag_$((i + 1))",
    "settings": {
        "auth": "password",
        "udp": true,
        "accounts": [{ "user": "$USERNAME", "pass": "$PASSWORD" }]
    },
    "listen": "${IP_ADDRESSES[i % ${#IP_ADDRESSES[@]}]}"
}
EOF
)
        if ((i < USER_COUNT - 1)); then
            config_content+=','
        fi
    done
    config_content+='], "outbounds": [{ "protocol": "freedom", "tag": "outbound" }] }'

    echo "$config_content" >/etc/xrayL/config.json
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service

    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口: $START_PORT"
    echo "结束端口: $(($START_PORT + USER_COUNT - 1))"
    echo "用户信息已保存到 $users_file"
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray "socks"
}
main "$@"
