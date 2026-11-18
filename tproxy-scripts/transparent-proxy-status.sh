#!/usr/bin/bash

base_dir="$(dirname "$0")"

if [ -z "${MARK_ID}" ]; then
    source $base_dir/variables.sh > /dev/null
fi

# ip rule is readable without privileges; iptables is not, so the check is
# limited to the ip rule plus a live xray service (which serves :53 and the
# inbound ports).
RULE_ACTIVE=$(ip rule list | grep -E "fwmark 0x$MARK_ID lookup $ROUTE_TABLE_ID")

if [ -n "$RULE_ACTIVE" ] && systemctl is-active --quiet xray; then
    echo "🔒 TProxy ON"
else
    echo "⚠️ TProxy OFF"
fi
