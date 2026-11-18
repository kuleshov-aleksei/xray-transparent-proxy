# Used projects:

## xray-gateway-installer

Huge thanks to https://github.com/El-medo/xray-gateway-installer. It was used as a starting point in making TProxy setup possible.

## XRay-examples

Making xray config is hard. https://github.com/XTLS/Xray-examples is a holy grail of configs

## geoip databases

https://github.com/runetfreedom/russia-v2ray-rules-dat

# Installation

1. Install xray (not v2ray!) from Xray-install or AUR (`xray-bin`)
    - Xray-install:  
    `bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata`
2. Download geoip db using scripts `01_download_geoip.sh` + `02_copy_geoip.sh`
3. Prepare special service user using `10_create_user.sh`
4. Install service using `11_install_service.sh <path to config>`

Usage:
 - Enable waybar integration
 - Start or Stop xray service manually
 - Execute scripts in tproxy-scripts/

## Traffic handling notes

- Local TCP is captured through the `XRAY_LOCAL` nat chain. Loopback, LAN,
  container (`10/8`, `172.16/12`, `192.168/16`), link-local and multicast
  destinations are never proxied.
- Traffic of local DNS resolvers (`dnsmc`, `doh-client`) and of xray itself is
  never intercepted. Override the list with `PROXY_BYPASS_USERS="user1 user2"`.
  Missing users are skipped silently.
- QUIC/HTTP3 is rejected for locally generated traffic (`BLOCK_QUIC=1`,
  `QUIC_PORTS="443"`), because TPROXY can only capture UDP in PREROUTING and
  cannot intercept local sockets. Applications fall back to TCP via xray.
  Set `BLOCK_QUIC=0` to disable.

## Optional

Set system proxy in current terminal using
```
source 99_set_proxy.sh
```

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
