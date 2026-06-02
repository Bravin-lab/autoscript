#!/bin/bash

# Icon helpers
icon_ok() { echo -e "\033[0;32m✔\033[0m"; }
icon_bad() { echo -e "\033[0;31m✘\033[0m"; }

# Function to count connected users
# Uses `who` output (works for SSH/Dropbear sessions)
get_connected_users() {
    if command -v who >/dev/null 2>&1; then
        # who output lines correspond to active logged-in sessions
        who | awk 'NF>=6{c++} END{print c+0}'
    else
        echo 0
    fi
}

# Function to get service status with tick/cross
get_service_status() {
    # $1 = label (what to print), $2 = unit/service name (systemctl), $3 = optional init.d script path
    local label="$1"
    local unit="$2"
    local initd="$3"

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$unit" 2>/dev/null; then
            echo "$(icon_ok) $label"
        else
            echo "$(icon_bad) $label"
        fi
        return 0
    fi

    # init.d fallback (if provided)
    if [ -n "$initd" ] && [ -f "$initd" ]; then
        if "$initd" status 2>/dev/null | grep -qi "active"; then
            echo "$(icon_ok) $label"
        else
            echo "$(icon_bad) $label"
        fi
        return 0
    fi

    echo "$(icon_bad) $label"
}

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

    echo -e "\e[1;34m                  ┏━━━━━━━━━━━━━━━━━━━━━━━┓                  \e[0m"
    echo -e "\e[1;34m                  ┃      MAIN  MENU       ┃                  \e[0m"
    echo -e "\e[1;34m                  ┗━━━━━━━━━━━━━━━━━━━━━━━┛                  \e[0m"
    echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;36m┃  [1] Menu SSH           ┃  [6] Status Service   ┃\e[0m"
    echo -e "\e[1;36m┃  [2] Menu Vmess         ┃  [7] Clear RAM Cache  ┃\e[0m"
    echo -e "\e[1;36m┃  [3] Menu Vless         ┃  [8] Reboot VPS       ┃\e[0m"
    echo -e "\e[1;36m┃  [4] Menu Trojan        ┃  [9] Exit Script      ┃\e[0m"
    echo -e "\e[1;36m┃  [5] Menu Shadowsocks   ┃                      ┃\e[0m"
    echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;32m Client Name \e[0m: $Name"
    echo -e "\e[1;32m Expired     \e[0m: $Exp2"
    echo -e "\e[1;32m Connected   \e[0m: $(get_connected_users) users"

    # Service status (tick/cross)
    # XRAY (xray.service)
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "XRAY" "xray.service")"
    # Dropbear
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "Dropbear" "dropbear.service" "/etc/init.d/dropbear")"
    # Websocket services
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "ws-stunnel" "ws-stunnel.service")"
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "ws-dropbear" "ws-dropbear.service")"
    # Fail2ban
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "fail2ban" "fail2ban.service" "/etc/init.d/fail2ban")"
    # Cron
    echo -e "\e[1;32m Service     \e[0m: $(get_service_status "cron" "cron.service" "/etc/init.d/cron")"

    echo -e "\e[1;32m POWERED BY  \e[0m: BRAVIN"
    echo -e "\e[1;32m MADE BY     \e[0m: BRAVIN"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e ""
    read -p " Select menu :  " opt
    echo ""
    case $opt in
    1) clear ; m-sshovpn ;;
    2) clear ; m-vmess ;;
    3) clear ; m-vless ;;
    4) clear ; m-trojan ;;
    5) clear ; m-ssws ;;
    6) clear ; m-system ;;
    7) clear ; running ;;
    8) clear ; clearcache ;;
    9) clear ; /sbin/reboot ;;
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