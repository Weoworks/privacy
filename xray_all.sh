#!/usr/bin/env bash
# Xray Reality Installer (Universal Edition)
# Supporting Debian, Ubuntu, CentOS, AlmaLinux, Rocky, Arch, Alpine, etc.
# Trojan Reality + VLESS XHTTP Reality

set -e

XRAY_HOME="/usr/local/bin/xray"
XRAY_BIN="${XRAY_HOME}/xray"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_CONFIG_DIR}/config.json"
CLIENT_INFO="${XRAY_CONFIG_DIR}/client_info.json"

# 自动识别系统包管理器并安装依赖
install_dependencies(){
    echo "正在安装系统依赖包..."
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash curl unzip ca-certificates python3
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        apt-get install -y bash curl unzip ca-certificates python3
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bash curl unzip ca-certificates python3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y bash curl unzip ca-certificates python3
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm bash curl unzip ca-certificates python3
    else
        echo "未识别的包管理器，请手动安装: bash curl unzip ca-certificates python3"
    fi
}

# 统一重启服务函数（增加存在性判断，避免 Unit not found 报错）
restart_service(){
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        if [ -f "/etc/systemd/system/xray.service" ]; then
            systemctl restart xray
        fi
    elif command -v rc-service >/dev/null 2>&1; then
        if [ -f "/etc/init.d/xray" ]; then
            rc-service xray restart
        fi
    else
        if [ -f "${XRAY_CONFIG}" ]; then
            pkill -f "${XRAY_BIN}" || true
            ${XRAY_BIN} run -c ${XRAY_CONFIG} >/dev/null 2>&1 &
        fi
    fi
}

# 自动识别服务管理器 (Systemd / OpenRC) 配置服务
setup_service(){
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        # Systemd 服务配置
        cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${XRAY_BIN} run -c ${XRAY_CONFIG}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable xray >/dev/null 2>&1 || true
        systemctl restart xray
    elif [ -f /sbin/openrc-run ] || command -v rc-service >/dev/null 2>&1; then
        # OpenRC 服务配置 (Alpine Linux 等)
        cat > /etc/init.d/xray <<EOF
#!/sbin/openrc-run
name="xray"
description="Xray Service"
command="${XRAY_BIN}"
command_args="run -c ${XRAY_CONFIG}"
command_background="true"
pidfile="/run/xray.pid"

depend(){
 need net
}
EOF
        chmod +x /etc/init.d/xray
        rc-update add xray default >/dev/null 2>&1 || true
        rc-service xray restart
    else
        echo "警告：未找到 Systemd 或 OpenRC，请手动启动 Xray："
        echo "${XRAY_BIN} run -c ${XRAY_CONFIG} &"
    fi
}

get_arch(){
    case "$(uname -m)" in
        x86_64|amd64) echo "64" ;;
        aarch64|arm64) echo "arm64-v8a" ;;
        armv7l|armv7) echo "arm32-v7a" ;;
        armv6l|armv6) echo "arm32-v6" ;;
        i386|i686) echo "32" ;;
        riscv64) echo "riscv64" ;;
        *) echo "Unsupported architecture"; exit 1 ;;
    esac
}

get_public_ip(){
    SERVER_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.me || curl -s4 https://api.ip.sb/ip)
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="YOUR_SERVER_IP"
    fi
}

short_id(){
    od -An -N8 -tx1 /dev/urandom | tr -d ' \n'
}

reality_key(){
    result=$(${XRAY_BIN} x25519)

    PRIVATE_KEY=$(echo "$result" | awk -F': ' '/PrivateKey/{print $2}')
    PUBLIC_KEY=$(echo "$result" | awk -F': ' '/Password/{print $2}')

    SHORT_ID=$(short_id)
}

save_client_info(){
cat > ${CLIENT_INFO} <<EOF
{
  "uuid": "${UUID}",
  "public_key": "${PUBLIC_KEY}",
  "short_id": "${SHORT_ID}",
  "sni": "${SNI}",
  "trojan_port": ${TROJAN_PORT},
  "vless_port": ${VLESS_PORT}
}
EOF
}

