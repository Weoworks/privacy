#!/usr/bin/env bash
# 修改版：给 xray_all.sh 生成的 config.json 增加 Shadowsocks 出站（outbound）
# 用法：运行此脚本后，会在 /usr/local/etc/xray/config.json 中新增 shadowsocks 出站

SS_SERVER="199.30.88.156"
SS_PORT=53888
SS_PASSWORD="199.30.88.156"
SS_METHOD="aes-256-gcm"

XRAY_CONFIG="/usr/local/etc/xray/config.json"

if [ ! -f "$XRAY_CONFIG" ]; then
    echo "错误：找不到 $XRAY_CONFIG，请先运行原 xray_all.sh 安装脚本。"
    exit 1
fi

python3 << 'PY'
import json, sys

SS_SERVER = "199.30.88.156"
SS_PORT = 53888
SS_PASSWORD = "199.30.88.156"
SS_METHOD = "aes-256-gcm"

with open("/usr/local/etc/xray/config.json", "r") as f:
    c = json.load(f)

# 添加 Shadowsocks 出站
ss_outbound = {
    "protocol": "shadowsocks",
    "tag": "shadowsocks-out",
    "settings": {
        "servers": [
            {
                "address": SS_SERVER,
                "port": SS_PORT,
                "method": SS_METHOD,
                "password": SS_PASSWORD
            }
        ]
    }
}

c.setdefault("outbounds", [])
# 避免重复添加同名 tag
if not any(i.get("tag") == "shadowsocks-out" for i in c["outbounds"]):
    c["outbounds"].append(ss_outbound)

with open("/usr/local/etc/xray/config.json", "w") as f:
    json.dump(c, f, indent=2)

print("已成功向", "/usr/local/etc/xray/config.json", "添加 Shadowsocks 出站:")
print("  tag:", ss_outbound["tag"])
print("  server:", SS_SERVER)
print("  port:", SS_PORT)
print("  method:", SS_METHOD)
print("  password:", SS_PASSWORD[:8] + "***")
PY

echo ""
echo "提示：修改后请重启 xray 服务生效。"
echo "例如执行：systemctl restart xray  或  rc-service xray restart"