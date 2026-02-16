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

mkdir -p /usr/local/etc/xray/
cp $1 /usr/local/etc/xray/v2ray-extended.json
mkdir -p /etc/systemd/system/xray.service.d/

export XRAY_PATH=$(whereis xray | cut -d' ' -f 2)
envsubst < service-configs/90-custom-override-xray.conf.template > service-configs/90-custom-override-xray.conf
cp service-configs/90-custom-override-xray.conf /etc/systemd/system/xray.service.d/
systemctl daemon-reload
systemctl restart xray.service
