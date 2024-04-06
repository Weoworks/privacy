#!/bin/bash

# 检查路由文件中是否包含 "geoip:private"
check=$(jq '.rules[].ip[]' /etc/XrayR/route.json | grep -o '"geoip:private"')

echo -e "我知道设置这个没用，但是我还是设置了"
read -p "您确定要设置本服务器吗？(Y/N): " yorn

if [[ "${yorn}" == "y" || "${yorn}" == "Y" ]]; then
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    if [ -n "$check" ]; then
        # 使用 jq 工具替换 JSON 文件中的内容
        jq '.rules[0].outboundTag = "IPv4_out"' /etc/XrayR/route.json > /etc/XrayR/route.json.temp && sudo mv /etc/XrayR/route.json.temp /etc/XrayR/route.json
    fi
    echo -e "添加成功~"
else
    echo -e "正在关闭..."
fi
