#!/bin/bash
check=$(awk 'NR==8{if($0~/"geoip:private"/) print "true"; else print "false"}' /etc/XrayR/route.json)

echo -e "我知道设置这个没用，但是我还是设置了"
read -p "您确定要设置本服务器吗？(Y/N): " yorn

if [[ "${yorn}" == "y" || "${yorn}" == "Y" ]]; then
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    echo -e "127.0.0.1 gstatic.com" | sudo tee -a /etc/hosts >/dev/null
    if [ "$check" == "true" ]; then
        awk 'NR==6{$0="      \"outboundTag\": \"IPv4_out\","}1' /etc/XrayR/route.json > /etc/XrayR/route.json.temp && mv /etc/XrayR/route.json.temp /etc/XrayR/route.json
    fi
    echo -e "添加成功~"
else
    echo -e "正在关闭..."
fi
