# Used projects:

## xray-gateway-installer

Huge thanks to https://github.com/El-medo/xray-gateway-installer. It was used as a starting point in making TProxy setup possible.

## XRay-examples

Making xray config is hard. https://github.com/XTLS/Xray-examples is a holy grail of configs

## geoip databases

https://github.com/runetfreedom/russia-v2ray-rules-dat

# Usage

1. Install xray (not v2ray!)
2. Download geoip db using scripts 01_download_geoip.sh + 02_copy_geoip.sh
3. Prepare special service user using 10_create_user.sh
4. Install service (systemctl service override + copy configs + custom sudoers entry)
    - Be aware: sudoers entry allows user to execute toggle config as root without password! Nothing prevents this user to change content of this script and execute whatever he wants to. But I'm ok with this security risk (waybar should be able to execute this script)
5. Enable waybar integration / Start or Stop xray service manually / Execute scripts in tproxy-scripts/

# Waybar

TODO: add links to proper usage

Example module:

```json
"custom/vpn-toggle": {
    "exec": "~/vpn/tproxy-scripts/transparent-proxy-status.sh",
    "interval": 5,
    "format": "{}",
    "on-click": "~/vpn/tproxy-scripts/toggle-transparent-proxy.sh",
    "tooltip-format": "Toggle XRAY + TProxy",
    "signal": 7
},
```
