#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 1 && "$1" == wg0 ]] || { echo "ERROR: Invalid WireGuard interface for PQ PostUp." >&2; exit 1; }
: "$VPN_ENDPOINT_IP"
# Avoid the wg-quick fwmark policy-routing sysctl in restricted rootless Podman.
# Changes are limited to the isolated container network namespace.
COUNT="$(ip -4 -o route show default | wc -l)"
[[ "$COUNT" == 1 ]] || { echo "ERROR: Expected exactly one initial namespace default route." >&2; exit 1; }
UPLINK="$(ip -4 route show default | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1);exit}}')"
GATEWAY="$(ip -4 route show default | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="via") {print $(i+1);exit}}')"
[[ "$UPLINK" =~ ^[A-Za-z0-9_.-]{1,15}$ && "$UPLINK" != wg0 ]] || { echo "ERROR: Unsafe uplink interface." >&2; exit 1; }
[[ "$GATEWAY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: Missing IPv4 gateway for Mullvad endpoint exception." >&2; exit 1; }
ip -4 route add "$VPN_ENDPOINT_IP/32" via "$GATEWAY" dev "$UPLINK"
ip -4 route del default
ip -4 route add default dev wg0
[[ "$(ip -4 -o route show default | wc -l)" == 1 ]] || { echo "ERROR: Unexpected default route count." >&2; exit 1; }
ip -4 route get 1.1.1.1 | grep -Fq ' dev wg0 ' || { echo "ERROR: Ordinary traffic not routed via WireGuard." >&2; exit 1; }
ip -4 route get "$VPN_ENDPOINT_IP" | grep -Fq " dev $UPLINK " || { echo "ERROR: Endpoint exception route missing." >&2; exit 1; }
echo "VPN routing established without modifying namespace sysctls."
timeout 90 mullvad-upgrade-tunnel -kem cme-mlkem -wg-interface wg0
