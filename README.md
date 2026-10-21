# KEMHarbor

**A fail-closed Mullvad WireGuard gateway with post-quantum key exchange for Linux containers.**

**Status: public source-only alpha (research preview). Not audited or production-ready.**

**Platform:** Linux **x86_64/amd64 only** for this source build. The pinned Mullvad upgrade binary is compiled for amd64; ARM64 support is not implemented or tested. The Fedora base image is pinned by digest, but distribution RPM dependencies are resolved at build time and are not yet reproducibly locked. Build results can change when package repositories change.

This repository contains the standalone KEMHarbor gateway source and usage documentation. The distributed source tree does not include test harnesses, experimental lifecycle supervisors or an automated container-image release workflow.

## Gateway characteristics

- Linux kernel WireGuard and the official Mullvad post-quantum ephemeral-peer upgrade tool (`cme-mlkem`).
- nftables default-DROP traffic policy, with the only uplink exception for marked UDP toward the selected Mullvad relay (`FwMark 0xca6c`).
- Mullvad DNS (`10.64.0.1`); IPv6 is deliberately blocked until fully implemented.
- Readiness only after the post-quantum upgrade tool succeeds, the WireGuard handshake is checked, and the Mullvad exit is verified.
- Read-only container root filesystem, secret file at runtime, temporary VPN configuration on tmpfs.
- No automatic non-PQ fallback or unattended restart. Austria is the only supported exit country in this source snapshot.

**Security limit:** Docker Compose startup health dependencies alone do not stop attached clients when the VPN fails. **Do not run attached applications unattended without separately verified fail-closed lifecycle supervision.** Such a supervisor is not included in this source distribution.

## Manual Docker Compose build (isolated Linux test host only)

This requires Linux with kernel WireGuard and nftables support. Never deploy to a host running unrelated production services without separate validation.

1. Copy `.env.example` to `.env` and enter the Mullvad WireGuard tunnel IPv4, relay IPv4 and relay public key. Keep it out of Git.
2. Put **only** the WireGuard private key into `secrets/mullvad_wg_private_key`, with host ownership `root:root` and permissions `0400` on rootful Docker. Never weaken this to world-readable permissions or add privileged capabilities.
3. Run `docker compose build`, `docker compose up -d`, and `docker compose logs --tail=80 kemharbor`.
4. Confirm explicit post-quantum readiness. Do not attach clients to this standalone example without an independently validated lifecycle supervisor. Stop via `docker compose down` when done.

Never run the gateway in host networking or privileged mode. It uses `NET_ADMIN` in a dedicated container network namespace, not as a blanket permission for attached applications.

For rootless Podman usage, see [Podman instructions](docs/podman.md). For technical limitations and security requirements, see [SECURITY.md](SECURITY.md).

## Container image availability

**No supported prebuilt Docker/Podman image is currently offered.** This public alpha publishes source code only. Build locally on an isolated test host; do not pull historical private images or assume the presence of a `latest` tag. See [distribution status](docs/registry.md).

## Licensing and provenance

KEMHarbor is GPL-3.0-only and **not an official Mullvad product**. Its build verifies the pinned [upstream Mullvad wgephemeralpeer](https://github.com/mullvad/wgephemeralpeer) release using a signing-key fingerprint, SHA-256 and a detached signature.

Never commit private keys, account configuration, personal server backups, credentials, identifying logs or application data to this repository.

---

## Support

If you find this project useful, you can support my open-source work:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=000000)](https://buymeacoffee.com/Olize)
