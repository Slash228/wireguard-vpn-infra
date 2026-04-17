#!/usr/bin/env bash
set -euo pipefail

OUT="/home/lisoon/dnp/wireguard-vpn-infra/docker/textfile_collector/wireguard.prom"
TMP="$(mktemp)"

echo '# HELP wireguard_sent_bytes_total Bytes sent to the peer' > "$TMP"
echo '# TYPE wireguard_sent_bytes_total counter' >> "$TMP"
echo '# HELP wireguard_received_bytes_total Bytes received from the peer' >> "$TMP"
echo '# TYPE wireguard_received_bytes_total counter' >> "$TMP"
echo '# HELP wireguard_latest_handshake_seconds UNIX timestamp seconds of the last handshake' >> "$TMP"
echo '# TYPE wireguard_latest_handshake_seconds gauge' >> "$TMP"
echo '# HELP wireguard_latest_handshake_delay_seconds Seconds from the last handshake' >> "$TMP"
echo '# TYPE wireguard_latest_handshake_delay_seconds gauge' >> "$TMP"

NOW="$(date +%s)"

wg show wg0 dump | tail -n +2 | while IFS=$'\t' read -r public_key preshared_key endpoint allowed_ips latest_handshake rx_bytes tx_bytes persistent_keepalive; do
  if [ -z "${public_key:-}" ]; then
    continue
  fi

  if [ "$latest_handshake" = "0" ]; then
    delay="-1"
  else
    delay=$((NOW - latest_handshake))
  fi

  echo "wireguard_received_bytes_total{peer=\"$public_key\",endpoint=\"$endpoint\",allowed_ips=\"$allowed_ips\"} $rx_bytes" >> "$TMP"
  echo "wireguard_sent_bytes_total{peer=\"$public_key\",endpoint=\"$endpoint\",allowed_ips=\"$allowed_ips\"} $tx_bytes" >> "$TMP"
  echo "wireguard_latest_handshake_seconds{peer=\"$public_key\",endpoint=\"$endpoint\",allowed_ips=\"$allowed_ips\"} $latest_handshake" >> "$TMP"
  echo "wireguard_latest_handshake_delay_seconds{peer=\"$public_key\",endpoint=\"$endpoint\",allowed_ips=\"$allowed_ips\"} $delay" >> "$TMP"
done

mv "$TMP" "$OUT"
