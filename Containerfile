FROM quay.io/hummingbird-community/bootc-os:latest

# Install packages for headless ARM64 Raspberry Pi system
# Note: targeting ARM64 architecture for Raspberry Pi 4/5
# Base: Fedora Hummingbird (zero-CVE target, ARK kernel, read-only root)
# Hummingbird pre-includes: chrony, podman, curl, python3, tar, gzip, NetworkManager

# Add Fedora Rawhide repo for packages not in Hummingbird's curated set
# gpgcheck=0 because Hummingbird doesn't ship the Fedora Rawhide GPG key
RUN cat > /etc/yum.repos.d/fedora-rawhide.repo << 'REPO'
[fedora-rawhide]
name=Fedora - Rawhide
metalink=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch
enabled=1
gpgcheck=0
skip_if_unavailable=False
REPO

# WiFi support + iptables-nft (for Tailscale dependency) + vim
RUN dnf install -y \
    --disablerepo='*' --enablerepo='fedora-rawhide' \
    NetworkManager-wifi \
    wpa_supplicant \
    iw \
    iptables-nft \
    vim-minimal && \
    dnf clean all

# Remove Fedora repo — all further installs from Hummingbird only
RUN rm -f /etc/yum.repos.d/fedora-rawhide.repo

# Add Tailscale repository and install (iptables-nft satisfies dependency)
RUN curl -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
    -o /etc/yum.repos.d/tailscale.repo
RUN dnf install -y tailscale && dnf clean all

# Supplementary tools from Hummingbird repos
RUN dnf install -y jq git unzip && dnf clean all

# Create directories for node-exporter monitoring
RUN mkdir -p /etc/containers/systemd

# Copy Quadlet configuration files for node-exporter only
COPY node-exporter.container /etc/containers/systemd/

# Copy WiFi configuration script
COPY wifi-setup.sh /usr/local/bin/
COPY tailscale-setup.sh /usr/local/bin/

# Set permissions and enable services
RUN chmod +x /usr/local/bin/wifi-setup.sh && \
    chmod +x /usr/local/bin/tailscale-setup.sh && \
    systemctl enable chronyd && \
    systemctl enable tailscaled && \
    systemctl enable sshd && \
    systemctl enable NetworkManager

# Bake in containers-policy for update stream lockdown
RUN mkdir -p /usr/share/pki/sigstore /etc/containers/registries.d
COPY containers-policy/cosign.pub /usr/share/pki/sigstore/cosign.pub
COPY containers-policy/ghcr.io-tempest-concorde.yaml /etc/containers/registries.d/ghcr.io-tempest-concorde.yaml
COPY containers-policy/policy.json /etc/containers/policy.json
RUN chmod 0444 /etc/containers/policy.json /etc/containers/registries.d/ghcr.io-tempest-concorde.yaml

# Run bootc container lint
RUN bootc container lint
