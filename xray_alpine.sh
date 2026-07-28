#!/usr/bin/env bash
# Xray Reality installer
# Keep original architecture detection style
# Trojan Reality + VLESS XHTTP Reality

set -e

XRAY_HOME="/usr/local/bin/xray"
XRAY_BIN="${XRAY_HOME}/xray"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_CONFIG_DIR}/config.json"

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

short_id(){
    od -An -N8 -tx1 /dev/urandom | tr -d ' \n'
}

reality_key(){
    result=$(${XRAY_BIN} x25519)

    PRIVATE_KEY=$(echo "$result" | awk -F': ' '/PrivateKey/{print $2}')
    PUBLIC_KEY=$(echo "$result" | awk -F': ' '/Password/{print $2}')

    SHORT_ID=$(short_id)
}

install_xray(){

    apk add --no-cache bash curl unzip ca-certificates

    mkdir -p ${XRAY_HOME} ${XRAY_CONFIG_DIR}

    VERSION=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest |
    grep tag_name |
    cut -d '"' -f4)

    ARCH=$(get_arch)

    wget -O /tmp/xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip"

    unzip -o /tmp/xray.zip -d /tmp/xray

    install -m755 /tmp/xray/xray ${XRAY_BIN}

    read -p "请输入UUID(留空自动生成): " UUID

    if [ -z "$UUID" ]; then
        UUID=$(${XRAY_BIN} uuid)
    fi

    reality_key

    read -p "Reality SNI [www.dlcci.cn]: " SNI
    SNI=${SNI:-www.dlcci.cn}


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
   "port":53999,
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
   "port":53666,
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

echo "安装完成"
echo "UUID: ${UUID}"
echo "PublicKey: ${PUBLIC_KEY}"
echo "ShortID: ${SHORT_ID}"
}


regenerate(){

    reality_key

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

    echo "Reality参数已重新生成"
    echo "PublicKey: ${PUBLIC_KEY}"
    echo "ShortID: ${SHORT_ID}"
}


menu(){
    echo "1. 安装Xray Reality"
    echo "2. 重新生成X25519和ShortID"
    echo "0. 退出"

    read -p "> " choice

    case $choice in
        1) install_xray ;;
        2) regenerate ;;
        0) exit ;;
        *) menu ;;
    esac
}

[ "$(id -u)" = "0" ] || exit 1

menu
