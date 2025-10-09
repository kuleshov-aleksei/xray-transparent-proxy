#!/bin/bash

# https://github.com/runetfreedom/russia-v2ray-rules-dat
# wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat
# wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat

ENGINE="${ENGINE:-XRAY_CORE}"
case "$ENGINE" in
  V2RAY)
    TARGET_DIR="/usr/share/v2ray"
    ;;
  XRAY_CORE)
    TARGET_DIR="/usr/local/share/xray"
    ;;
  *)
    echo "[ERROR] Unknown ENGINE: $ENGINE"
    exit 1
    ;;
esac

echo "[INFO] Copying geoip.dat and geosite.dat to $TARGET_DIR"

sudo cp data/geoip.dat "$TARGET_DIR/geoip.dat"
sudo cp data/geosite.dat "$TARGET_DIR/geosite.dat"

echo "[INFO] Copy complete"
