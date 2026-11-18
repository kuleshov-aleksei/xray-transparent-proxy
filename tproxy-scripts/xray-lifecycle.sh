#!/bin/bash
# Lifecycle helpers shared by enable/disable-transparent-proxy.sh
#
# The transparent proxy needs port 127.0.0.1:53 for xray's built-in DNS, while
# the regular setup needs it for dnsmc/doh-client. This file owns the handover
# in both directions, plus safe installation of the xray config.
#
# This file is meant to be sourced, not executed.

# Prints the process currently bound to local port 53 (empty when none/free).
dns_port_holder() {
    ss -lnuHp 'sport = :53' 2>/dev/null \
        | grep -o 'users:(("[^"]*"' \
        | head -n1 \
        | sed 's/^users:(("//; s/"$//'
}

# Stops the local DNS resolvers and remembers which ones were running.
# On a repeated enable the previous state file is kept (the resolver is already
# stopped and must still be restored later).
dns_resolvers_stop() {
    local active=() unit holder i

    mapfile -t active < <(
        for unit in $LOCAL_DNS_UNITS; do
            systemctl is-active --quiet "$unit" 2>/dev/null && echo "$unit"
        done
    )

    if (( ${#active[@]} > 0 )); then
        mkdir -p "$DNS_STATE_DIR"
        printf '%s\n' "${active[*]}" > "${DNS_STATE_FILE}.tmp"
        mv "${DNS_STATE_FILE}.tmp" "$DNS_STATE_FILE"
        echo "[INFO] Stopping local DNS resolver(s): ${active[*]}"
        for unit in "${active[@]}"; do
            systemctl stop "$unit" || echo "[WARN] Failed to stop $unit"
        done
    elif [[ -f "$DNS_STATE_FILE" ]]; then
        echo "[INFO] Local DNS already stopped by a previous run ($(cat "$DNS_STATE_FILE"))"
    else
        echo "[WARN] No local DNS resolver is running (${LOCAL_DNS_UNITS})"
    fi

    # Wait for the stopped processes to release port 53. xray holding it is
    # expected on re-enable and is not a problem.
    for i in {1..20}; do
        holder=$(dns_port_holder)
        if [[ -z "$holder" || "$holder" == "xray" ]]; then
            return 0
        fi
        sleep 0.1
    done

    echo "[WARN] Port 53 is still held by '$holder'"
    return 1
}

# Starts the resolvers recorded by dns_resolvers_stop.
# A short retry covers the moment when xray has just released the port.
dns_resolvers_start() {
    if [[ ! -f "$DNS_STATE_FILE" ]]; then
        echo "[INFO] No local DNS resolver was stopped by tproxy"
        return 0
    fi

    local units unit failed=0
    units=$(cat "$DNS_STATE_FILE")

    for unit in $units; do
        echo "[INFO] Starting $unit..."
        if systemctl start "$unit" 2>/dev/null && systemctl is-active --quiet "$unit"; then
            echo "[OK] $unit is running"
        elif sleep 1 && systemctl start "$unit" 2>/dev/null && systemctl is-active --quiet "$unit"; then
            echo "[OK] $unit is running (after retry)"
        else
            echo "[ERROR] Could not start $unit"
            failed=1
        fi
    done

    (( failed == 0 )) && rm -f "$DNS_STATE_FILE"
    return $failed
}

# Restores the previous xray config after a failed installation.
xray_rollback_config() {
    local backup="${XRAY_INSTALLED_CONFIG}.tproxy-backup"

    if [[ ! -f "$backup" ]]; then
        echo "[WARN] No xray config backup available for rollback"
        return 1
    fi

    echo "[WARN] Restoring previous xray config..."
    cp -a "$backup" "$XRAY_INSTALLED_CONFIG"
    systemctl restart xray 2>/dev/null || true

    if systemctl is-active --quiet xray; then
        echo "[OK] Previous xray config restored"
    else
        echo "[ERROR] xray failed even after rollback, check: journalctl -u xray -n 50"
    fi
}

# Validates and installs an xray config through 11_install_service.sh.
# Keeps a backup of the installed config and rolls back if xray does not come up.
xray_install_config() {
    local config="$1"

    if [[ ! -f "$config" ]]; then
        echo "[ERROR] Xray config not found: $config"
        return 1
    fi

    if [[ ! -x "$INSTALL_SERVICE_SCRIPT" ]]; then
        echo "[ERROR] Installer missing or not executable: $INSTALL_SERVICE_SCRIPT"
        return 1
    fi

    echo "[INFO] Testing $(basename "$config")..."
    if ! xray run -test -c "$config" >/dev/null 2>&1; then
        echo "[ERROR] Xray rejected $(basename "$config"):"
        xray run -test -c "$config" 2>&1 | tail -n 5
        return 1
    fi

    [[ -f "$XRAY_INSTALLED_CONFIG" ]] && \
        cp -a "$XRAY_INSTALLED_CONFIG" "${XRAY_INSTALLED_CONFIG}.tproxy-backup"

    echo "[INFO] Installing $(basename "$config")..."
    if ! ( cd "$REPO_ROOT" && "$INSTALL_SERVICE_SCRIPT" "$config" ); then
        echo "[ERROR] Installer failed for $(basename "$config")"
        xray_rollback_config
        return 1
    fi

    if ! systemctl is-active --quiet xray; then
        echo "[ERROR] xray is not running with $(basename "$config")"
        xray_rollback_config
        return 1
    fi

    echo "[OK] xray is running with $(basename "$config")"
    return 0
}
