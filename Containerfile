FROM ghcr.io/vanilla-os/desktop:main

# Add linux-surface repository and key
RUN lpkg --unlock && \
    apt-get update && \
    apt-get install -y wget gnupg && \
    wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc | gpg --dearmor > /etc/apt/keyrings/linux-surface.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/linux-surface.gpg] https://pkg.surfacelinux.com/debian release main" > /etc/apt/sources.list.d/linux-surface.list && \
    apt-get update && \
    apt-get install -y linux-image-surface linux-headers-surface iptsd libwacom-surface && \
    systemctl enable iptsd@.service && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    lpkg --lock

# Set the default kernel to Surface kernel
RUN update-grub