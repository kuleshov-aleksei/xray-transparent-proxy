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

## DNS handover

xray can only own `127.0.0.1:53` while the transparent proxy is on, because the
regular setup uses that port for `dnsmc`/`doh-client`. The scripts hand it over:

- `enable-transparent-proxy.sh` stops the running local resolver (`dnsmc-client`
  or `doh-client`, list in `LOCAL_DNS_UNITS`), records it in
  `/var/lib/xray-transparent-proxy/dns-resolvers`, tests and installs
  `xray-configs/v2ray-extended-dns.json` through `11_install_service.sh`, and
  only then applies the routing/iptables rules. DNS queries are answered by
  xray's built-in DNS (DoH to `1.1.1.1`/`8.8.8.8` through the tunnel) and cached.
- `disable-transparent-proxy.sh` removes the rules, reinstalls
  `xray-configs/v2ray-extended.json`, and starts the resolver recorded in the
  state file again.
- Config installation keeps a backup and automatically rolls back if xray does
  not come up (for example when another process still holds port 53).
- `enable-transparent-proxy.sh` is idempotent. When the ip rule, the capture
  chains, the DNS-enabled config, the requested `BLOCK_QUIC` state and a running
  xray are all in place it prints `already enabled` and exits without touching
  anything. Run `disable-transparent-proxy.sh` first to force a rebuild or to
  change settings.

Both scripts run as root and call `11_install_service.sh` from the repository
root, so relative paths in that installer keep working.

> After a reboot the iptables rules are gone, but the DNS-enabled config stays
> installed while the resolver starts at boot. That can leave xray unable to
> bind port 53. Toggle the proxy off (or run `disable-transparent-proxy.sh`)
> once after such a reboot to restore the regular config.

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
