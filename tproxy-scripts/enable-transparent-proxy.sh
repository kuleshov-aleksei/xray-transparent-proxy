#!/bin/bash

# https://github.com/El-medo/xray-gateway-installer/blob/main/template/xray-iptables.template.sh
base_dir="$(dirname "$0")"
source $base_dir/variables.sh

set -e
trap 'echo "[FATAL] Failed at $LINENO"; exit 1' ERR

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "[INFO] Setting iptables rules for enabling transparent proxy to xray..."

source $base_dir/disable-transparent-proxy.sh

echo "[INFO] Clearing chain XRAY_DISABLED (if exists)..."
iptables -t mangle -D PREROUTING -j XRAY_DISABLED 2>/dev/null || true
iptables -t mangle -F XRAY_DISABLED 2>/dev/null
iptables -t mangle -X XRAY_DISABLED 2>/dev/null && echo "[OK] XRAY_DISABLED chain deleted"

echo "[INFO] Creating ip rule and routing tables..."
ip rule add fwmark $MARK_ID table $ROUTE_TABLE_ID || {
    echo "[ERROR] Failed to add ip rule"
    exit 1
}

ip route add local 0.0.0.0/0 dev lo table $ROUTE_TABLE_ID || {
    echo "[ERROR] Failed to add route to table $ROUTE_TABLE_ID"
    exit 1
}

echo "[INFO] Creating XRAY chains..."
iptables -t mangle -N $XRAY_CHAIN 2>/dev/null || iptables -t mangle -F $XRAY_CHAIN
iptables -t nat -N $XRAY_CHAIN 2>/dev/null || iptables -t nat -F $XRAY_CHAIN
iptables -t mangle -N $XRAY_SELF_CHAIN 2>/dev/null || iptables -t mangle -F $XRAY_SELF_CHAIN
iptables -t mangle -N XRAY_ENABLED 2>/dev/null || iptables -t mangle -F XRAY_ENABLED

iptables -t mangle -D PREROUTING -j XRAY_ENABLED 2>/dev/null || true
iptables -t mangle -A PREROUTING -j XRAY_ENABLED

iptables -t mangle -C XRAY_ENABLED -j $XRAY_CHAIN 2>/dev/null || \
iptables -t mangle -A XRAY_ENABLED -j $XRAY_CHAIN
echo "[OK] Chain XRAY_ENABLED is forwarding traffic to XRAY"

echo "[INFO] Adding XRAY to PREROUTING and NAT (inside XRAY_ENABLED)..."
iptables -t nat -D PREROUTING -j $XRAY_CHAIN 2>/dev/null || true
iptables -t nat -A PREROUTING -j $XRAY_CHAIN

echo "[INFO] Applying system exclusions..."
for cidr in $LOCAL_CIDRS 127.0.0.0/8; do
    iptables -t mangle -A $XRAY_CHAIN -d "$cidr" -j RETURN
    iptables -t nat -A $XRAY_CHAIN -d "$cidr" -j RETURN
done

iptables -t mangle -A $XRAY_CHAIN -i lo -j RETURN
iptables -t nat -A $XRAY_CHAIN -i lo -j RETURN

echo "[INFO] Applying custom exclusions..."
for cidr in "${CUSTOM_BYPASS_CIDRS[@]}"; do
    iptables -t mangle -A $XRAY_CHAIN -d "$cidr" -j RETURN
    iptables -t nat -A $XRAY_CHAIN -d "$cidr" -j RETURN
done

for ip in "${CUSTOM_BYPASS_IPS[@]}"; do
    iptables -t mangle -A $XRAY_CHAIN -d "$ip" -j RETURN
    iptables -t nat -A $XRAY_CHAIN -d "$ip" -j RETURN
done

for port in "${CUSTOM_BYPASS_PORTS[@]}"; do
    iptables -t mangle -A $XRAY_CHAIN -p tcp --dport "$port" -j RETURN
    iptables -t nat -A $XRAY_CHAIN -p tcp --dport "$port" -j RETURN
done

echo "[INFO] Applying TPROXY (UDP) to port $XRAY_TPROXY_PORT"
[[ -n "$XRAY_TPROXY_PORT" ]] && {
    iptables -t mangle -A $XRAY_CHAIN -p udp -j TPROXY --on-port $XRAY_TPROXY_PORT --tproxy-mark $MARK_ID/0xffffffff
    echo "[OK] TPROXY applied for UDP to port $XRAY_TPROXY_PORT"
}

echo "[INFO] Applying REDIRECT (TCP) rules to port $XRAY_REDIRECT_PORT"
[[ -n "$XRAY_REDIRECT_PORT" ]] && {
    iptables -t nat -A $XRAY_CHAIN -p tcp -j REDIRECT --to-ports $XRAY_REDIRECT_PORT
    iptables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner $TPROXY_UID -j REDIRECT --to-ports $XRAY_REDIRECT_PORT
    echo "[OK] REDIRECT applied for TCP to port $XRAY_REDIRECT_PORT"
}

echo "[INFO] Excluding self-Xray traffic (uid=$TPROXY_UID)..."
iptables -t mangle -D OUTPUT -m owner ! --uid-owner $TPROXY_UID -j $XRAY_SELF_CHAIN 2>/dev/null || true
iptables -t mangle -A OUTPUT -m owner ! --uid-owner $TPROXY_UID -j $XRAY_SELF_CHAIN
iptables -t mangle -A $XRAY_SELF_CHAIN -j RETURN
echo "[OK] Xray traffic excluded"

echo "[INFO] Done"
