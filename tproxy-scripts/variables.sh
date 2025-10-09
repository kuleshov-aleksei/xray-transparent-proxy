#!/bin/bash

echo "[INFO] Loading variables"

base_dir="$(dirname "$0")"

TPROXY_UID=$(id -u xray)
MARK_ID=1
ROUTE_TABLE_ID=233

XRAY_TPROXY_PORT=12345
XRAY_REDIRECT_PORT=12346

XRAY_CHAIN="XRAY"
XRAY_SELF_CHAIN="XRAY_SELF"

LAN_IF=$(ip route | awk '/default/ {print $5}' | head -n1)
LOCAL_CIDRS=$(ip -o -f inet addr show "$LAN_IF" | awk '{print $4}')

echo "[INFO] Default interface: $LAN_IF: CIDR: $LOCAL_CIDRS"

[[ -f "$base_dir/xray-exclude-iptables.cidrs" ]] && \
    mapfile -t cidrs_from_file < <(grep -vE '^\s*#|^\s*$' "$base_dir/xray-exclude-iptables.cidrs")

[[ -f "$base_dir/xray-exclude-iptables.ips" ]] && \
    mapfile -t ips_from_file < <(grep -vE '^\s*#|^\s*$' "$base_dir/xray-exclude-iptables.ips")

[[ -f "$base_dir/xray-exclude-iptables.ports" ]] && \
    mapfile -t ports_from_file < <(grep -vE '^\s*#|^\s*$' "$base_dir/xray-exclude-iptables.ports")

CUSTOM_BYPASS_CIDRS=($(printf "%s\n" "${cidrs_from_env[@]}" "${cidrs_from_file[@]}" | sort -u))
CUSTOM_BYPASS_IPS=($(printf "%s\n" "${ips_from_env[@]}" "${ips_from_file[@]}" | sort -u))
CUSTOM_BYPASS_PORTS=($(printf "%s\n" "${ports_from_env[@]}" "${ports_from_file[@]}" | sort -u))

echo "[INFO] Loaded exclusions:"
echo "  ├─ CIDRs: ${#CUSTOM_BYPASS_CIDRS[@]}"
echo "  ├─ IPs:   ${#CUSTOM_BYPASS_IPS[@]}"
echo "  └─ Ports: ${#CUSTOM_BYPASS_PORTS[@]}"

echo "[INFO] Done"
