# Surface-enabled Vanilla OS

This repository contains a custom Vanilla OS image with Microsoft Surface drivers and touchscreen support.

## What's included

- **Linux Surface kernel** (6.17.1-surface-2) with IPTS drivers for touchscreen support
- **IPTSD daemon** for Intel Precise Touch & Stylus functionality
- **Wacom Surface support** for stylus input
- All standard Vanilla OS desktop features

## Usage

1. **Configure ABRoot** to use this custom image:
   ```bash
   abroot config-editor
   ```
   
2. **Change the "name" entry** from `vanilla-os/desktop` to `your-github-username/surface-vanillaos`

3. **Upgrade your system**:
   ```bash
   abroot upgrade
   ```

4. **Reboot** to the new Surface-enabled system

## Hardware Support

This image is specifically designed for Microsoft Surface devices, particularly:
- Surface Laptop (Gen 1)
- Surface Pro models with IPTS touchscreens
- Other Surface devices requiring linux-surface drivers

## Building

The image is automatically built via GitHub Actions and published to GitHub Container Registry (GHCR).

## Requirements

- Vanilla OS 2.0+ with ABRoot
- Microsoft Surface device
- Internet connection for pulling the image

## Notes

- The first upgrade may take longer as it downloads the new kernel and drivers
- After upgrading, your touchscreen should work automatically
- Weekly builds ensure you get the latest base OS updates