show_client_links(){
    if [ ! -f "${CLIENT_INFO}" ]; then
        echo "未找到客户端配置文件，请先运行安装！"
        return
    fi

    get_public_ip

    # 读取客户端参数
    UUID=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['uuid'])")
    PUBLIC_KEY=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['public_key'])")
    SHORT_ID=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['short_id'])")
    SNI=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['sni'])")
    TROJAN_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('trojan_port', 53999))")
    VLESS_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('vless_port', 53666))")

    # 生成 V2Ray 协议链接 (%2F 为路径斜杠 / 的 URL 编码)
    TROJAN_LINK="trojan://${UUID}@${SERVER_IP}:${TROJAN_PORT}?security=reality&sni=${SNI}&fp=edge&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#Trojan-Reality"
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${VLESS_PORT}?security=reality&sni=${SNI}&fp=edge&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=xhttp&path=%2Ftxc&host=${SNI}&mode=auto#VLESS-XHTTP-Reality"

    echo ""
    echo "=================================================================="
    echo "                      节点链接与客户端配置                        "
    echo "=================================================================="
    echo ""
    echo "--- 1. V2Ray 类型链接 (适用于 v2rayN / v2rayNG / Shadowrocket 等) ---"
    echo ""
    echo "【Trojan-Reality 链接】:"
    echo "${TROJAN_LINK}"
    echo ""
    echo "【VLESS-XHTTP-Reality 链接】:"
    echo "${VLESS_LINK}"
    echo ""
    echo "------------------------------------------------------------------"
    echo "--- 2. Mihomo (Clash Meta) YAML 节点配置 (直接复制粘贴到 proxies:) ---"
    echo ""
cat <<EOF
proxies:
  - name: "Trojan-Reality"
    type: trojan
    server: ${SERVER_IP}
    port: ${TROJAN_PORT}
    udp: true
    client-fingerprint: edge
    sni: ${SNI}
    password: ${UUID}
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}

  - name: "VLESS-XHTTP-Reality"
    type: vless
    server: ${SERVER_IP}
    port: ${VLESS_PORT}
    network: xhttp
    udp: true
    tls: true
    client-fingerprint: edge
    xhttp-opts:
      mode: auto
      path: /txc
      headers:
        Host: ${SNI}
    servername: ${SNI}
    uuid: ${UUID}
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}
EOF
    echo "=================================================================="
    echo ""
}

download_geo(){
    echo "正在下载/更新 GeoIP 和 GeoSite 数据库..."
    mkdir -p ${XRAY_HOME}
    wget -O ${XRAY_HOME}/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat || echo "GeoIP 下载失败"
    wget -O ${XRAY_HOME}/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat || echo "GeoSite 下载失败"
    echo "Geo 数据库更新完成！"
    
    restart_service
}

update_xray(){
    echo "正在检查 Xray 最新版本..."
    LATEST_URL=$(curl -sIL -o /dev/null -w "%{url_effective}" https://github.com/XTLS/Xray-core/releases/latest)
    VERSION=$(echo "${LATEST_URL}" | awk -F'/' '{print $NF}')

    if [ -z "${VERSION}" ]; then
        echo "获取 Xray 最新版本失败，请检查网络！"
        return
    fi

    echo "找到最新版本: ${VERSION}，准备更新..."

    ARCH=$(get_arch)

    wget -O /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip"

    unzip -o /tmp/xray.zip -d /tmp/xray

    install -m755 /tmp/xray/xray ${XRAY_BIN}
    rm -rf /tmp/xray /tmp/xray.zip

    restart_service

    echo "Xray 内核更新完成！当前版本信息："
    ${XRAY_BIN} version | head -n 1
}

modify_sni(){
    if [ ! -f "${CLIENT_INFO}" ]; then
        echo "错误：未找到客户端配置文件，请先运行安装！"
        return
    fi

    CURRENT_SNI=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('sni', 'www.dlcci.cn'))")
    echo "当前的 Reality SNI 为: ${CURRENT_SNI}"
    read -p "请输入新的 SNI 域名 [留空保持不变]: " NEW_SNI
    NEW_SNI=${NEW_SNI:-$CURRENT_SNI}

    if [ "$NEW_SNI" = "$CURRENT_SNI" ]; then
        echo "SNI 未变动。"
        return
    fi

    python3 - <<PY
import json

config_file = "${XRAY_CONFIG}"
client_info_file = "${CLIENT_INFO}"
new_sni = "${NEW_SNI}"

with open(config_file, "r") as f:
    c = json.load(f)

for i in c.get("inbounds", []):
    rs = i.get("streamSettings", {}).get("realitySettings", {})
    if "serverNames" in rs:
        rs["serverNames"] = [new_sni]
    if "target" in rs:
        rs["target"] = f"{new_sni}:443"
    
    xs = i.get("streamSettings", {}).get("xhttpSettings", {})
    if "host" in xs:
        xs["host"] = new_sni

with open(config_file, "w") as f:
    json.dump(c, f, indent=2)

with open(client_info_file, "r") as f:
    info = json.load(f)

info["sni"] = new_sni

with open(client_info_file, "w") as f:
    json.dump(info, f, indent=2)
PY

    restart_service

    echo "SNI 修改成功！已更新为: ${NEW_SNI}"
    show_client_links
}

