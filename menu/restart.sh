#!/bin/bash

print_header() {
    clear
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[0;100;33m         • NT RESTART MENU •          \E[0m"
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e ""
}

pause_back() {
    echo ""
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    read -n 1 -s -r -p "Press any key to back on system menu"
    restart
}

restart_unit() {
    local unit="$1"
    local init_name

    init_name="${unit%.service}"

    systemctl restart "$unit" >/dev/null 2>&1 \
        || service "$init_name" restart >/dev/null 2>&1 \
        || /etc/init.d/"$init_name" restart >/dev/null 2>&1
}

restart_badvpn() {
    pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true

    for port in 7100 7200 7300; do
        screen -dmS "badvpn-${port}" badvpn-udpgw --listen-addr 127.0.0.1:${port} --max-clients 500
    done
}

show_menu() {
    print_header
    echo -e " [\e[36m•1\e[0m] Restart All Services"
    echo -e " [\e[36m•2\e[0m] Restart OpenSSH"
    echo -e " [\e[36m•3\e[0m] Restart Dropbear"
    echo -e " [\e[36m•4\e[0m] Restart Stunnel4"
    echo -e " [\e[36m•5\e[0m] Restart OpenVPN"
    echo -e " [\e[36m•6\e[0m] Restart Squid"
    echo -e " [\e[36m•7\e[0m] Restart Nginx"
    echo -e " [\e[36m•8\e[0m] Restart Badvpn"
    echo -e " [\e[36m•9\e[0m] Restart XRAY"
    echo -e " [\e[36m10\e[0m] Restart WEBSOCKET"
    echo -e " [\e[36m11\e[0m] Restart Trojan Go"
    echo -e ""
    echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
    echo -e ""
    echo -e "Press x or [ Ctrl+C ] • To-Exit"
    echo -e ""
    echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e ""
}

show_menu
read -p " Select menu : " Restart

echo -e ""

case $Restart in
    1)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit ssh
        restart_unit dropbear
        restart_unit stunnel4
        restart_unit openvpn
        restart_unit fail2ban
        restart_unit cron
        restart_unit nginx
        restart_unit squid
        restart_unit xray.service
        restart_badvpn
        restart_unit sshws.service
        restart_unit ws-dropbear.service
        restart_unit ws-stunnel.service
        restart_unit trojan-go.service
        echo -e "[ \033[32mInfo\033[0m ] ALL Service Restarted"
        pause_back
        ;;
    2)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit ssh
        echo -e "[ \033[32mInfo\033[0m ] SSH Service Restarted"
        pause_back
        ;;
    3)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit dropbear
        echo -e "[ \033[32mInfo\033[0m ] Dropbear Service Restarted"
        pause_back
        ;;
    4)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit stunnel4
        echo -e "[ \033[32mInfo\033[0m ] Stunnel4 Service Restarted"
        pause_back
        ;;
    5)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit openvpn
        echo -e "[ \033[32mInfo\033[0m ] Openvpn Service Restarted"
        pause_back
        ;;
    6)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit squid
        echo -e "[ \033[32mInfo\033[0m ] Squid Service Restarted"
        pause_back
        ;;
    7)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit nginx
        echo -e "[ \033[32mInfo\033[0m ] Nginx Service Restarted"
        pause_back
        ;;
    8)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_badvpn
        echo -e "[ \033[32mInfo\033[0m ] Badvpn Service Restarted"
        pause_back
        ;;
    9)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit xray.service
        echo -e "[ \033[32mInfo\033[0m ] XRAY Service Restarted"
        pause_back
        ;;
    10)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit sshws.service
        restart_unit ws-dropbear.service
        restart_unit ws-stunnel.service
        echo -e "[ \033[32mInfo\033[0m ] WEBSOCKET Service Restarted"
        pause_back
        ;;
    11)
        print_header
        echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
        restart_unit trojan-go.service
        echo -e "[ \033[32mInfo\033[0m ] Trojan Go Service Restarted"
        pause_back
        ;;
    0)
        m-system
        exit
        ;;
    x)
        clear
        exit
        ;;
    *)
        echo -e ""
        echo " EREN YEAGER "
        sleep 1
        restart
        ;;
esac
