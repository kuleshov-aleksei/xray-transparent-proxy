#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Creating user xray with group root"

# Create a custom user for running xray. This user will be used during routing
id -u xray &>/dev/null || useradd xray -M -G root
# cap_net_admin is required to use SO_MARK
echo "Setting user capabilities"
sudo setcap 'cap_net_bind_service,cap_net_admin=+ep' $(which xray)
