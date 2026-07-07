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

# FIX #1: get_cpu_usage was called but never defined. Added here.
get_cpu_usage() {
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8"%"}')
    else
        cpu_usage="N/A"
    fi
}

get_ram_info() {
    ram_info=$(free -m | awk 'NR==2{print $2,$3}')
    tram=$(echo "$ram_info" | awk '{print $1}')
    uram=$(echo "$ram_info" | awk '{print $2}')
}

draw_box_title() {
    local title="$1"
    local inner_width=51
    local title_len=${#title}
    local left_pad=0
    local right_pad=0

    if [ "$title_len" -lt "$inner_width" ]; then
        left_pad=$(((inner_width - title_len) / 2))
        right_pad=$((inner_width - title_len - left_pad))
    fi

    printf '\033[1;36m+%s+\033[0m\n' "$(printf '=%.0s' $(seq 1 $inner_width))"
    printf '\033[1;36m|\033[1;33m%*s%s%*s\033[0m\033[1;36m|\033[0m\n' "$left_pad" "" "$title" "$right_pad" ""
    printf '\033[1;36m+%s+\033[0m\n' "$(printf '=%.0s' $(seq 1 $inner_width))"
}

draw_value_line() {
    local label="$1"
    local value="$2"
    printf '\033[1;32m  %-13s\033[0m: %b\n' "$label" "$value"
}

draw_menu_row() {
    local left="$1"
    local right="$2"
    printf '\033[1;36m  %-26s %-26s\033[0m\n' "$left" "$right"
}

draw_right_mascot() {
    return 0
}

# STYLE: block-character progress bar for CPU/RAM usage.
# Purely presentational — takes a percentage in, returns colored bar text out.
draw_bar() {
    local percent="$1"       # 0-100
    local width="${2:-20}"   # bar width in characters
    local filled empty bar color

    # clamp to 0-100 in case of odd input
    [ "$percent" -lt 0 ] 2>/dev/null && percent=0
    [ "$percent" -gt 100 ] 2>/dev/null && percent=100

    filled=$(( percent * width / 100 ))
    empty=$(( width - filled ))

    color="\033[0;32m"  # green
    if [ "$percent" -ge 80 ]; then
        color="\033[0;31m"   # red
    elif [ "$percent" -ge 50 ]; then
        color="\033[0;33m"   # yellow
    fi

    bar=""
    if [ "$filled" -gt 0 ]; then
        bar=$(printf '█%.0s' $(seq 1 $filled) 2>/dev/null)
    fi
    if [ "$empty" -gt 0 ]; then
        bar+=$(printf '░%.0s' $(seq 1 $empty) 2>/dev/null)
    fi

    printf "${color}%s\033[0m" "$bar"
}

# FIX #2: network info (IP/ISP/city/country) is now fetched ONCE and cached
# to a file with a TTL, instead of hitting 4 external APIs on every redraw.
VPS_INFO_CACHE="/tmp/.vps_info_cache"
VPS_INFO_TTL=3600  # seconds; refresh once an hour

# FIX #4: some endpoints (notably ifconfig.co) sit behind Cloudflare and will
# serve a "Just a moment..." JS-challenge page to requests with no/blank
# User-Agent instead of the plain-text value we expect. A browser-like UA
# makes that far less likely.
_curl_ua=(-s --max-time 3 -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36")

# FIX #5: even with a proper UA, any of these free endpoints can still
# occasionally rate-limit or challenge us. Rather than trusting the raw
# response, reject anything that looks like HTML/a challenge page and fall
# back to a safe placeholder instead of caching/displaying garbage.
_sanitize_field() {
    local val="$1" fallback="$2"
    if [ -z "$val" ] || printf '%s' "$val" | grep -qi -e '<html' -e '<!doctype' -e 'cf-chl' -e 'just a moment'; then
        echo "$fallback"
    else
        echo "$val"
    fi
}

refresh_vps_info_cache() {
    local ipvps isp city loc

    ipvps=$(curl "${_curl_ua[@]}" ifconfig.me)
    ipvps=$(_sanitize_field "$ipvps" "Unknown")

    isp=$(curl "${_curl_ua[@]}" ifconfig.co/org 2>/dev/null)
    isp=$(_sanitize_field "$isp" "Unknown")

    city=$(curl "${_curl_ua[@]}" "https://ipapi.co/${ipvps}/city" 2>/dev/null)
    city=$(_sanitize_field "$city" "Unknown")

    if command -v jq >/dev/null 2>&1; then
        loc=$(curl -sS --max-time 3 -A "Mozilla/5.0" "https://api.country.is/${ipvps}" 2>/dev/null | jq -r '.country' 2>/dev/null)
    else
        loc=""
    fi
    loc=$(_sanitize_field "$loc" "Unknown")
    [ "$loc" = "null" ] && loc="Unknown"

    printf '%s\n%s\n%s\n%s\n%s\n' "$ipvps" "$isp" "$city" "$loc" "$(date +%s)" > "$VPS_INFO_CACHE"
}

load_vps_info_cache() {
    local cache_time now
    if [ -f "$VPS_INFO_CACHE" ]; then
        cache_time=$(sed -n '5p' "$VPS_INFO_CACHE")
        now=$(date +%s)
        if [ -n "$cache_time" ] && [ $((now - cache_time)) -lt "$VPS_INFO_TTL" ]; then
            IPVPS=$(sed -n '1p' "$VPS_INFO_CACHE")
            ISP=$(sed -n '2p' "$VPS_INFO_CACHE")
            CITY=$(sed -n '3p' "$VPS_INFO_CACHE")
            LOC=$(sed -n '4p' "$VPS_INFO_CACHE")
            return 0
        fi
    fi
    return 1
}

show_vps_info() {
    clear
    domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
    uptime=$(uptime -p | cut -d " " -f 2-10)
    DATE2=$(date +%d/%m/%Y)
    TIME2=$(date +%H:%M:%S)

    if ! load_vps_info_cache; then
        refresh_vps_info_cache
        load_vps_info_cache
    fi

    draw_box_title "AUTOSCRIPT KINGS"
    echo ""
    draw_box_title "SERVER INFO"
    draw_value_line "ISP" "$ISP"
    draw_value_line "CITY" "$CITY"
    draw_value_line "DATE" "$DATE2"
    draw_value_line "TIME" "$TIME2"
    echo ""
}

show_cpu_ram_info() {
    get_ram_info
    get_cpu_usage

    # STYLE: strip trailing % from cpu_usage for bar math, but the
    # original $cpu_usage value/format is still used as fallback display text.
    local cpu_pct="${cpu_usage%\%}"
    local ram_pct=0
    if [ "$tram" -gt 0 ] 2>/dev/null; then
        ram_pct=$(( uram * 100 / tram ))
    fi

    draw_box_title "SYSTEM RESOURCES"
    if [[ "$cpu_pct" =~ ^[0-9]+$ ]]; then
        printf '\033[1;32m  %-13s\033[0m: [%s] %s%%\n' "CPU Usage" "$(draw_bar "$cpu_pct" 20)" "$cpu_pct"
    else
        draw_value_line "CPU Usage" "$cpu_usage"
    fi
    printf '\033[1;32m  %-13s\033[0m: [%s] %s MB / %s MB\n' "RAM Used" "$(draw_bar "$ram_pct" 20)" "$uram" "$tram"
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
    printf '\033[1;36m  [11] Exit\033[0m\n'
    echo ""
    draw_box_title "ACCOUNT DETAILS"
    draw_value_line "Client Name" "\033[1;33m$Name\033[0m"
    draw_value_line "Expired" "\033[1;33m$Exp2\033[0m"
    draw_value_line "Connected" "\033[1;33m$(get_connected_users) users\033[0m"
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
    echo -e "\033[1;36m+===================================================+\033[0m"
    echo -e "\033[1;35m           Powered By: BRAVIN | Made By: BRAVIN    \033[0m"
    echo -e "\033[1;36m+===================================================+\033[0m"
    echo ""
    read -p " $(echo -e '\033[1;36m▶\033[0m Select menu: ')" opt
    echo ""
    # FIX #3: replaced recursive `show_menu` calls on invalid input with a
    # plain fallthrough so the outer `while true` loop redraws instead of
    # growing the call stack on every mistyped key.
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
    *) echo -e '\033[1;31m✗\033[0m Invalid selection. Press enter to continue...' ; read -r ;;
    esac
}

Exp2="NONE"
Name="BRAVIN"

while true; do
    show_menu
done
