#!/usr/bin/bash
# Strict startup validation. Sourced before any nftables or WireGuard change.
kemharbor_valid_ipv4() {
  local a b c d octet
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r a b c d <<< "$1"
  for octet in "$a" "$b" "$c" "$d"; do
    [[ "$octet" =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}
kemharbor_validate_config() {
  local ipv4 prefix
  [[ -n "$VPN_ENDPOINT_IP" && -n "$VPN_ENDPOINT_PORT" &&
     -n "$VPN_PEER_PUBLIC_KEY" && -n "$WG_ADDRESS" ]] || {
    echo "ERROR: Required VPN settings are empty." >&2
    return 1
  }
  if ! kemharbor_valid_ipv4 "$VPN_ENDPOINT_IP" ||
     [[ "$VPN_ENDPOINT_IP" == 0.0.0.0 || "$VPN_ENDPOINT_IP" == 255.255.255.255 ]]; then
    echo "ERROR: Invalid relay IPv4 address (leading zeros forbidden)." >&2
    return 1
  fi
  if ! [[ "$VPN_ENDPOINT_PORT" =~ ^[1-9][0-9]{0,4}$ ]] ||
     ! (( 10#$VPN_ENDPOINT_PORT <= 65535 )); then
    echo "ERROR: Invalid relay UDP port (1..65535, no leading zeros)." >&2
    return 1
  fi
  [[ "$VPN_PEER_PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]] || {
    echo "ERROR: Invalid WireGuard relay public key format." >&2
    return 1
  }
  [[ "$WG_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/32$ ]] || {
    echo "ERROR: Invalid client IPv4 address or CIDR." >&2
    return 1
  }
  IFS=/ read -r ipv4 prefix <<< "$WG_ADDRESS"
  if ! kemharbor_valid_ipv4 "$ipv4" ||
     [[ "$ipv4" == 0.0.0.0 || "$ipv4" == 255.255.255.255 ]]; then
    echo "ERROR: Invalid client IPv4 octets (leading zeros forbidden)." >&2
    return 1
  fi
}
