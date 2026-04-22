#!/bin/bash
# Recover network when WG has stale handshake / dhcpcd restart killed tunnel.
set -e
echo "[net-recover] rebinding wlan0..."
sudo dhcpcd -n wlan0 || true
sleep 2
echo "[net-recover] restarting wg-quick@wg0..."
sudo systemctl restart wg-quick@wg0
sleep 2
echo "[net-recover] testing DNS + reach..."
getent hosts cloudflare.com >/dev/null && echo "  DNS OK" || echo "  DNS FAIL"
ping -c1 -W2 1.1.1.1 >/dev/null && echo "  ICMP OK" || echo "  ICMP FAIL"
echo "[net-recover] done."
