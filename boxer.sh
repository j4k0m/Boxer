#!/bin/bash

if [ ! -f /usr/bin/nmap ]; then
    echo -e "\e[1;31m[-]\e[0m Nmap is not installed. Installing nmap."
    sudo apt-get -y install nmap
    clear
fi

if [ ! -f /usr/bin/dirb ]; then
    echo -e "\e[1;31m[-]\e[0m Dirb is not installed. Installing dirb."
    sudo apt-get -y install dirb
    clear
fi

[ ! -d "./reports" ] && mkdir ./reports

if [ $# -eq 0 ]; then
    echo "Usage: ./boxer.sh <target>"
    exit 1
fi

([ -d "./reports/$1" ] && echo -e "\e[1;31m[-]\e[0m Folder target already exists, creating new one..." && rm -r ./reports/$1 && mkdir ./reports/$1) || mkdir ./reports/$1

ping -c 1 $1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\e[1;31m[-]\e[0m I can't reach the host: $1! please check you vpn connection."
    exit 1
fi

echo -e "\e[1;32m[+]\e[0m Running nmap scan... (nmap -sC -sV $1 -o ./reports/$1/nmap.txt)"
nmap -sC -sV $1 -o ./reports/$1/nmap.txt &> /dev/null

echo -e "\e[1;32m[+]\e[0m Getting open ports..."

if [ $(cat ./reports/$1/nmap.txt | grep open | wc -l) -gt 0 ]; then
    cat ./reports/$1/nmap.txt | grep open
else
    echo -e "\e[1;31m[-]\e[0m No open ports found."
    rm -r ./reports/$1
    exit 1
fi

if [ $(cat ./reports/$1/nmap.txt | grep ftp -m 1 | wc -l) -gt 0 ]; then
    echo -e "\e[1;32m[+]\e[0m FTP service found."

    FTP_PORT=$(cat ./reports/$1/nmap.txt | grep ftp -m 1 | cut -d "/" -f 1)
    echo -e "\e[1;32m[+]\e[0m FTP port: $FTP_PORT"

    echo -e "\e[1;32m[+]\e[0m Checking if FTP anon login is enabled..."
    
    ftp -n $1 << EOF &>/dev/null
    quoete USER anonymous
    quote PASS anonymous
    quit
EOF
    if [ $?=="Login incorrect." ]; then
        echo -e "\e[1;31m[-]\e[0m FTP anonymous login is not enabled."
    else
        echo -e "\e[1;32m[+]\e[0m FTP anonymous login is enabled."
    fi
fi

echo -e "\e[1;32m[+]\e[0m Checking if there is any web server running on the target..."

if [ $(cat ./reports/$1/nmap.txt | grep http | wc -l) -gt 0 ]; then
    for i in $(cat ./reports/$1/nmap.txt | grep open | grep http | cut -d "/" -f 1); do
        echo -e "\e[1;32m[+]\e[0m HTTP port: $i"
        echo -e "\e[1;32m[+]\e[0m Running dirb..."
        dirb http://$1:$i -o ./reports/$1/dirb-$i.txt &> /dev/null
        echo -e "\e[1;32m[+]\e[0m Getting paths from dirb output..."
        if [ $(cat ./reports/$1/dirb-$i.txt | grep "+ http://" | wc -l) -gt 0 ]; then
            echo -e "\e[1;32m[+]\e[0m Paths found for http://$1:$i/ :"
            cat ./reports/$1/dirb-$i.txt | grep "+ http://" | awk '{print $1 " " $2}'
        else
            echo -e "\e[1;31m[-]\e[0m No paths found from dirb output."
        fi
    done
else
    echo -e "\e[1;31m[-]\e[0m No HTTP service found."
    exit 1
fi
