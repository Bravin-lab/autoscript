#!/bin/bash
MYIP=$(wget -qO- ipv4.icanhazip.com);
echo "Checking VPS"

pause_menu() {
    echo ""
    read -n 1 -s -r -p "Press any key to back on menu"
    m-udp
}

service_action() {
    local action="$1"

    if systemctl "$action" udp-custom.service >/dev/null 2>&1; then
        echo "udp-custom.service ${action} OK"
    else
        echo "Failed to ${action} udp-custom.service"
    fi

    pause_menu
}

show_udp_config() {
    if [ -f /root/udp/config.json ]; then
        cat /root/udp/config.json
    else
        echo "UDP Custom config not found. Install UDP Custom first."
    fi

    pause_menu
}

clear
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "\E[0;100;33m          NT UDP MENU          \E[0m"
echo -e "\e[33m-----------------------------------\033[0m"
echo -e ""
echo -e " [\e[36m1\e[0m] Create UDP Account"
echo -e " [\e[36m2\e[0m] Trial UDP Account"
echo -e " [\e[36m3\e[0m] Renew UDP Account"
echo -e " [\e[36m4\e[0m] Delete UDP Account"
echo -e " [\e[36m5\e[0m] Check UDP Custom Status"
echo -e " [\e[36m6\e[0m] Restart UDP Custom"
echo -e " [\e[36m7\e[0m] Start UDP Custom"
echo -e " [\e[36m8\e[0m] Stop UDP Custom"
echo -e " [\e[36m9\e[0m] Show UDP Config"
echo -e " [\e[36m10\e[0m] Install/Update UDP Custom"
echo -e ""
echo -e " [\e[31m0\e[0m] \e[31mBACK TO NT MENU\033[0m"
echo -e ""
echo -e "Press x or [ Ctrl+C ] - To-Exit"
echo ""
echo -e "\e[33m-----------------------------------\033[0m"
echo -e ""
read -p " Select menu :  " opt
echo -e ""

case $opt in
1) clear ; usernew ; exit ;;
2) clear ; trial ; exit ;;
3) clear ; renew ; exit ;;
4) clear ; hapus ; exit ;;
5) clear ; systemctl status udp-custom.service --no-pager ; pause_menu ;;
6) clear ; service_action restart ;;
7) clear ; service_action start ;;
8) clear ; service_action stop ;;
9) clear ; show_udp_config ;;
10) clear ; ins-udp ; exit ;;
0) clear ; menu ; exit ;;
x) exit ;;
*) echo "Invalid selection" ; sleep 1 ; m-udp ;;
esac
