cd /etc/autoxray
wget https://raw.githubusercontent.com/Weoworks/privacy/refs/heads/main/shadowsocks.json
mv shadowsocks.json config.json
systemctl restart autoxray
