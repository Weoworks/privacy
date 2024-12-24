sudo -i
mkdir /etc/autoxray
cd /etc/autoxray
wget https://raw.githubusercontent.com/Weoworks/privacy/refs/heads/main/shadowsocks.json
mv shadowsocks.json config.json
wget https://github.com/XTLS/Xray-core/releases/download/v24.11.30/Xray-linux-64.zip
apt install unzip -y
unzip Xray-linux-64.zip
wget https://raw.githubusercontent.com/Weoworks/privacy/refs/heads/main/autoxray.service
mv autoxray.service /etc/systemd/system/autoxray.service
systemctl enable autoxray
systemctl start autoxray
echo "运行完成"
