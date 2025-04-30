#!/bin/bash
SSID=$(iw dev | grep ssid | awk '{print $2}')
SIGNAL=$(grep $(iw dev | awk '$1=="Interface"{print $2}') /proc/net/wireless | awk '{ print int($3 * 100 / 70) }')

if [[ -z "$SSID" ]]; then
  echo '{"text": "Disconnected", "tooltip": "WiFi not connected", "class": "disconnected"}'
else
  echo "{\"text\": \"$SSID ($SIGNAL%)\", \"tooltip\": \"Connected to $SSID\", \"class\": \"connected\"}"
fi