install_xray(){

    install_dependencies

    mkdir -p ${XRAY_HOME} ${XRAY_CONFIG_DIR}

    LATEST_URL=$(curl -sIL -o /dev/null -w "%{url_effective}" https://github.com/XTLS/Xray-core/releases/latest)
    VERSION=$(echo "${LATEST_URL}" | awk -F'/' '{print $NF}')

    if [ -z "${VERSION}" ]; then
        echo "获取 Xray 最新版本失败，请检查网络！"
        exit 1
    fi

    echo "获取到最新的 Xray 版本: ${VERSION}"

    ARCH=$(get_arch)

    wget -O /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip"

    unzip -o /tmp/xray.zip -d /tmp/xray

    install -m755 /tmp/xray/xray ${XRAY_BIN}
    rm -rf /tmp/xray /tmp/xray.zip

    download_geo

    read -p "请输入UUID(留空自动生成): " UUID

    if [ -z "$UUID" ]; then
        UUID=$(${XRAY_BIN} uuid)
    fi

    read -p "请输入 Trojan 端口 [53999]: " TROJAN_PORT
    TROJAN_PORT=${TROJAN_PORT:-53999}

    read -p "请输入 VLESS XHTTP 端口 [53666]: " VLESS_PORT
    VLESS_PORT=${VLESS_PORT:-53666}

    reality_key

    read -p "Reality SNI [www.dlcci.cn]: " SNI
    SNI=${SNI:-www.dlcci.cn}

    save_client_info

cat > ${XRAY_CONFIG} <<EOF
{
 "log":{
  "access":"none",
  "error":"none",
  "loglevel":"info"
 },
 "inbounds":[
  {
   "tag":"trojan-reality",
   "port":${TROJAN_PORT},
   "protocol":"trojan",
   "settings":{
    "clients":[
     {
      "password":"${UUID}"
     }
    ]
   },
   "streamSettings":{
    "network":"tcp",
    "security":"reality",
    "realitySettings":{
     "fingerprint":"edge",
     "privateKey":"${PRIVATE_KEY}",
     "serverNames":[
      "${SNI}"
     ],
     "shortIds":[
      "",
      "${SHORT_ID}"
     ],
     "target":"${SNI}:443",
     "xver":0
    }
   }
  },
  {
   "tag":"vless-xhttp-reality",
   "port":${VLESS_PORT},
   "protocol":"vless",
   "settings":{
    "clients":[
     {
      "id":"${UUID}"
     }
    ],
    "decryption":"none"
   },
   "streamSettings":{
    "network":"xhttp",
    "security":"reality",
    "realitySettings":{
     "fingerprint":"edge",
     "privateKey":"${PRIVATE_KEY}",
     "serverNames":[
      "${SNI}"
     ],
     "shortIds":[
      "",
      "${SHORT_ID}"
     ],
     "target":"${SNI}:443",
     "xver":0
    },
    "xhttpSettings":{
     "host":"${SNI}",
     "mode":"auto",
     "path":"/txc"
    }
   }
  }
 ],
 "outbounds":[
  {
   "protocol":"freedom",
   "tag":"direct"
  }
 ]
}
EOF

    setup_service

    echo "安装完成！"
    show_client_links
}

regenerate(){

    if [ ! -f "${CLIENT_INFO}" ]; then
        echo "错误：未找到原配置，请先运行安装！"
        return
    fi

    reality_key

    UUID=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['uuid'])")
    SNI=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['sni'])")
    TROJAN_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('trojan_port', 53999))")
    VLESS_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('vless_port', 53666))")

    save_client_info

    python3 - <<PY
import json
p="${XRAY_CONFIG}"

with open(p) as f:
    c=json.load(f)

for i in c["inbounds"]:
    r=i["streamSettings"]["realitySettings"]
    r["privateKey"]="${PRIVATE_KEY}"
    r["shortIds"]=["","${SHORT_ID}"]

with open(p,"w") as f:
    json.dump(c,f,indent=2)
PY

    restart_service

    echo "Reality参数已更新！"
    show_client_links
}

menu(){
    echo "========================================="
    echo "    Xray Reality 管理脚本 (全系统通用)    "
    echo "========================================="
    echo " 1. 安装 / 重置 Xray Reality"
    echo " 2. 重新生成 X25519 密钥和 ShortID"
    echo " 3. 修改 Reality SNI 域名"
    echo " 4. 更新 Xray 内核"
    echo " 5. 更新 GeoIP / GeoSite 数据库"
    echo " 6. 查看客户端配置及链接"
    echo " 0. 退出"
    echo "========================================="

    read -p "> " choice

    case $choice in
        1) install_xray ;;
        2) regenerate ;;
        3) modify_sni ;;
        4) update_xray ;;
        5) download_geo ;;
        6) show_client_links ;;
        0) exit ;;
        *) menu ;;
    esac
}

[ "$(id -u)" = "0" ] || exit 1

menu
