# Vanilla OS Overview: Immutability and Containers

## What is Vanilla OS?

<cite index="1-1,13-11">Vanilla OS is a cutting-edge immutable Linux distribution that maintains a small, immutable core operating system while isolating additional software from that core through containerization or sandboxing.</cite> <cite index="1-2,14-21">The core is based on Open Container Initiative (OCI) images composed of packages from Debian sid</cite> (previously Ubuntu in v1).

## Immutability Explained

### Core Concept
<cite index="5-18,5-19">Vanilla OS is designed to be mostly immutable. By default, only /home, /etc, /opt, and /var can be written to in a separate partition.</cite> <cite index="6-20">The active root partition is marked as read-only: this is an immutable distro.</cite>

### A/B Root System
<cite index="11-35,5-23">ABRoot works by performing transactions between two root partitions, A and B. They each consist of an identical root filesystem partitioned with Btrfs, which hosts the core applications.</cite> <cite index="6-21,6-22">When you install updates or drivers, the OS updates the other root partition, then reboots into it. If anything goes wrong, it fails over automatically to the previous, known-good system.</cite>

## Container Technologies

### VSO (Vanilla System Operator)
<cite index="13-3,13-4,13-5">The default terminal emulator in Vanilla OS is Black Box, which enters a shell in the VSO subsystem by default. This environment allows users to work in a controlled system instance without affecting the immutable host OS. Users familiar with the Debian workflow will feel at home, as they can use apt and dpkg directly within the VSO environment.</cite>

**VSO is for:** Regular package installation and development work

### Apx (Multi-Distribution Containers)
<cite index="1-3,1-6">Vanilla OS allows users to install separate "subsystems" based on various Linux distributions through Apx, a wrapper around Distrobox. Vanilla OS includes a graphical user interface for Apx, enabling users to create a subsystem based on a stack (Alpine, Arch Linux, Fedora, openSUSE, Ubuntu, and Vanilla OS are supported by default) and a package manager (apk, apt, dnf, pacman, or zypper).</cite>

**Apx is for:** Accessing packages from different Linux distributions

### Flatpak
<cite index="13-18,13-19">Flatpak – A runtime system for graphical applications. It isolates applications using bubblewrap, a lightweight sandboxing tool based on Linux namespaces.</cite>

**Flatpak is for:** Sandboxed GUI applications

## Where to Run Your Apps and Tools

### 1. Regular Applications → VSO Container
- **Default location**: When you open a terminal, you're automatically in VSO
- **Package manager**: `apt` (Debian-style)
- **Use cases**: Development tools, CLI utilities, most user applications
- **Integration**: <cite index="1-8,1-9">Applications installed this way are "exported", which is a feature of Distrobox. The application then appears in GNOME's activities overview.</cite>

### 2. GUI Applications → Flatpak
- **Priority**: Use Flatpak first for GUI applications when available
- **Command**: `flatpak install <app>`
- **Benefits**: Sandboxed, secure, automatic updates

### 3. Distribution-Specific Software → Apx Subsystems  
- **Ubuntu packages**: `apx install <package>`
- **Arch packages**: `apx install --aur <package>`  
- **Fedora packages**: `apx install --dnf <package>`
- **Use cases**: When software isn't available in Debian or Flatpak

### 4. System-Level Software → ABRoot
- **Use only for**: Drivers, firmware, kernel modules
- **Command**: `abroot pkg add <package>` then `abroot pkg apply`
- **Warning**: <cite index="20-1,20-2">When installing packages with ABRoot, it's a good idea to limit them to essential items such as drivers or firmware that must reside on the host system. For user applications, it's preferable to install them via subsystems created by tools like Apx, virtual environments like VSO, or using Flatpak.</cite>

## Where to Run Code

### Development Environment Options

1. **VSO Container (Default)**
   - Perfect for most development work
   - Full Debian environment with `apt` package manager
   - Integrated with host filesystem
   
2. **Apx Development Containers**
   - <cite index="19-11">Dev Image: Can be used in APX, and provides a large set of development libraries/SDKs and tools.</cite>
   - Create language-specific environments (e.g., Node.js in Ubuntu container, Python in Fedora)
   
3. **Distrobox for Specialized Environments**
   - <cite index="3-14,3-15,3-16">Distrobox has nearly limitless potential for power users. One can integrate systemd in a container, using that compatibility to install integrated virtual machines and other fun stuff. One can also use Distrobox to run another desktop environment on top of one's distribution.</cite>

## How to Update the OS and Apps

### OS Updates
<cite index="1-20,14-23">Rather than handling system updates through a package manager, Vanilla OS downloads a new OCI image, and then uses the new image when it reboots.</cite>

**Manual Updates:**
```bash
# Check for updates
abroot upgrade --check-only

# Apply system updates  
abroot upgrade

# Force update
vso sys upgrade --now
```

**Automatic Updates:**
<cite index="18-4,18-5">VSO (Vanilla System Operator) periodically checks for an update and then downloads and installs it in the background if the device is not under heavy usage. VSO checks that certain checks are met, such as whether the resources are free (CPU/RAM), whether the connection allows it, whether the battery is at least 30%, etc.</cite>

### App Updates

- **VSO packages**: `apt update && apt upgrade` (inside VSO)
- **Flatpak**: `flatpak update`  
- **Apx subsystems**: Handled automatically or via `apx update`
- **ABRoot packages**: Updated with OS image updates

### Rollback System
<cite index="19-15,19-16,19-17">Did you encounter a system issue and need to revert to a previous stable state? With Orchid, this is quite simple, if something goes wrong, you can select the previous state during boot. After logging in, Orchid will prompt you to perform a rollback, once confirmed, this rollback becomes permanent until the next update.</cite>

## Key Commands Reference

### System Management
```bash
# System status
abroot status

# Update system
abroot upgrade
vso sys upgrade --now

# Rollback
abroot rollback

# Kernel parameters
abroot kargs show
abroot kargs edit
```

### Package Management
```bash
# ABRoot (system packages)
abroot pkg add <package>
abroot pkg remove <package>  
abroot pkg apply

# VSO (user packages - default environment)
apt install <package>
apt remove <package>

# Apx (multi-distro)
apx install <package>                 # Ubuntu
apx install --aur <package>           # Arch  
apx install --dnf <package>          # Fedora

# Flatpak
flatpak install <app>
flatpak update
```

### Container Management
```bash
# Access host shell from container
host-shell

# Reset VSO container if corrupted
reset-vso

# Create new Apx subsystem
apx subsystems new <name> --stack <distro>
```

## Summary

<cite index="3-2,3-3">Combining everything together, Vanilla OS is unprecedentedly low-maintenance and powerful. It has the potential to become a staple for non-technical individuals and Linux veterans alike.</cite> The system provides multiple isolated environments for different use cases while maintaining a stable, immutable core that can be safely updated and rolled back when needed.