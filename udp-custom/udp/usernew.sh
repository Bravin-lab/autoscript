#!/bin/bash
MYIP=$(wget -qO- ipv4.icanhazip.com);
echo "Checking VPS"
clear
cekray=`cat /root/log-install.txt | grep -ow "XRAY" | sort | uniq`
if [ "$cekray" = "XRAY" ]; then
domen=`cat /etc/xray/domain`
else
domen=`cat /etc/v2ray/domain`
fi
portsshws=`cat ~/log-install.txt | grep -w "SSH Websocket" | cut -d: -f2 | awk '{print $1}'`
wsssl=`cat /root/log-install.txt | grep -w "SSH SSL Websocket" | cut -d: -f2 | awk '{print $1}'`

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m           NT UDP Account           \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "Username : " Login
read -p "Password : " Pass
read -p "Expired (hari): " masaaktif

IP=$(curl -sS ifconfig.me);
opensh=`cat /root/log-install.txt | grep -w "OpenSSH" | cut -f2 -d: | awk '{print $1}'`
db=`cat /root/log-install.txt | grep -w "Dropbear" | cut -f2 -d: | awk '{print $1,$2}'`
ssl="$(cat ~/log-install.txt | grep -w "Stunnel4" | cut -d: -f2)"
sqd="$(cat ~/log-install.txt | grep -w "Squid" | cut -d: -f2)"
export ovpn="$(netstat -nlpt | grep -i openvpn | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2)"
OhpSSH=`cat /root/log-install.txt | grep -w "OHP SSH" | cut -d: -f2 | awk '{print $1}'`
OhpDB=`cat /root/log-install.txt | grep -w "OHP DBear" | cut -d: -f2 | awk '{print $1}'`
OhpOVPN=`cat /root/log-install.txt | grep -w "OHP OpenVPN" | cut -d: -f2 | awk '{print $1}'`

sleep 1
clear
useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $Login
exp="$(chage -l $Login | grep "Account expires" | awk -F": " '{print $2}')"
echo -e "$Pass\n$Pass\n"|passwd $Login &> /dev/null

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "\E[0;41;36m           NT UDP Account           \E[0m" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "Username    : $Login" | tee -a /etc/log-create-udp.log
echo -e "Password    : $Pass" | tee -a /etc/log-create-udp.log
echo -e "Expired On  : $exp" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "IP          : $IP" | tee -a /etc/log-create-udp.log
echo -e "Host        : $domen" | tee -a /etc/log-create-udp.log
echo -e "OpenSSH     : $opensh" | tee -a /etc/log-create-udp.log
echo -e "SSH WS      : $portsshws" | tee -a /etc/log-create-udp.log
echo -e "SSH SSL WS  : $wsssl" | tee -a /etc/log-create-udp.log
echo -e "SSL/TLS     :$ssl" | tee -a /etc/log-create-udp.log
echo -e "UDPGW       : 7100-7900" | tee -a /etc/log-create-udp.log
echo -e "UDP Custom  : 1-65350" | tee -a /etc/log-create-udp.log
echo -e "Port NS     : ALL Port (22, 445, 143)" | tee -a /etc/log-create-udp.log
echo -e "Squid Proxy :$sqd" | tee -a /etc/log-create-udp.log
echo -e "OpenVPN TCP : 1194" | tee -a /etc/log-create-udp.log
echo -e "OpenVPN UDP : 2200" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "\E[0;41;36m         INFO UDP Custom            \E[0m" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "$domen:1-65350@$Login:$Pass" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "\E[0;41;36m          CONFIG OPENVPN            \E[0m" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo -e "OpenVPN TCP : http://$MYIP:81/client-tcp-1194.ovpn" | tee -a /etc/log-create-udp.log
echo -e "" | tee -a /etc/log-create-udp.log
echo -e "OpenVPN UDP : http://$MYIP:81/client-udp-2200.ovpn" | tee -a /etc/log-create-udp.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-udp.log
echo "" | tee -a /etc/log-create-udp.log
read -n 1 -s -r -p "Press any key to back on menu"
m-udp