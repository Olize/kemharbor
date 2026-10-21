# KEMHarbor - experimental Mullvad post-quantum WireGuard gateway
FROM registry.fedoraproject.org/fedora-minimal@sha256:85f06b1bce50801f26dc444ab401270a59aa3e8c96a1f0d56284088e0d5a18c7 AS verify-mullvad
RUN microdnf -y --setopt=install_weak_deps=False install ca-certificates curl gnupg2 unzip coreutils && microdnf clean all
ARG MULLVAD_RELEASE=v1.0.6
RUN set -eu; \
    mkdir -p /tmp/kemharbor/gnupg; chmod 700 /tmp/kemharbor/gnupg; \
    base="mullvad-upgrade-tunnel_$MULLVAD_RELEASE""_linux_amd64.zip"; \
    url="https://github.com/mullvad/wgephemeralpeer/releases/download/$MULLVAD_RELEASE"; \
    curl --fail --location --show-error --silent --retry 2 "$url/$base" -o "/tmp/kemharbor/$base"; \
    curl --fail --location --show-error --silent --retry 2 "$url/$base.asc" -o "/tmp/kemharbor/$base.asc"; \
    curl --fail --location --show-error --silent --retry 2 "https://mullvad.net/static/gpg/mullvad-rsw.asc" -o /tmp/kemharbor/mullvad-rsw.asc; \
    gpg --homedir /tmp/kemharbor/gnupg --batch --import /tmp/kemharbor/mullvad-rsw.asc; \
    fingerprint="$(gpg --homedir /tmp/kemharbor/gnupg --batch --with-colons --fingerprint 'Mullvad RSW' | awk -F: '$1=="fpr"{print $10;exit}')"; \
    test "$fingerprint" = "10241484929EEC4248D6F68035332B90D3936CAE"; \
    unzip -p "/tmp/kemharbor/$base" mullvad-upgrade-tunnel > /tmp/kemharbor/mullvad-upgrade-tunnel; \
    echo "c9be217c189104d62fadd0e90f1d2531d8b1d79043c6fe63009067ce75654220  /tmp/kemharbor/mullvad-upgrade-tunnel" | sha256sum -c -; \
    gpg --homedir /tmp/kemharbor/gnupg --batch --verify "/tmp/kemharbor/$base.asc" /tmp/kemharbor/mullvad-upgrade-tunnel; \
    chmod 0755 /tmp/kemharbor/mullvad-upgrade-tunnel

FROM registry.fedoraproject.org/fedora-minimal@sha256:85f06b1bce50801f26dc444ab401270a59aa3e8c96a1f0d56284088e0d5a18c7
LABEL org.opencontainers.image.source="https://github.com/Olize/kemharbor" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.description="Experimental Mullvad post-quantum WireGuard gateway"
RUN microdnf -y --setopt=install_weak_deps=False install wireguard-tools nftables iproute procps-ng curl ca-certificates jq coreutils bash && microdnf clean all
COPY --from=verify-mullvad /tmp/kemharbor/mullvad-upgrade-tunnel /usr/local/sbin/mullvad-upgrade-tunnel
COPY scripts/entrypoint.sh /usr/local/sbin/kemharbor-entrypoint
COPY scripts/postup.sh /usr/local/sbin/kemharbor-postup
COPY scripts/health.sh /usr/local/sbin/kemharbor-health
COPY scripts/validate.sh /usr/local/sbin/kemharbor-validate
RUN chmod 0755 /usr/local/sbin/mullvad-upgrade-tunnel /usr/local/sbin/kemharbor-entrypoint /usr/local/sbin/kemharbor-postup
ENTRYPOINT ["/usr/local/sbin/kemharbor-entrypoint"]
