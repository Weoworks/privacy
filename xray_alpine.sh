#!/usr/bin/env bash
# Xray Reality installer
# Keep original architecture detection style
# Trojan Reality + VLESS XHTTP Reality

set -e

XRAY_HOME="/usr/local/bin/xray"
XRAY_BIN="${XRAY_HOME}/xray"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_CONFIG_DIR}/config.json"
CLIENT_INFO="${XRAY_CONFIG_DIR}/client_info.json"

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
        echo "未找到客户端配置文件，请先安装节点！"
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
    password: ${UUID}
    udp: true
    sni: ${SNI}
    client-fingerprint: edge
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}

  - name: "VLESS-XHTTP-Reality"
    type: vless
    server: ${SERVER_IP}
    port: ${VLESS_PORT}
    uuid: ${UUID}
    network: xhttp
    udp: true
    tls: true
    servername: ${SNI}
    client-fingerprint: edge
    reality-opts:
      public-key: ${PUBLIC_KEY}
      short-id: ${SHORT_ID}
    xhttp-opts:
      mode: auto
      path: /txc
      headers:
        Host: ${SNI}
EOF
    echo "=================================================================="
    echo ""
}

install_xray(){

    apk add --no-cache bash curl unzip ca-certificates python3

    mkdir -p ${XRAY_HOME} ${XRAY_CONFIG_DIR}

    # 使用重定向获取最新的 Tag 名称，避免 GitHub API 解析错误或限流
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

cat >/etc/init.d/xray <<EOF
#!/sbin/openrc-run
command="${XRAY_BIN}"
command_args="run -c ${XRAY_CONFIG}"
depend(){
 need net
}
EOF

chmod +x /etc/init.d/xray
rc-update add xray default
rc-service xray restart

echo "安装完成！"
show_client_links
}


regenerate(){

    if [ ! -f "${CLIENT_INFO}" ]; then
        echo "错误：未找到原配置，请先运行安装！"
        return
    fi

    reality_key

    # 读取旧的配置信息
    UUID=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['uuid'])")
    SNI=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}'))['sni'])")
    TROJAN_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('trojan_port', 53999))")
    VLESS_PORT=$(python3 -c "import json; print(json.load(open('${CLIENT_INFO}')).get('vless_port', 53666))")

    # 更新 client_info.json
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

    rc-service xray restart

    echo "Reality参数已更新！"
    show_client_links
}


menu(){
    echo "========================="
    echo "1. 安装Xray Reality"
    echo "2. 重新生成X25519和ShortID"
    echo "3. 查看客户端配置及链接"
    echo "0. 退出"
    echo "========================="

    read -p "> " choice

    case $choice in
        1) install_xray ;;
        2) regenerate ;;
        3) show_client_links ;;
        0) exit ;;
        *) menu ;;
    esac
}

[ "$(id -u)" = "0" ] || exit 1

menu
