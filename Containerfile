FROM ghcr.io/vanilla-os/desktop:main

# Add Surface drivers and WiFi firmware (keeping signed kernel for Secure Boot)
RUN lpkg --unlock && \
    apt-get update && \
    apt-get install -y wget gnupg && \
    # Add linux-surface repository for touchscreen drivers
    wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc | gpg --dearmor > /etc/apt/keyrings/linux-surface.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/linux-surface.gpg] https://pkg.surfacelinux.com/debian release main" > /etc/apt/sources.list.d/linux-surface.list && \
    apt-get update && \
    # Install Surface touchscreen and WiFi drivers
    apt-get install -y \
        iptsd \
        libwacom-surface \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree && \
    # Enable touchscreen service
    systemctl enable iptsd@.service && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    lpkg --lock

# Note: ABRoot will handle boot configuration automatically
