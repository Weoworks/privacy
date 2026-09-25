#!/usr/bin/env bash
# 修改版：给 xray_all.sh 生成的 config.json 增加 Shadowsocks 入站（inbound）
# 用法：运行此脚本后，会在 /usr/local/etc/xray/config.json 中新增 shadowsocks 入站
# 参数（按用户要求固定）：
#   端口: 53888
#   密码: 5e226409-60a2-4479-a314-67494fd71fae
#   加密方法: aes-256-gcm
#   协议: auto（默认不写协议字段，用 xray 默认行为）

SS_PORT=53888
SS_PASSWORD="5e226409-60a2-4479-a314-67494fd71fae"
SS_METHOD="aes-256-gcm"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

if [ ! -f "$XRAY_CONFIG" ]; then
    echo "错误：找不到 $XRAY_CONFIG，请先运行原 xray_all.sh 安装脚本（选 1 安装）。"
    exit 1
fi

python3 << 'PY'
import json, sys

SS_PORT = 53888
SS_PASSWORD = "5e226409-60a2-4479-a314-67494fd71fae"
SS_METHOD = "aes-256-gcm"

with open("/usr/local/etc/xray/config.json", "r") as f:
    c = json.load(f)

# 添加 Shadowsocks 入站到 inbounds 数组末尾
ss_inbound = {
    "tag": "shadowsocks-in",
    "port": SS_PORT,
    "protocol": "shadowsocks",
    "settings": {
        "method": SS_METHOD,
        "password": SS_PASSWORD,
        "network": "tcp,udp",
        "level": 0
    },
    "streamSettings": {
        "network": "tcp"
    }
}

c.setdefault("inbounds", [])
# 避免重复添加同名 tag
if not any(i.get("tag") == "shadowsocks-in" for i in c["inbounds"]):
    c["inbounds"].append(ss_inbound)

with open("/usr/local/etc/xray/config.json", "w") as f:
    json.dump(c, f, indent=2)

print("已成功向", "/usr/local/etc/xray/config.json", "添加 Shadowsocks 入站:")
print("  tag:", ss_inbound["tag"])
print("  port:", SS_PORT)
print("  method:", SS_METHOD)
print("  password:", SS_PASSWORD[:8] + "***")
PY

echo ""
echo "提示：修改后请重启 xray 服务生效。"
echo "例如执行：systemctl restart xray  或  rc-service xray restart"
