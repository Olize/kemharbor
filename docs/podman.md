# Podman on Linux

This project derives from a tested rootless Podman gateway on Fedora 44. The generalized source build needs its own validation.

Build the image:

    podman build -t kemharbor:local .

Create a local relay.env with WG_ADDRESS, VPN_ENDPOINT_IP, VPN_ENDPOINT_PORT and VPN_PEER_PUBLIC_KEY. Provision your private key as a Podman secret:

    podman secret create mullvad_wg_private_key /path/to/private-key-file

Manually start the gateway:

    podman run -d --name kemharbor --pull=never \
      --network=pasta --dns=10.64.0.1 \
      --cap-drop=all --cap-add=NET_ADMIN \
      --security-opt=no-new-privileges --read-only \
      --pids-limit=128 --memory=768m \
      --tmpfs /run/vpn-conf:rw,nosuid,nodev,noexec,size=16m,mode=0700 \
      --secret mullvad_wg_private_key,type=mount,target=mullvad_wg_private_key \
      --env-file ./relay.env kemharbor:local

Review the logs with podman logs kemharbor. Do not attach another container until the VPN reports readiness; clients also require a supervisor to stop them if the VPN fails.

Stop with podman stop kemharbor and podman rm kemharbor. Never run the gateway using host networking.


## Compatibility limitation

An isolated offline rootless Podman/pasta test verified kernel WireGuard, packet mark `0xca6c`, and nftables with synthetic traffic. This is **not** proof of live authenticated Mullvad-PQ negotiation on Fedora 44 or other hosts. Do not replace an existing working gateway without a separate staged, authenticated test using disposable credentials.
