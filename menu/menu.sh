#!/bin/bash

icon_ok() { echo -e "\033[0;32mOK\033[0m"; }
icon_bad() { echo -e "\033[0;31mNO\033[0m"; }

count_openvpn_clients() {
    local count=0
    local log_file

    for log_file in /etc/openvpn/server/openvpn-tcp.log /etc/openvpn/server/openvpn-udp.log; do
        if [ -f "$log_file" ]; then
            count=$((count + $(grep -c '^CLIENT_LIST' "$log_file" 2>/dev/null || true)))
        fi
    done

    echo "$count"
}

get_connected_users() {
    local ssh_users=0
    local openvpn_users=0

    if command -v who >/dev/null 2>&1; then
        ssh_users=$(who | awk 'NF{c++} END{print c+0}')
    fi

    openvpn_users=$(count_openvpn_clients)
    echo $((ssh_users + openvpn_users))
}

get_service_status() {
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

get_ram_info() {
    ram_info=$(free -m | awk 'NR==2{print $2,$3}')
    tram=$(echo "$ram_info" | awk '{print $1}')
    uram=$(echo "$ram_info" | awk '{print $2}')
}

get_cpu_usage() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu_usage=$(echo "$cpu_usage" | awk '{printf "%.2f", $1}')
    cpu_usage+=" %"
}

draw_right_mascot() {
    local start_row="$1"
    local cols
    local mascot_width=31
    local min_cols=96
    local start_col
    local i=0

    cols=$(tput cols 2>/dev/null || echo 80)
    if [ -z "$cols" ] || [ "$cols" -lt "$min_cols" ]; then
        return 0
    fi

    start_col=$((cols - mascot_width - 1))
    [ "$start_col" -lt 56 ] && return 0

    printf '\e[s'
    while IFS= read -r line; do
        printf '\e[%s;%sH\e[1;35m%s\e[0m' "$((start_row + i))" "$start_col" "$line"
        i=$((i + 1))
    done << 'EOF'
            .-"""-.
           '       \
          |,.  ,-.  |
          |()L( ()| |
          |,'  `".| |
          |.___.',| `
         .j `--"' `  `.
        / '        '   \
       / /          `   `.
      / /            `    .
     / /              l   |
    . ,               |   |
    ,"`.             .|   |
 _.'   ``.          | `..-'l
|       `.`,        |      `.
|         `.    __.j         )
|__        |--""___|      ,-'
   `"--...,+""""   `._,.-' mh
EOF
    printf '\e[u'
}

show_vps_info() {
    clear
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    uptime=$(uptime -p | cut -d " " -f 2-10)
    DATE2=$(date -R | cut -d " " -f -5)
    IPVPS=$(curl -s ifconfig.me)
    LOC=$(curl -sS "https://api.country.is/${IPVPS}" | jq -r '.country' 2>/dev/null)
    if [ -z "$LOC" ] || [ "$LOC" = "null" ]; then
        LOC="Unknown"
    fi

    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m         AUTOSCRIPT KINGS                         \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    draw_right_mascot 3
    echo ""
    echo -e "\e[1;32m  OS            \e[0m: $(hostnamectl | grep "Operating System" | cut -d ' ' -f5-)"
    echo -e "\e[1;32m  Uptime        \e[0m: $uptime"
    echo -e "\e[1;32m  Public IP     \e[0m: $IPVPS"
    echo -e "\e[1;32m  Country       \e[0m: $LOC"
    echo -e "\e[1;32m  Domain        \e[0m: $domain"
    echo -e "\e[1;32m  Date & Time   \e[0m: $DATE2"
    echo ""
}

show_cpu_ram_info() {
    get_ram_info
    get_cpu_usage

    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m               SYSTEM RESOURCES               \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo -e "\e[1;32m  CPU Usage   \e[0m: $cpu_usage"
    echo -e "\e[1;32m  RAM Used    \e[0m: ${uram} MB / ${tram} MB"
    echo ""
}

show_menu() {
    clear
    show_vps_info
    show_cpu_ram_info

    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m               PROTOCOL MANAGEMENT            \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo -e "\e[1;36m  [1] Menu SSH           [4] Menu Trojan\e[0m"
    echo -e "\e[1;36m  [2] Menu Vmess         [5] Menu Shadowsocks\e[0m"
    echo -e "\e[1;36m  [3] Menu Vless         [6] Menu UDP\e[0m"
    echo ""
    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m               SYSTEM & UTILITIES              \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo -e "\e[1;36m  [7] System Menu        [9] Clear RAM Cache\e[0m"
    echo -e "\e[1;36m  [8] Status Service     [10] Reboot VPS\e[0m"
    echo -e "\e[1;36m  [11] Exit\e[0m"
    echo ""
    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m                ACCOUNT DETAILS               \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo -e "\e[1;32m  Client Name \e[0m: \e[1;33m$Name\e[0m"
    echo -e "\e[1;32m  Expired     \e[0m: \e[1;33m$Exp2\e[0m"
    echo -e "\e[1;32m  Connected   \e[0m: \e[1;33m$(get_connected_users) users\e[0m"
    echo ""
    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║\e[1;33m               SERVICE STATUS                \e[0m\e[1;36m║\e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo -e "\e[1;32m  XRAY       \e[0m: $(get_service_status "●" "xray.service")"
    echo -e "\e[1;32m  Dropbear   \e[0m: $(get_service_status "●" "dropbear.service" "/etc/init.d/dropbear")"
    echo -e "\e[1;32m  WS Stunnel \e[0m: $(get_service_status "●" "ws-stunnel.service")"
    echo -e "\e[1;32m  WS Dropbear\e[0m: $(get_service_status "●" "ws-dropbear.service")"
    echo -e "\e[1;32m  UDP Custom \e[0m: $(get_service_status "●" "udp-custom.service")"
    echo -e "\e[1;32m  Fail2Ban   \e[0m: $(get_service_status "●" "fail2ban.service" "/etc/init.d/fail2ban")"
    echo -e "\e[1;32m  Cron       \e[0m: $(get_service_status "●" "cron.service" "/etc/init.d/cron")"
    echo ""
    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;35m           Powered By: BRAVIN | Made By: BRAVIN    \e[0m"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo ""
    read -p " $(echo -e '\e[1;36m▶\e[0m Select menu: ')" opt
    echo ""
    case $opt in
    1) clear ; m-sshovpn ;;
    2) clear ; m-vmess ;;
    3) clear ; m-vless ;;
    4) clear ; m-trojan ;;
    5) clear ; m-ssws ;;
    6) clear ; m-udp ;;
    7) clear ; m-system ;;
    8) clear ; running ;;
    9) clear ; clearcache ;;
    10) clear ; /sbin/reboot ;;
    11) exit ;;
    x) exit ;;
    *) echo "$(echo -e '\e[1;31m✗\e[0m Invalid selection. Press enter to continue...')" ; read -r ; show_menu ;;
    esac
}

Exp2="NONE"
Name="BRAVIN"

while true; do
    show_menu
done
