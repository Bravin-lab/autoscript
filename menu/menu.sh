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

# Function to fetch disk usage
get_disk_usage() {
    disk_info=$(df -h / | awk 'NR==2{print $2, $3, $5}')
    disk_total=$(echo "$disk_info" | awk '{print $1}')
    disk_used=$(echo "$disk_info" | awk '{print $2}')
    disk_percent=$(echo "$disk_info" | awk '{print $3}')
}

# Function to fetch system load
get_system_load() {
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    load_1=$(echo "$load_avg" | awk '{print $1}' | sed 's/,//')
}

# Function to check service alerts
check_service_alerts() {
    alerts=""
    systemctl is-active --quiet nginx || alerts="${alerts}NGINX "
    systemctl is-active --quiet xray || alerts="${alerts}XRAY "
    systemctl is-active --quiet stunnel4 || alerts="${alerts}STUNNEL "
    systemctl is-active --quiet ssh || alerts="${alerts}SSH "
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
    get_disk_usage
    get_system_load

    echo -e "\e[1;34m                   NT CPU/RAM/DISK INFO                  \e[0m"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e "\e[1;32m CPU USAGE   \e[0m: $cpu_usage"
    echo -e "\e[1;32m RAM USED    \e[0m: ${uram} MB / ${tram} MB"
    echo -e "\e[1;32m DISK USED   \e[0m: ${disk_used} / ${disk_total} (${disk_percent})"
    echo -e "\e[1;32m LOAD AVG    \e[0m: ${load_avg}"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
}

# Function to display menu and handle user input
show_menu() {
    clear
    show_vps_info
    show_cpu_ram_info

    # small helper: check unit active
    svc() { systemctl is-active --quiet "$1" >/dev/null 2>&1 && echo -e "\\e[1;32m✓ ON\\e[0m" || echo -e "\\e[1;31m✗ OFF\\e[0m"; }
    svc_col() { systemctl is-active --quiet "$1" >/dev/null 2>&1 && echo -e "\\e[1;32m" || echo -e "\\e[1;31m"; }

    nginx_s=$(svc nginx)
    xray_s=$(svc xray)
    stunnel_s=$(svc stunnel4)
    wsstun_s=$(svc ws-stunnel.service)
    dropbear_s=$(svc dropbear)
    ssh_s=$(svc ssh)

    # Header — CREATIVE TITLE with styling (now includes branding)
    echo -e "\\e[1;36m╔══════════════════════════════════════════════════════════════╗\\e[0m"
    echo -e "\\e[1;35m║                      POWERED BY BRAVIN                      ║\\e[0m"
    echo -e "\\e[1;36m╠══════════════════════════════════════════════════════════════╣\\e[0m"
    echo -e "\\e[1;35m║              NT VIP AIO TERMINAL MANAGEMENT v2.0             ║\\e[0m"
    echo -e "\\e[1;36m╠══════════════════════════════════════════════════════════════╣\\e[0m"
    echo -e "\\e[1;36m║                    [ MANAGEMENT DASHBOARD ]                  ║\\e[0m"
    echo -e "\\e[1;36m╚══════════════════════════════════════════════════════════════╝\\e[0m"

    # Live Service Status with status colors
    printf "\\n"
    echo -e "\\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\e[0m"
    echo -e "\\e[1;33m [ SERVICE STATUS ]\\e[0m"
    echo -e "\\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\e[0m"
    echo -e "  SSH............: ${ssh_s}  │  NGINX........: ${nginx_s}  │  XRAY........: ${xray_s}"
    echo -e "  STUNNEL........: ${stunnel_s}  │  WS-TLS.......: ${wsstun_s}  │  DROPBEAR....: ${dropbear_s}"
    echo -e "\\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\e[0m"

    # Service Alerts — check for DOWN services
    check_service_alerts
    if [ -n "$alerts" ]; then
        echo -e "\\e[1;31m⚠ WARNING: The following services are DOWN: ${alerts}\\e[0m"
        echo -e "\\e[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\e[0m"
    fi

    # Color-coded Menu Categories
    printf "\\n"
    echo -e "\\e[1;32m┌─ CONNECTION SERVICES ─────────────────────────────────────┐\\e[0m"
    echo -e "\\e[1;32m│  \\e[0m\\e[1;36m[1]\\e[0m  SSH / OpenVPN Menu   \\e[1;32m│  \\e[0m\\e[1;36m[2]\\e[0m  VMess Menu         \\e[1;32m│\\e[0m"
    echo -e "\\e[1;32m│  \\e[0m\\e[1;36m[3]\\e[0m  Trojan Menu         \\e[1;32m│  \\e[0m\\e[1;36m[4]\\e[0m  Shadowsocks Menu   \\e[1;32m│\\e[0m"
    echo -e "\\e[1;32m└────────────────────────────────────────────────────────────┘\\e[0m"

    echo -e "\\e[1;34m┌─ SYSTEM & UTILITIES ───────────────────────────────────────┐\\e[0m"
    echo -e "\\e[1;34m│  \\e[0m\\e[1;36m[5]\\e[0m  Advanced Settings    \\e[1;34m│  \\e[0m\\e[1;36m[6]\\e[0m  Service Status     \\e[1;34m│\\e[0m"
    echo -e "\\e[1;34m│  \\e[0m\\e[1;36m[7]\\e[0m  Clear Cache         \\e[1;34m│  \\e[0m\\e[1;36m[8]\\e[0m  Reboot System      \\e[1;34m│\\e[0m"
    echo -e "\\e[1;34m└────────────────────────────────────────────────────────────┘\\e[0m"

    echo -e "\\e[1;31m┌─ EXIT ─────────────────────────────────────────────────────┐\\e[0m"
    echo -e "\\e[1;31m│  \\e[0m\\e[1;36m[x]\\e[0m  Exit Menu                                          \\e[1;31m│\\e[0m"
    echo -e "\\e[1;31m└────────────────────────────────────────────────────────────┘\\e[0m"

    # Footer with user info
    echo -e "\\n\\e[1;37m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\\e[0m"
    echo -e "\\e[1;37m┃  User: $Name  │  Expiry: $Exp2  │  Domain: $(cat /etc/xray/domain)\\e[0m"
    echo -e "\\e[1;37m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\\e[0m"

    # prompt (same behavior)
    read -p " $(echo -e '\\e[1;33m>>\\e[0m') Select menu :  " opt
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