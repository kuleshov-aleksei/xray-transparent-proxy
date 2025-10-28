#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

#cp xray-configs/v2ray-extended.json /usr/local/etc/xray/v2ray-extended.json
cp xray-configs/v2ray-de.encamy.com.json /usr/local/etc/xray/v2ray-extended.json
cp service-configs/90-custom-override-xray.conf /etc/systemd/system/xray.service.d/
systemctl daemon-reload
systemctl restart xray.service

cp service-configs/10_sudoers_toggle /etc/sudoers.d/10_tproxy_toggle
