#!/bin/bash

# https://github.com/El-medo/xray-gateway-installer/blob/main/template/xray-iptables.template.sh
base_dir="$(dirname "$0")"

if [ -z "${MARK_ID}" ]; then
    source $base_dir/variables.sh
fi

set -e
trap 'echo "[FATAL] Failed at $LINENO"; exit 1' ERR

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "[INFO] Reverting XRAY iptables and routing rules..."

if ip rule del fwmark $MARK_ID table $ROUTE_TABLE_ID 2>/dev/null; then
    echo "[OK] ip rule cleared: fwmark=$MARK_ID → table $ROUTE_TABLE_ID"
else
    echo "[WARN] ip rule not found"
fi

if ip route flush table $ROUTE_TABLE_ID 2>/dev/null; then
    echo "[OK] Route table $ROUTE_TABLE_ID cleared"
else
    echo "[WARN] Route table $ROUTE_TABLE_ID does not exists"
fi

echo "[INFO] Clearing XRAY chains from PREROUTING and OUTPUT..."
iptables -t mangle -D PREROUTING -j XRAY_ENABLED 2>/dev/null && echo "[OK] XRAY_ENABLED deleted from PREROUTING" || echo "[WARN] chain XRAY_ENABLED does not exists"
iptables -t mangle -D PREROUTING -j $XRAY_CHAIN 2>/dev/null && echo "[OK] $XRAY_CHAIN deleted from PREROUTING" || echo "[WARN] chain $XRAY_CHAIN does not exists"
iptables -t nat -D PREROUTING -j $XRAY_CHAIN 2>/dev/null && echo "[OK] $XRAY_CHAIN deleted from PREROUTING (nat)" || echo "[WARN] chain $XRAY_CHAIN does not exists (nat)"
iptables -t mangle -D OUTPUT -m owner ! --uid-owner $TPROXY_UID -j $XRAY_SELF_CHAIN 2>/dev/null && echo "[OK] $XRAY_SELF_CHAIN deleted from OUTPUT" || echo "[WARN] $XRAY_SELF_CHAIN does not exists"

echo "[INFO] Clearing chains XRAY, XRAY_SELF and XRAY_ENABLED..."
iptables -t mangle -F $XRAY_CHAIN 2>/dev/null && echo "[OK] Chain $XRAY_CHAIN (mangle) cleared" || echo "[WARN] Chain $XRAY_CHAIN (mangle) does not exists"
iptables -t nat -F $XRAY_CHAIN 2>/dev/null && echo "[OK] Chain $XRAY_CHAIN (nat) cleared" || echo "[WARN] Chain $XRAY_CHAIN (nat) does not exists"
iptables -t mangle -F $XRAY_SELF_CHAIN 2>/dev/null && echo "[OK] Chain $XRAY_SELF_CHAIN cleared" || echo "[WARN] Chain $XRAY_SELF_CHAIN does not exists"
iptables -t mangle -F XRAY_ENABLED 2>/dev/null && echo "[OK] Chain XRAY_ENABLED cleared" || echo "[WARN] Chain XRAY_ENABLED does not exists"

echo "[INFO] Creating or clearing XRAY_DISABLED for DROP by default..."
iptables -t mangle -F XRAY_DISABLED 2>/dev/null || iptables -t mangle -N XRAY_DISABLED
iptables -t mangle -D PREROUTING -j XRAY_DISABLED 2>/dev/null || true
iptables -t mangle -A PREROUTING -j XRAY_DISABLED

echo "[INFO] Clearing custom"
iptables -t nat -D OUTPUT -p tcp -m owner ! --uid-owner $TPROXY_UID -j REDIRECT --to-ports $XRAY_REDIRECT_PORT 2>/dev/null && echo "[OK] Cleared" || echo "[WARN] Nothing to clear"

echo "[INFO] Adding exclusions into XRAY_DISABLED..."

# System CIDRs (e.g., localhost and 10.x.x.x)
for cidr in $LOCAL_CIDRS 127.0.0.0/8; do
    iptables -t mangle -A XRAY_DISABLED -d "$cidr" -j RETURN
done

# IP-address exclusions
for ip in "${CUSTOM_BYPASS_IPS[@]}"; do
    iptables -t mangle -A XRAY_DISABLED -d "$ip" -j RETURN
done

# CIDRs-address exclusions
for cidr in "${CUSTOM_BYPASS_CIDRS[@]}"; do
    iptables -t mangle -A XRAY_DISABLED -d "$cidr" -j RETURN
done

# TCP ports exclusions
for port in "${CUSTOM_BYPASS_PORTS[@]}"; do
    iptables -t mangle -A XRAY_DISABLED -p tcp --dport "$port" -j RETURN
done

# Default - DROP
iptables -t mangle -A XRAY_DISABLED -j DROP
echo "[OK] Chain XRAY_DISABLED added with exclusions and DROP by default"

echo "[INFO] XRAY iptables and routing cleanup complete."
