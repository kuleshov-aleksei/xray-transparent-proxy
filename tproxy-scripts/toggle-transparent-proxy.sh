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

# Check if TProxy is currently active
RULE_ACTIVE=$(ip rule list | grep -E "$MARK_ID|table $ROUTE_TABLE_ID")
if [ -z "$RULE_ACTIVE" ]; then
    # TProxy is inactive, enable
    echo "Inactive, enabling"
    source $base_dir/enable-transparent-proxy.sh
    echo "🔒 TProxy ON"
    pkill -RTMIN+9 waybar
else
    # TProxy is active, disable
    echo "Active, disabling"
    source $base_dir/disable-transparent-proxy.sh
    echo "⚠️ TProxy OFF"
    pkill -RTMIN+9 waybar
fi
