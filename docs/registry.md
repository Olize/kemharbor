# Distribution status

**Public source-only alpha. There is no supported public prebuilt KEMHarbor container image.**

Build from this source on a dedicated disposable Linux host. Do not use a mutable `latest` image tag, assume that a similarly named image was produced from this source, or attach unattended production clients.

Previously built private experimental images are **obsolete** and predate security hardening such as the WireGuard socket-mark restriction (`FwMark = 0xca6c`). No historical image should be used for security-sensitive workloads. Those artifacts are not releases of this public source snapshot.

A future image release should be built from an explicitly reviewed source commit, tested with a real authenticated Mullvad post-quantum tunnel and forced failure/leak scenarios, published by immutable digest, accompanied by an SBOM, and signed with a verifiable build identity.

For current safety and deployment limits, see [SECURITY.md](../SECURITY.md). This source is GPL-3.0-only and is not affiliated with Mullvad.
