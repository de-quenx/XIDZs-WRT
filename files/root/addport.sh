#!/bin/bash

FILE="/etc/board.json"

sed -i '10i\
    },\
    "wan": {\
      "ports": ["eth1", "usb0"],\
      "protocol": "dhcp"\
    ' "$FILE"

rm -- "$0"