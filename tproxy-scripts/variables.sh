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
XRAY_LOCAL_CHAIN="XRAY_LOCAL"     # nat: local (OUTPUT) TCP capture
XRAY_QUIC_CHAIN="XRAY_QUIC"       # filter: UID bypass + QUIC/HTTP3 block

# Repository layout (this file is sourced from tproxy-scripts/)
REPO_ROOT="$(cd "$base_dir/.." && pwd)"
XRAY_CONFIG_PLAIN="$REPO_ROOT/xray-configs/v2ray-extended.json"
XRAY_CONFIG_DNS="$REPO_ROOT/xray-configs/v2ray-extended-dns.json"
INSTALL_SERVICE_SCRIPT="$REPO_ROOT/11_install_service.sh"
XRAY_INSTALLED_CONFIG="/usr/local/etc/xray/v2ray-extended.json"

# Local DNS resolvers that must yield port 53 while the proxy is enabled.
# They are stopped on enable, recorded in DNS_STATE_FILE and started again on
# disable.
LOCAL_DNS_UNITS=${LOCAL_DNS_UNITS-"dnsmc-client doh-client"}
DNS_STATE_DIR="/var/lib/xray-transparent-proxy"
DNS_STATE_FILE="$DNS_STATE_DIR/dns-resolvers"

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

# Users whose traffic must never be intercepted (local DNS resolvers etc.).
# Missing users are skipped silently: dnsmc and doh-client are both optional.
PROXY_BYPASS_USERS=${PROXY_BYPASS_USERS-"dnsmc doh-client"}
PROXY_BYPASS_UIDS=()
for user in $PROXY_BYPASS_USERS; do
    if uid=$(id -u "$user" 2>/dev/null); then
        PROXY_BYPASS_UIDS+=("$uid")
    fi
done

# QUIC/HTTP3 cannot be transparently proxied for local sockets (TPROXY only
# works in PREROUTING), so reject it and let apps fall back to TCP via xray.
BLOCK_QUIC=${BLOCK_QUIC:-1}
QUIC_PORTS=${QUIC_PORTS:-"443"}

echo "[INFO] Loaded exclusions:"
echo "  ├─ CIDRs: ${#CUSTOM_BYPASS_CIDRS[@]}"
echo "  ├─ IPs:   ${#CUSTOM_BYPASS_IPS[@]}"
echo "  ├─ Ports: ${#CUSTOM_BYPASS_PORTS[@]}"
echo "  ├─ Users: ${PROXY_BYPASS_USERS} (found UIDs: ${PROXY_BYPASS_UIDS[*]:-none})"
echo "  ├─ QUIC block: ${BLOCK_QUIC} (ports: ${QUIC_PORTS})"
echo "  └─ Local DNS units: ${LOCAL_DNS_UNITS}"

echo "[INFO] Done"
