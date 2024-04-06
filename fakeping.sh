#!/bin/bash

# 检查路由文件中是否包含 "geoip:private"
check=$(sed -n '/"ip": \["geoip:private"\]/=' /etc/XrayR/route.json)

echo -e "我知道设置这个没用，但是我还是设置了"
read -p "您确定要设置本服务器吗？(Y/N): " yorn

if [[ "${yorn}" == "y" || "${yorn}" == "Y" ]]; then
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    if [ -n "$check" ]; then
        # 使用 sed 替换 JSON 文件中的内容
        sed -i "${check} s/\"outboundTag\": .*/\"outboundTag\": \"IPv4_out\",/" /etc/XrayR/route.json
    fi
    echo -e "添加成功~"
else
    echo -e "正在关闭..."
fi
