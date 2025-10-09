#!/usr/bin/bash

base_dir="$(dirname "$0")"

if [ -z "${MARK_ID}" ]; then
    source $base_dir/variables.sh > /dev/null
fi

# Check if TProxy is currently active
RULE_ACTIVE=$(ip rule list | grep -E "$MARK_ID|table $ROUTE_TABLE_ID")
if [ -z "$RULE_ACTIVE" ]; then
    echo "⚠️ TProxy OFF"
else
    echo "🔒 TProxy ON"
fi
