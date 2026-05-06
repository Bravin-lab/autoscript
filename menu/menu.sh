#!/bin/bash

# Color status indicator function
get_status_color() {
    local value=$1
    local threshold1=$2
    local threshold2=$3
    
    if (( $(echo "$value < $threshold1" | bc -l) )); then
        echo -e "\e[1;32m●\e[0m"  # Green
    elif (( $(echo "$value < $threshold2" | bc -l) )); then
        echo -e "\e[1;33m●\e[0m"  # Yellow
    else
        echo -e "\e[1;31m●\e[0m"  # Red
    fi
}

# Function to check service status
check_service_status() {
    local service=$1
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "\e[1;32m✓\e[0m"
    else
        echo -e "\e[1;31m✗\e[0m"
    fi
}

# Get service uptime
get_service_uptime() {
    local service=$1
    if systemctl is-active --quiet $service 2>/dev/null; then
        systemctl show -p ActiveEnterTimestamp $service 2>/dev/null | cut -d= -f2 | xargs -I {} date -d "{}" +%s 2>/dev/null | {
            read timestamp
            if [ -n "$timestamp" ]; then
                echo $(($(date +%s) - timestamp))
            else
                echo 0
            fi
        }
    else
        echo "N/A"
    fi
}

# Format seconds to readable time
format_time() {
    local seconds=$1
    if [ "$seconds" = "N/A" ]; then
        echo "N/A"
        return
    fi
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local mins=$(((seconds % 3600) / 60))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${mins}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# Get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}' 
}

# Get disk percentage
get_disk_percent() {
    df -h / | awk 'NR==2 {gsub("%",""); print $5}'
}

# Get load average with color
get_load_average() {
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    local load1=$(echo $load | awk '{print $1}' | sed 's/,//')
    local status=$(get_status_color $load1 2 4)
    echo -e "${status} $load"
}

# Get RAM percentage
get_ram_percent() {
    free | awk 'NR==2 {printf "%.1f", ($3/$2)*100}'
}

# Get memory color status
get_memory_status() {
    local percent=$(get_ram_percent)
    get_status_color $percent 50 80
}

# Get active connections count
get_active_connections() {
    ss -tn 2>/dev/null | grep ESTAB | wc -l
}

# Get network interfaces bandwidth (basic)
get_bandwidth_usage() {
    if command -v ifstat &> /dev/null; then
        ifstat -i eth0,eth1 -n 1 2 | tail -1 | awk '{printf "RX: %.2f MB/s TX: %.2f MB/s", $1/1024, $2/1024}'
    else
        echo "N/A (install ifstat)"
    fi
}

# Get SSL certificate expiry
get_cert_expiry() {
    local domain=$(cat /etc/xray/domain 2>/dev/null)
    if [ -z "$domain" ]; then
        echo "N/A"
        return
    fi
    
    local cert_file="/etc/xray/cert.pem"
    if [ -f "$cert_file" ]; then
        local exp_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
        local exp_epoch=$(date -d "$exp_date" +%s 2>/dev/null)
        local now=$(date +%s)
        local days=$(( ($exp_epoch - $now) / 86400 ))
        
        if [ $days -lt 0 ]; then
            echo -e "\e[1;31mEXPIRED\e[0m"
        elif [ $days -lt 7 ]; then
            echo -e "\e[1;31m${days} days\e[0m"
        elif [ $days -lt 30 ]; then
            echo -e "\e[1;33m${days} days\e[0m"
        else
            echo -e "\e[1;32m${days} days\e[0m"
        fi
    else
        echo "N/A"
    fi
}

# Get fail2ban status
get_fail2ban_status() {
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        local banned=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "0")
        echo -e "Active (Banned IPs: $banned)"
    else
        echo -e "\e[1;33mInactive\e[0m"
    fi
}

# Get total SSH users count
get_total_users() {
    grep -c "^[^#]" /etc/passwd 2>/dev/null || echo "0"
}

# Get new users today
get_new_users_today() {
    find /home -type d -newermt "today" -user root 2>/dev/null | wc -l
}

# Get expiring accounts (within 3 days)
get_expiring_accounts() {
    local count=0
    if [ -f /etc/shadow ]; then
        while IFS=: read -r user pass lastchange expdate; do
            if [ ! -z "$expdate" ] && [ "$expdate" != "-1" ] && [ "$expdate" != "0" ]; then
                local exp_epoch=$((($expdate * 86400)))
                local now=$(date +%s)
                local days=$(( ($exp_epoch - $now) / 86400 ))
                if [ $days -le 3 ] && [ $days -gt 0 ]; then
                    count=$((count + 1))
                fi
            fi
        done < /etc/shadow
    fi
    echo $count
}

# Get system security alerts
get_security_alerts() {
    local alerts=""
    
    # Check for failed SSH attempts
    local failed=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    if [ $failed -gt 10 ]; then
        alerts="${alerts}\e[1;31m⚠ High failed SSH attempts ($failed)\e[0m\n"
    fi
    
    # Check disk space
    local disk_usage=$(get_disk_percent)
    if [ "${disk_usage%.*}" -gt 90 ]; then
        alerts="${alerts}\e[1;31m⚠ Disk space critical (${disk_usage}%)\e[0m\n"
    fi
    
    if [ -z "$alerts" ]; then
        echo -e "\e[1;32mNo alerts\e[0m"
    else
        echo -e "$alerts" | head -3
    fi
}

# Function to display Bravin branding header
show_bravin_header() {
    echo -e "\e[1;35m╔════════════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;35m║                                                            ║\e[0m"
    echo -e "\e[1;35m║     \e[1;33mScript Created and Maintained by BRAVIN VIP AIO\e[0m\e[1;35m     ║\e[0m"
    echo -e "\e[1;35m║                                                            ║\e[0m"
    echo -e "\e[1;35m╚════════════════════════════════════════════════════════════╝\e[0m"
}

