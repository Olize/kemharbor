# KEMHarbor security and limitations

**Status: research preview; no formal security audit and no production-ready release.**
This source distribution does not include test harnesses or an automated image-release pipeline. Its documented safety properties are not a substitute for independent security review and live validation.

## Isolation and capabilities

- Run the VPN inside a dedicated Linux network namespace. **Never** use host networking or privileged mode.
- nftables starts with a default-DROP policy. The only uplink exception permits UDP to the selected Mullvad WireGuard relay with packet mark `0xca6c`. The WireGuard transport socket uses `FwMark = 0xca6c`.
- This mark prevents bypass by **unprivileged** attached clients; it is **not** authentication against a client with `NET_ADMIN`, `NET_RAW`, rootful Docker host control or arbitrary socket-mark privileges. **Do not grant these capabilities** to attached applications.
- IPv6 egress is blocked intentionally; it is not tunneled.
- Store the WireGuard private key as a runtime secret at `/run/secrets/mullvad_wg_private_key`, not in the image, repository or logs. For rootful Docker Compose the secret must be root-owned and mode `0400`: with `DAC_OVERRIDE` dropped, an unprivileged-owner `0600` file can fail to mount readably.
- Use the built-in Docker bridge and `dns: 10.64.0.1`; other Compose custom bridges can introduce Docker's `127.0.0.11` DNS proxy. Resolver-file settings **alone do not prove** leak-free packet routing.

## Post-quantum readiness and failure policy

- The pinned Mullvad upgrade executable is checked by SHA-256, detached GPG signature and signing-key fingerprint at build time.
- Successful completion of the ephemeral-peer upgrade, a WireGuard handshake and Mullvad exit verification are mandatory before readiness. A local preshared key is **not independent proof** of authenticated live PQ traffic.
- Local PQ-PSK and handshake freshness checks normally run every **5 seconds**; the last WireGuard handshake must be younger than **180 seconds**.
- External Mullvad exit validation normally runs every **90 seconds**. A verified non-Mullvad or non-Austrian exit is a hard failure. Transient unreachable/malformed external checks are retried after **30 seconds**, up to **three consecutive failures**, then the gateway stops.
- A failed check is not necessarily detected instantly. nftables remains the immediate packet-level fail-closed mechanism. Automatic live ephemeral-peer rotation is **not** enabled or validated.
- Startup input validation rejects ambiguous decimal IPv4 addresses/UDP ports before firewall and interface changes.

## Client lifecycle and unresolved risks

Docker Compose `depends_on: condition: service_healthy` governs startup ordering **only**. It does not stop a running client if the gateway later becomes unhealthy. Attached applications require an **independently tested, fail-closed supervisor**; none is bundled in this source distribution.

Offline isolation, DNS-resolver configuration, synthetic WireGuard/PQ control flow and Docker lifecycle scenarios have been exercised in isolated tests. These are **not** proof of a real authenticated Mullvad-PQ session on Docker, extended DNS/IPv6 leak freedom, post-quantum peer renewal, daemon/host-crash recovery or unattended readiness. Rootless Podman/pasta behavior on each target environment must be independently verified before deployment.

Do not disclose tokens, keys, identifying server logs, credentials or account details. No public container image has been security-approved. Report sensitive vulnerabilities privately to the repository owner (prefer GitHub private vulnerability reporting if enabled).

**Do not deploy this experimental source to a production host without dedicated validation and a rollback plan.**
