# Fedora 45 bootc base — pinned to SHA256 digest of the floating :45 stream tag
# (multi-arch manifest list digest). Dependabot opens a PR when Fedora rebuilds
# the :45 tag with a new digest.
FROM quay.io/fedora/fedora-bootc:46@sha256:e90c3e10e79cfed7e5e30f12492bd01e05689c926af21f2c40c5c626b9d402aa

# Platform layer for headless ARM64 Raspberry Pi 4/5
# Provides: WiFi, Tailscale VPN, node-exporter, SSH

# WiFi support + iptables-nft (Tailscale dependency) + tools
RUN dnf install -y \
    NetworkManager-wifi \
    wpa_supplicant \
    iw \
    iptables-nft \
    vim-minimal \
    jq \
    git \
    unzip \
    && dnf clean all

# Tailscale VPN
RUN curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
    -o /etc/yum.repos.d/tailscale.repo && \
    dnf install -y tailscale && \
    dnf clean all

# Node-exporter quadlet
RUN mkdir -p /etc/containers/systemd
COPY node-exporter.container /etc/containers/systemd/

# First-boot scripts
COPY wifi-setup.sh /usr/local/bin/
COPY tailscale-setup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wifi-setup.sh /usr/local/bin/tailscale-setup.sh

# Enable services
RUN systemctl enable chronyd tailscaled sshd NetworkManager

# Container update policy — only pull from signed tempest-concorde images
RUN mkdir -p /usr/share/pki/sigstore /etc/containers/registries.d
COPY containers-policy/cosign.pub /usr/share/pki/sigstore/cosign.pub
COPY containers-policy/ghcr.io-tempest-concorde.yaml /etc/containers/registries.d/ghcr.io-tempest-concorde.yaml
COPY containers-policy/policy.json /etc/containers/policy.json
RUN chmod 0444 /etc/containers/policy.json /etc/containers/registries.d/ghcr.io-tempest-concorde.yaml

RUN bootc container lint
