#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ -z "$1" ]; then
   echo "Error: xray config argument is empty. Usage $0 xray-configs/my-config.json"
   exit 1
fi

if [[ ! -f "$1" ]]; then
   echo "Xray config does not exist"
   exit 1
fi

cp $1 /usr/local/etc/xray/v2ray-extended.json
mkdir -p /etc/systemd/system/xray.service.d/
cp service-configs/90-custom-override-xray.conf /etc/systemd/system/xray.service.d/
systemctl daemon-reload
systemctl restart xray.service

cp service-configs/10_sudoers_toggle /etc/sudoers.d/10_tproxy_toggle
