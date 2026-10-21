#!/usr/bin/bash
# Strictly isolated research container; production services are not touched.
set -Eeuo pipefail
umask 077

if (($# > 0)); then
  echo "ERROR: Unsupported command." >&2
  exit 64
fi
for cmd in wg wg-quick ip nft timeout curl jq; do
  command -v "$cmd" >/dev/null || { echo "ERROR: Missing required command: $cmd" >&2; exit 1; }
done
source /usr/local/sbin/kemharbor-health
source /usr/local/sbin/kemharbor-validate
kemharbor_validate_health_settings
: "$VPN_ENDPOINT_IP" "$VPN_ENDPOINT_PORT" "$VPN_PEER_PUBLIC_KEY" "$WG_ADDRESS"
kemharbor_validate_config
[[ -s /run/secrets/mullvad_wg_private_key ]] || { echo "ERROR: WireGuard key secret missing." >&2; exit 1; }
[[ -d /run/vpn-conf && -w /run/vpn-conf ]] || { echo "ERROR: Writable private tmpfs mount missing." >&2; exit 1; }
UPLINK="$(ip -4 route show default | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1);exit}}')"
[[ "$UPLINK" =~ ^[A-Za-z0-9_.-]{1,15}$ && "$UPLINK" != wg0 ]] || { echo "ERROR: Default uplink is not safe to use." >&2; exit 1; }
nft -f - <<NFT
flush ruleset
table inet kemharbor_lock {
  chain output {
    type filter hook output priority -300; policy drop;
    oifname "lo" accept
    oifname "wg0" accept
    oifname "$UPLINK" ip daddr $VPN_ENDPOINT_IP udp dport $VPN_ENDPOINT_PORT meta mark 0xca6c accept
  }
  chain input {
    type filter hook input priority -300; policy drop;
    iifname "lo" accept
    ct state invalid drop
    ct state established,related accept
  }
  chain forward { type filter hook forward priority -300; policy drop; }
}
NFT
CONFIG=/run/vpn-conf/wg0.conf
WG_KEY="$(tr -d '\r\n' </run/secrets/mullvad_wg_private_key)"
[[ "$WG_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo "ERROR: Invalid WireGuard private key secret." >&2; exit 1; }
cat > "$CONFIG" <<WGCONF
[Interface]
PrivateKey = $WG_KEY
Address = $WG_ADDRESS
MTU = 1380
Table = off
# Mark only genuine WireGuard transport sockets. Clients without privileges
# cannot forge this exception, even inside the shared network namespace.
FwMark = 0xca6c
PostUp = /usr/local/sbin/kemharbor-postup %i
[Peer]
PublicKey = $VPN_PEER_PUBLIC_KEY
Endpoint = $VPN_ENDPOINT_IP:$VPN_ENDPOINT_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
WGCONF
unset WG_KEY
chmod 0600 "$CONFIG"
cleanup() {
  rm -f /run/vpn-conf/ready
  if wg-quick down "$CONFIG" >/dev/null 2>&1; then
    echo "KEMHarbor: WireGuard cleanup completed."
  else
    echo "WARNING: WireGuard cleanup could not be completed." >&2
  fi
}
trap cleanup EXIT
# Bash as container PID 1 must handle termination itself. EXIT then performs
# wg-quick down without opening any new non-VPN network route.
trap 'exit 143' TERM
trap 'exit 130' INT
sleep_interruptible() {
  # A foreground sleep can delay Bash's trap until the child exits. Waiting
  # on a background child lets TERM/INT interrupt the wait immediately.
  sleep "$1" &
  wait "$!"
}
timeout 110 wg-quick up "$CONFIG"
if ! wg show wg0 | grep -F 'preshared key: (hidden)' >/dev/null; then
  echo "ERROR: PQ preshared key was not applied. Refusing service." >&2
  exit 1
fi
# Only transient reachability/API errors are retried. Missing PQ credentials,
# a stale WireGuard handshake, or an unexpected VPN exit are hard failures.
for n in 1 2 3 4 5; do
  if kemharbor_health_check; then
    break
  else
    status="$?"
    if (( status != 75 || n == 5 )); then
      echo "ERROR: Initial Mullvad/PQ verification failed; refusing service." >&2
      exit 1
    fi
  fi
  sleep_interruptible 3
done
touch /run/vpn-conf/ready
echo "Mullvad PQ tunnel ready; Austria exit verified. VPN clients can now be started separately."

# Local WireGuard/PQ status is cheap and checked frequently. External HTTPS
# exit verification has a separate cadence; temporary remote errors receive
# bounded faster retries, while hard failures always terminate immediately.
transient_failures=0
next_exit_check=$(( $(date +%s) + KEMHARBOR_EXIT_INTERVAL_SECONDS ))
while sleep_interruptible "$KEMHARBOR_HEALTH_INTERVAL_SECONDS"; do
  if ! kemharbor_local_check; then
    echo "ERROR: Local VPN/PQ health gate failed; stopping fail-closed." >&2
    exit 1
  fi
  now="$(date +%s)"
  if (( now < next_exit_check )); then
    continue
  fi
  if kemharbor_exit_check; then
    transient_failures=0
    next_exit_check=$(( now + KEMHARBOR_EXIT_INTERVAL_SECONDS ))
    continue
  else
    status="$?"
    if (( status == 75 )); then
      transient_failures=$(( transient_failures + 1 ))
      if (( transient_failures < KEMHARBOR_HEALTH_MAX_TRANSIENTS )); then
        echo "WARNING: Transient Mullvad verification failure $transient_failures/$KEMHARBOR_HEALTH_MAX_TRANSIENTS; tunnel still restricted." >&2
        next_exit_check=$(( now + KEMHARBOR_EXIT_RETRY_SECONDS ))
        continue
      fi
    fi
    echo "ERROR: Tunnel/PQ health gate failed; stopping fail-closed." >&2
    exit 1
  fi
done