# Function to display service status
show_service_status() {
    echo -e "\e[1;34m                    SERVICE STATUS                      \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m SSH            \e[0m: $(check_service_status sshd)  \e[1;32m Nginx          \e[0m: $(check_service_status nginx)"
    echo -e "\e[1;32m Xray           \e[0m: $(check_service_status xray)  \e[1;32m Stunnel4       \e[0m: $(check_service_status stunnel4)"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
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
    local disk_usage=$(get_disk_percent)
    local ram_percent=$(get_ram_percent)

    echo -e "\e[1;34m                 SYSTEM RESOURCES                  \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m CPU Usage   \e[0m: $(get_status_color ${cpu_usage%% *} 50 80) $cpu_usage"
    echo -e "\e[1;32m RAM Usage   \e[0m: $(get_memory_status) ${ram_percent}% (${uram}MB/${tram}MB)"
    echo -e "\e[1;32m Disk Usage  \e[0m: $(get_status_color $disk_usage 75 90) ${disk_usage}% ($(get_disk_usage))"
    echo -e "\e[1;32m Load Avg    \e[0m: $(get_load_average)"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Display service health and statistics
show_service_health() {
    echo -e "\e[1;34m              SERVICE HEALTH & UPTIME               \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    
    local sshd_uptime=$(format_time $(get_service_uptime sshd))
    local nginx_uptime=$(format_time $(get_service_uptime nginx))
    local xray_uptime=$(format_time $(get_service_uptime xray))
    local stunnel_uptime=$(format_time $(get_service_uptime stunnel4))
    
    echo -e "\e[1;32m SSH Uptime     \e[0m: $sshd_uptime"
    echo -e "\e[1;32m Nginx Uptime   \e[0m: $nginx_uptime"
    echo -e "\e[1;32m Xray Uptime    \e[0m: $xray_uptime"
    echo -e "\e[1;32m Stunnel Uptime \e[0m: $stunnel_uptime"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Display certificate information
show_certificate_info() {
    echo -e "\e[1;34m                 SSL CERTIFICATE                   \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m Certificate Expiry \e[0m: $(get_cert_expiry)"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Get currently connected SSH users
get_connected_users() {
    who | awk '{print $1, "from", $3}' | sort -u
}

# Get connected users count
get_connected_users_count() {
    who | wc -l
}

# Display active connections detail
show_network_info() {
    echo -e "\e[1;34m                 NETWORK STATUS                   \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m Total Connections   \e[0m: $(get_active_connections)"
    echo -e "\e[1;32m Connected SSH Users  \e[0m: $(get_connected_users_count)"
    
    local users=$(get_connected_users)
    if [ -n "$users" ]; then
        echo -e "\e[1;32m Active Users:\e[0m"
        echo "$users" | sed 's/^/   ├─ /'
    else
        echo -e "\e[1;32m Active Users:\e[0m    (None)"
    fi
    
    echo -e "\e[1;32m Bandwidth Usage      \e[0m: $(get_bandwidth_usage)"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Display security information
show_security_info() {
    echo -e "\e[1;34m                  SECURITY STATUS                  \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m Fail2Ban       \e[0m: $(get_fail2ban_status)"
    echo -e "\e[1;32m Security Alerts \e[0m:"
    get_security_alerts | sed 's/^/   /'
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Display user statistics
show_user_statistics() {
    echo -e "\e[1;34m                 USER STATISTICS                  \e[0m"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
    echo -e "\e[1;32m Total Users        \e[0m: $(get_total_users)"
    echo -e "\e[1;32m New Users Today    \e[0m: $(get_new_users_today)"
    echo -e "\e[1;32m Expiring Soon      \e[0m: $(get_expiring_accounts)"
    echo -e "\e[1;33m────────────────────────────────────────────────────────────\e[0m"
}

# Function to display menu and handle user input
show_menu() {
    clear
    show_bravin_header
    echo ""
    show_service_status
    echo ""
    show_vps_info
    echo ""
    show_cpu_ram_info
    echo ""
    show_service_health
    echo ""
    show_certificate_info
    echo ""
    show_network_info
    echo ""
    show_security_info
    echo ""
    show_user_statistics
    echo ""

    echo -e "\e[1;34m                  ┏━━━━━━━━━━━━━━━━━━━━━━━┓                  \e[0m"
    echo -e "\e[1;34m                  ┃      MAIN  MENU       ┃                  \e[0m"
    echo -e "\e[1;34m                  ┗━━━━━━━━━━━━━━━━━━━━━━━┛                  \e[0m"
    echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;36m┃  [1] Menu SSH           ┃  [5] Menu Setting     ┃\e[0m"
    echo -e "\e[1;36m┃  [2] Menu Vmess         ┃  [6] Status Service   ┃\e[0m"
    echo -e "\e[1;36m┃  [3] Menu Trojan        ┃  [7] Clear RAM Cache  ┃\e[0m"
    echo -e "\e[1;36m┃  [4] Menu Shadowsocks   ┃  [8] Reboot VPS       ┃\e[0m"
    echo -e "\e[1;36m┃  [x] Exit Script        ┃                      ┃\e[0m"
    echo -e "\e[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "\e[1;32m Client Name \e[0m: $Name"
    echo -e "\e[1;32m Expired     \e[0m: $Exp2"
    echo -e "\e[1;32m POWERED BY  \e[0m: BRAVIN"
    echo -e "\e[1;32m MADE BY     \e[0m: BRAVIN"
    echo -e "\e[1;33m -------------------------------------------------\e[0m"
    echo -e ""
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