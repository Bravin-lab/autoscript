#!/bin/bash

# Function to fetch RAM information
get_ram_info() {
    ram_info=$(free -m | awk 'NR==2{print $2,$3}')
    tram=$(echo "$ram_info" | awk '{print $1}')
    uram=$(echo "$ram_info" | awk '{print $2}')
}

# Function to fetch CPU usage information
get_cpu_usage() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu_usage=$(echo "$cpu_usage" | awk '{printf "%.2f", $1}')
    cpu_usage+=" %"
}

# Function to display VPS information
show_vps_info() {
    clear
    domain=$(cat /etc/xray/domain)
    uptime=$(uptime -p | cut -d " " -f 2-10)
    DATE2=$(date -R | cut -d " " -f -5)
    IPVPS=$(curl -s ifconfig.me)
    LOC=$(curl -sS "https://api.country.is/${IPVPS}" | jq -r '.country')
    if [ -z "$LOC" ]; then
        LOC="Unknown"
    fi

    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e "\e[1;34m                     NT VIP AIO                    \e[0m"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e "\e[1;32m OS            \e[0m: $(hostnamectl | grep "Operating System" | cut -d ' ' -f5-)"
    echo -e "\e[1;32m Uptime        \e[0m: $uptime"
    echo -e "\e[1;32m Public IP     \e[0m: $IPVPS"
    echo -e "\e[1;32m Country       \e[0m: $LOC"
    echo -e "\e[1;32m DOMAIN        \e[0m: $domain"
    echo -e "\e[1;32m DATE & TIME   \e[0m: $DATE2"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
}

# Function to display CPU and RAM information
show_cpu_ram_info() {
    get_ram_info
    get_cpu_usage

    echo -e "\e[1;34m                   NT CPU/RAM INFO                  \e[0m"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e "\e[1;32m CPU USAGE   \e[0m: $cpu_usage"
    echo -e "\e[1;32m RAM USED    \e[0m: ${uram} MB"
    echo -e "\e[1;32m RAM TOTAL   \e[0m: ${tram} MB"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
}

# Function to display menu and handle user input
show_menu() {
    clear
    show_vps_info
    show_cpu_ram_info

    # small helper: check unit active
    svc() { systemctl is-active --quiet "$1" >/dev/null 2>&1 && echo -e "\\e[1;32mON\\e[0m" || echo -e "\\e[1;31mOFF\\e[0m"; }

    nginx_s=$(svc nginx)
    xray_s=$(svc xray)
    stunnel_s=$(svc stunnel4)
    wsstun_s=$(svc ws-stunnel.service)
    dropbear_s=$(svc dropbear)
    ssh_s=$(svc ssh)

    # Header
    echo -e "\\e[1;36m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\\e[0m"
    echo -e "\\e[1;35m┃               NT VIP AIO — DASHBOARD  (creative)           ┃\\e[0m"
    echo -e "\\e[1;36m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\\e[0m"

    # Services row
    printf "\\n"
    echo -e "\\e[1;34m[ SERVICES ]\\e[0m  SSH:[ ${ssh_s} ]  NGINX:[ ${nginx_s} ]  XRAY:[ ${xray_s} ]  STUNNEL:[ ${stunnel_s} ]"
    echo -e "\\e[1;34m                          WS-TLS:[ ${wsstun_s} ]  DROPBEAR:[ ${dropbear_s} ]\\e[0m"
    printf "\\n"

    # Menu boxes — keep commands identical, only layout changes
    echo -e "\\e[1;33m┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐\\e[0m"
    echo -e "\\e[1;32m│ [1]  SSH Menu           │  │ [2]  VMess Menu         │  │ [3]  Trojan Menu        │\\e[0m"
    echo -e "\\e[1;33m└─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘\\e[0m"
    echo -e "\\e[1;33m┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐\\e[0m"
    echo -e "\\e[1;32m│ [4]  Shadowsocks Menu   │  │ [5]  Settings           │  │ [6]  Status Service     │\\e[0m"
    echo -e "\\e[1;33m└─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘\\e[0m"

    echo -e "\\n\\e[1;34m┌──────────────────────────────────────────────────────────────┐\\e[0m"
    echo -e "\\e[1;36m│ [7] Clear RAM Cache   [8] Reboot VPS   [x] Exit              │\\e[0m"
    echo -e "\\e[1;34m└──────────────────────────────────────────────────────────────┘\\e[0m"

    # Footer info (client/name etc.)
    echo -e "\\n\\e[1;32m Client : $Name    Expire: $Exp2    DOMAIN: $(cat /etc/xray/domain)\\e[0m"
    echo -e "\\e[1;33m---------------------------------------------------------------\\e[0m"

    # prompt (same behavior)
    read -p " Select menu :  " opt
    echo ""
    case $opt in
    1) clear ; m-sshovpn ;;
    2) clear ; m-vmess ;;
    3) clear ; m-trojan ;;
    4) clear ; m-ssws ;;
    5) clear ; m-system ;;
    6) clear ; running ;;
    7) clear ; clearcache ;;
    8) clear ; /sbin/reboot ;;
    x) exit ;;
    *) echo "Invalid selection" ; sleep 1 ;;
    esac
}

# Initial setup
domain=$(cat /etc/xray/domain)
Exp2="NONE"
Name="BRAVIN"

# Main loop to display menu continuously
while true; do
    show_menu
done