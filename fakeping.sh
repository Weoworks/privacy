#/bin/bash
echo -e "我知道设置这个没用，但是我还是设置了"
read -p "您确定要设置本服务器吗？(Y/N):" yorn
if [[ x"${yorn}" == x"y" || x"${yorn}" == x"Y" ]]; then
echo -e "127.0.0.1 gstatic.com" >> /etc/hosts
echo -e "127.0.0.1 gstatic.com" >> /etc/hosts
echo -e "添加成功~"
else
   echo -e "正在关闭..."
