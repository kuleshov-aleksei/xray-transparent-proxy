#!/usr/bin/bash

if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

base_dir="$(dirname "$0")"

# Note: all source scripts should be silenced here because waybar will use 1st message

if [ -z "${MARK_ID}" ]; then
    source $base_dir/variables.sh > /dev/null
fi

# The enable/disable scripts set `set -e` and an ERR trap for themselves. Run
# them in a subshell so that (a) those settings do not leak into this script and
# (b) a failing `pkill` below is not reported as a fatal script error.
RULE_ACTIVE=$(ip rule list | grep -E "fwmark 0x$MARK_ID lookup $ROUTE_TABLE_ID")

if [ -z "$RULE_ACTIVE" ]; then
    # TProxy is inactive, enable
    echo "Inactive, enabling"
    if ! ( source $base_dir/enable-transparent-proxy.sh ); then
        echo "❌ TProxy enable failed"
        pkill -RTMIN+9 waybar 2>/dev/null || true
        exit 1
    fi
    echo "🔒 TProxy ON"
else
    # TProxy is active, disable
    echo "Active, disabling"
    if ! ( source $base_dir/disable-transparent-proxy.sh ); then
        echo "❌ TProxy disable failed"
        pkill -RTMIN+9 waybar 2>/dev/null || true
        exit 1
    fi
    echo "⚠️ TProxy OFF"
fi

pkill -RTMIN+9 waybar 2>/dev/null || true
