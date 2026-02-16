#!/bin/bash

# https://github.com/runetfreedom/russia-v2ray-rules-dat
mkdir -p data
wget -O data/geoip.dat https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat
wget -O data/geosite.dat https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat
