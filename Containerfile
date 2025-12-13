# Renovate will automatically add digest pinning on first run
FROM ghcr.io/vanilla-os/desktop:main

# Add Surface kernel and drivers for full hardware support
# NOTE: Surface kernel is unsigned - requires Secure Boot to be disabled
RUN lpkg --unlock && \
    apt-get update && \
    apt-get install -y wget gnupg && \
    # Add linux-surface repository
    wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc | gpg --dearmor > /etc/apt/keyrings/linux-surface.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/linux-surface.gpg] https://pkg.surfacelinux.com/debian release main" > /etc/apt/sources.list.d/linux-surface.list && \
    apt-get update && \
    # Install Surface kernel and drivers for full hardware support
    apt-get install -y \
        linux-image-surface \
        linux-headers-surface \
        iptsd \
        libwacom-surface \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-libertas \
        network-manager \
        wireless-tools \
        rfkill \
        wpasupplicant && \
    # Enable touchscreen service
    systemctl enable iptsd@.service && \
    # Enable NetworkManager for wireless support
    systemctl enable NetworkManager.service && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    lpkg --lock

# IMPORTANT: This image includes unsigned Surface kernel
# Secure Boot must be disabled in BIOS/UEFI for the Surface kernel to boot
# ABRoot will handle boot configuration automatically
