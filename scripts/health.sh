#!/usr/bin/bash
# KEMHarbor tunnel health policy. No private-key material is logged.
# Local WireGuard/PQ failure: hard stop (1).
# Remote Mullvad exit failure: hard stop (1), or transient upstream error (75).
KEMHARBOR_HANDSHAKE_MAX_AGE_SECONDS=180

kemharbor_pq_and_handshake_ok() {
  local wg_info handshakes timestamp now age
  wg_info="$(wg show wg0 2>/dev/null)" || return 1
  grep -F 'preshared key: (hidden)' >/dev/null <<<"$wg_info" || return 1

  handshakes="$(wg show wg0 latest-handshakes 2>/dev/null)" || return 1
  [[ "$(printf '%s\n' "$handshakes" | wc -l)" -eq 1 ]] || return 1
  timestamp="$(awk 'NF==2 {print $2}' <<<"$handshakes")"
  [[ "$timestamp" =~ ^[0-9]{1,12}$ ]] || return 1
  now="$(date +%s)"
  [[ "$now" =~ ^[0-9]{1,12}$ ]] || return 1
  age=$(( 10#$now - 10#$timestamp ))
  (( age >= -5 && age <= KEMHARBOR_HANDSHAKE_MAX_AGE_SECONDS ))
}

kemharbor_local_check() {
  if ! kemharbor_pq_and_handshake_ok; then
    echo "ERROR: PQ peer missing or WireGuard handshake too old; refusing service." >&2
    return 1
  fi
}

kemharbor_exit_check() {
  local body
  if ! body="$(curl -fsS --connect-timeout 6 --max-time 15 --retry 0 https://am.i.mullvad.net/json)"; then
    echo "WARNING: Mullvad exit verification temporarily unreachable." >&2
    return 75
  fi
  if ! jq -e 'type=="object" and (.mullvad_exit_ip | type=="boolean") and (.country | type=="string")' >/dev/null <<<"$body"; then
    echo "WARNING: Invalid Mullvad exit verification response." >&2
    return 75
  fi
  if ! jq -e '.mullvad_exit_ip == true and ((.country | ascii_downcase) == "austria")' >/dev/null <<<"$body"; then
    echo "ERROR: Exit is not a verified Austrian Mullvad VPN server." >&2
    return 1
  fi
  return 0
}

# Startup still requires BOTH conditions in the same verification pass.
kemharbor_health_check() {
  kemharbor_local_check || return 1
  kemharbor_exit_check
}

kemharbor_validate_health_settings() {
  # Legacy HEALTH_INTERVAL controls the inexpensive local check, not the
  # remote HTTPS rate. Defaults: local 5 s, exit 90 s, transient retry 30 s.
  if ! [[ -v KEMHARBOR_HEALTH_INTERVAL_SECONDS ]]; then KEMHARBOR_HEALTH_INTERVAL_SECONDS=5; fi
  if ! [[ -v KEMHARBOR_HEALTH_MAX_TRANSIENTS ]]; then KEMHARBOR_HEALTH_MAX_TRANSIENTS=3; fi
  if ! [[ -v KEMHARBOR_EXIT_INTERVAL_SECONDS ]]; then KEMHARBOR_EXIT_INTERVAL_SECONDS=90; fi
  if ! [[ -v KEMHARBOR_EXIT_RETRY_SECONDS ]]; then KEMHARBOR_EXIT_RETRY_SECONDS=30; fi
  [[ "$KEMHARBOR_HEALTH_INTERVAL_SECONDS" =~ ^([1-9]|[1-5][0-9]|60)$ ]] || {
    echo "ERROR: KEMHARBOR_HEALTH_INTERVAL_SECONDS must be 1..60." >&2; return 1;
  }
  [[ "$KEMHARBOR_HEALTH_MAX_TRANSIENTS" =~ ^[1-3]$ ]] || {
    echo "ERROR: KEMHARBOR_HEALTH_MAX_TRANSIENTS must be 1..3." >&2; return 1;
  }
  [[ "$KEMHARBOR_EXIT_INTERVAL_SECONDS" =~ ^([1-9]|[1-9][0-9]|[12][0-9][0-9]|300)$ ]] || {
    echo "ERROR: KEMHARBOR_EXIT_INTERVAL_SECONDS must be 1..300." >&2; return 1;
  }
  [[ "$KEMHARBOR_EXIT_RETRY_SECONDS" =~ ^([1-9]|[1-5][0-9]|60)$ ]] || {
    echo "ERROR: KEMHARBOR_EXIT_RETRY_SECONDS must be 1..60." >&2; return 1;
  }
}
