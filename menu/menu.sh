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

draw_box_title() {
    local title="$1"
    local inner_width=47
    local title_len=${#title}
    local left_pad=0
    local right_pad=0

    if [ "$title_len" -lt "$inner_width" ]; then
        left_pad=$(((inner_width - title_len) / 2))
        right_pad=$((inner_width - title_len - left_pad))
    fi

    printf '\e[1;36m╔═════════════════════════════════════════════════╗\e[0m\n'
    printf '\e[1;36m║\e[1;33m%*s%s%*s\e[0m\e[1;36m║\e[0m\n' "$left_pad" "" "$title" "$right_pad" ""
    printf '\e[1;36m╚═════════════════════════════════════════════════╝\e[0m\n'
}

draw_value_line() {
    local label="$1"
    local value="$2"
    printf '\e[1;32m  %-13s\e[0m: %b\n' "$label" "$value"
}

draw_menu_row() {
    local left="$1"
    local right="$2"
    printf '\e[1;36m  %-26s %-26s\e[0m\n' "$left" "$right"
}

draw_right_mascot() {
    return 0
}

show_vps_info() {
    clear
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    uptime=$(uptime -p | cut -d " " -f 2-10)
    DATE2=$(date +%d/%m/%Y)
    TIME2=$(date +%H:%M:%S)
    IPVPS=$(curl -s ifconfig.me)
    ISP=$(curl -s ifconfig.co/org 2>/dev/null || echo "Unknown")
    CITY=$(curl -s "https://ipapi.co/${IPVPS}/city" 2>/dev/null || echo "Unknown")
    LOC=$(curl -sS "https://api.country.is/${IPVPS}" | jq -r '.country' 2>/dev/null)
    if [ -z "$LOC" ] || [ "$LOC" = "null" ]; then
        LOC="Unknown"
    fi

    draw_box_title "AUTOSCRIPT KINGS"
    echo ""
    echo -e "\e[1;36m╔═════════════════════════════════════════════════╗\e[0m"
    draw_value_line "ISP" "$ISP"
    draw_value_line "CITY" "$CITY"
    draw_value_line "DATE" "$DATE2"
    draw_value_line "TIME" "$TIME2"
    echo -e "\e[1;36m╚═════════════════════════════════════════════════╝\e[0m"
    echo ""
}

show_cpu_ram_info() {
    get_ram_info
    get_cpu_usage

    draw_box_title "SYSTEM RESOURCES"
    draw_value_line "CPU Usage" "$cpu_usage"
    draw_value_line "RAM Used" "${uram} MB / ${tram} MB"
    echo ""
}

show_menu() {
    clear
    show_vps_info
    show_cpu_ram_info

    draw_box_title "PROTOCOL MANAGEMENT"
    draw_menu_row "[1] Menu SSH" "[4] Menu Trojan"
    draw_menu_row "[2] Menu Vmess" "[5] Menu Shadowsocks"
    draw_menu_row "[3] Menu Vless" "[6] Menu UDP"
    echo ""
    draw_box_title "SYSTEM & UTILITIES"
    draw_menu_row "[7] System Menu" "[9] Clear RAM Cache"
    draw_menu_row "[8] Status Service" "[10] Reboot VPS"
    printf '\e[1;36m  [11] Exit\e[0m\n'
    echo ""
    draw_box_title "ACCOUNT DETAILS"
    draw_value_line "Client Name" "\e[1;33m$Name\e[0m"
    draw_value_line "Expired" "\e[1;33m$Exp2\e[0m"
    draw_value_line "Connected" "\e[1;33m$(get_connected_users) users\e[0m"
    echo ""
    draw_box_title "SERVICE STATUS"
    draw_value_line "XRAY" "$(get_service_status "●" "xray.service")"
    draw_value_line "Dropbear" "$(get_service_status "●" "dropbear.service" "/etc/init.d/dropbear")"
    draw_value_line "WS Stunnel" "$(get_service_status "●" "ws-stunnel.service")"
    draw_value_line "WS Dropbear" "$(get_service_status "●" "ws-dropbear.service")"
    draw_value_line "UDP Custom" "$(get_service_status "●" "udp-custom.service")"
    draw_value_line "Fail2Ban" "$(get_service_status "●" "fail2ban.service" "/etc/init.d/fail2ban")"
    draw_value_line "Cron" "$(get_service_status "●" "cron.service" "/etc/init.d/cron")"
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
