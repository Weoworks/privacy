#!/bin/bash

function is_xray_installed() {
    command -v xrayL > /dev/null 2>&1
}

function install_xray() {
    if is_xray_installed; then
        echo "Xray 已经安装，跳过安装步骤."
        return
    fi

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
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
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

function generate_config() {
    echo "请输入socks/http/ss，输入no继续运行此脚本"
    read protocol

    i=0  # Counter for entry order

    config_file="/etc/xrayL/config.toml.temp"

    # Check if the config file exists, create it if not
    if [ ! -f "$config_file" ]; then
        mkdir /etc/xrayL
        touch "$config_file"
        echo "# XrayL Config File" > "$config_file"
    fi

    while [ "$protocol" != "no" ]; do
        ((i++))
        echo "已经切换到$protocol"

        echo "请输入节点信息，格式为IP/端口/账户/密码或IP/端口/加密方式/密码"
        read node_info

        # Protocol mapping
        case $protocol in
            "socks" | "http")
                protocol_type="$protocol"
                ;;
            "ss")
                protocol_type="shadowsocks"
                ;;
            *)
                echo "无效的协议类型"
                continue
                ;;
        esac

        # 生成配置文件
        cat <<EOF >>"$config_file"
[[inbounds]]
port = "$(echo "$node_info" | cut -d'/' -f2)"
protocol = "$protocol_type"
tag = ${protocol}_in_${i}
[inbounds.settings]
EOF

        # 处理信息
        case $protocol_type in
            "socks")
                echo "auth = \"password\"" >>"$config_file"
                echo "udp = true" >>"$config_file"
                echo "[[inbounds.settings.accounts]]" >>"$config_file"
                echo "user = \"$(echo "$node_info" | cut -d'/' -f3)\"" >>"$config_file"
                echo "pass = \"$(echo "$node_info" | cut -d'/' -f4)\"" >>"$config_file"
                ;;
            "http")
                echo "[[inbounds.settings.accounts]]" >>"$config_file"
                echo "user = \"$(echo "$node_info" | cut -d'/' -f3)\"" >>"$config_file"
                echo "pass = \"$(echo "$node_info" | cut -d'/' -f4)\"" >>"$config_file"
                ;;
            "shadowsocks")
                echo "password = \"$(echo "$node_info" | cut -d'/' -f4)\"" >>"$config_file"
                echo "method = \"$(echo "$node_info" | cut -d'/' -f3)\"" >>"$config_file"
                echo "network = tcp,udp" >>"$config_file"
                ;;
        esac

        echo "" >>"$config_file"

        # 添加 outbound 和 route 配置
        cat <<EOF >>"$config_file"
[[outbounds]]
protocol = "$protocol_type"
tag = ${protocol}_out_${i}
[outbounds.settings]
EOF

        # 处理信息
        case $protocol_type in
            "socks" | "http")
                echo "[[outbounds.settings.servers]]" >>"$config_file"
                echo "address = \"$(echo "$node_info" | cut -d'/' -f1)\"" >>"$config_file"
                echo "port = \"$(echo "$node_info" | cut -d'/' -f2)\"" >>"$config_file"
                echo "[[outbounds.settings.servers.users]]" >>"$config_file"
                echo "user = \"$(echo "$node_info" | cut -d'/' -f3)\"" >>"$config_file"
                echo "pass = \"$(echo "$node_info" | cut -d'/' -f4)\"" >>"$config_file"
                ;;
            "shadowsocks")
                echo "address = \"$(echo "$node_info" | cut -d'/' -f1)\"" >>"$config_file"
                echo "port = \"$(echo "$node_info" | cut -d'/' -f2)\"" >>"$config_file"
                echo "password = \"$(echo "$node_info" | cut -d'/' -f4)\"" >>"$config_file"
                echo "method = \"$(echo "$node_info" | cut -d'/' -f3)\"" >>"$config_file"
                ;;
        esac

        echo "" >>"$config_file"

        echo "[[routing.rules]]" >>"$config_file"
        echo "type = \"field\"" >>"$config_file"
        echo "inboundTag = \"${protocol}_in_${i}\"" >>"$config_file"
        echo "outboundTag = \"${protocol}_out_${i}\"" >>"$config_file"

        echo "" >>"$config_file"

        echo "请输入socks/http/ss，输入no继续运行此脚本"
        read protocol
    done
    rm -rf /etc/xrayL/config.toml
    mv /etc/xrayL/config.toml.temp /etc/xrayL/config.toml
    echo "生成配置文件成功"
}


function manage_config() {
    # 读取配置文件
    # TODO: 读取配置文件的逻辑

    echo "当前配置文件中的节点信息:"
    # TODO: 输出配置文件中的节点信息

    echo "请选择操作: 1.添加节点 2.移除节点"
    read choice

    while [ "$choice" != "no" ]; do
        case $choice in
            1)
                echo "输入之前需要先确认节点的协议，如果没有要输入的内容了就输入no继续运行脚本"
                generate_config # 调用添加节点的函数
                ;;
            2)
                echo "请输入以上列出的tag"
                read tag
                # TODO: 移除节点的逻辑
                ;;
            *)
                echo "无效的选项，请重新选择: 1.添加节点 2.移除节点"
                ;;
        esac

        echo "请选择操作: 1.添加节点 2.移除节点"
        read choice
    done

    echo "操作完成，如果没有成功运行请及时反馈"
}

# 主菜单
echo "请选择操作: 1.安装转发 2.管理配置(未完成)"
read main_choice

case $main_choice in
    1)
        install_xray
        generate_config
        ;;
    2)
        manage_config
        ;;
    *)
        echo "无效的选项，请重新运行脚本并选择正确的操作"
        ;;
esac
