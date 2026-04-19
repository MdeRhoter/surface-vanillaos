#!/bin/bash

# Vanilla OS System Update Script
# Updates all subsystems, flatpaks, and the host OS

set -e

# Parse command line arguments
SKIP_CONFIRMATION=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -h|--help)
            echo "Vanilla OS System Update Script"
            echo "Updates all subsystems, flatpaks, and the host OS"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes    Skip confirmation prompt and proceed automatically"
            echo "  -h, --help   Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run command with error handling
run_cmd() {
    local cmd="$1"
    local description="$2"
    
    log "Running: $description"
    if ! eval "$cmd"; then
        error "Failed to: $description"
        return 1
    fi
    success "$description completed"
}

# Function to check what's available and build update plan
check_available_systems() {
    local systems=()
    
    # Check current subsystem
    if command_exists apt; then
        systems+=("Current APT-based subsystem (Debian/Ubuntu)")
        if command_exists snap; then
            systems+=("Snap packages in current subsystem")
        fi
    fi
    
    # Check Flatpak
    if command_exists flatpak; then
        local flatpak_count=$(flatpak list --app 2>/dev/null | wc -l || echo "0")
        systems+=("Flatpak applications ($flatpak_count apps)")
    fi
    
    # Check host system upgrade path (prefer host-shell -> abroot because
    # `vso update` under a zsh host login shell hits the "no such option: pty"
    # bug in vso 3.x)
    if command_exists host-shell; then
        systems+=("Host Vanilla OS system (via abroot through host-shell)")
    elif command_exists abroot; then
        systems+=("Host system (via abroot)")
    elif [ -n "$HOSTNAME" ] && [ "$HOSTNAME" = "vanilla" ]; then
        systems+=("Host Vanilla OS system (detection attempt)")
    fi
    
    # Check APX subsystems
    if command_exists apx; then
        local subsystems=$(apx subsystems list 2>/dev/null | grep '┊.*┊.*┊.*┊' | grep -v 'NAME.*STACK.*STATUS.*PKGS' | awk -F'┊' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); if($2 != "") print $2}' | wc -l || echo "0")
        if [ "$subsystems" -gt 0 ]; then
            systems+=("APX subsystems ($subsystems subsystems)")
        fi
    fi
    
    # Check other package managers
    if command_exists brew; then
        systems+=("Homebrew packages")
    fi
    
    if command_exists pip3; then
        local pip_outdated=$(pip3 list --outdated 2>/dev/null | wc -l || echo "0")
        if [ "$pip_outdated" -gt 0 ]; then
            systems+=("Python pip packages")
        fi
    fi
    
    printf '%s\n' "${systems[@]}"
}

echo "==================================="
echo "   Vanilla OS System Update"
echo "==================================="
echo ""

# Show what will be updated
log "Checking available systems and packages..."
available_systems=$(check_available_systems)

if [ -z "$available_systems" ]; then
    error "No updatable systems or packages found!"
    exit 1
fi

echo ""
echo -e "${BLUE}The following systems and packages will be updated:${NC}"
echo "$available_systems" | sed 's/^/  • /'
echo ""
echo -e "${BLUE}Additional maintenance tasks:${NC}"
echo "  • Clean package caches"
echo "  • Update system databases"
echo ""

# Ask for confirmation (unless bypassed)
if [ "$SKIP_CONFIRMATION" = false ]; then
    read -p "Do you want to proceed with the update? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warning "Update cancelled by user."
        exit 0
    fi
else
    log "Skipping confirmation (--yes flag provided)"
fi

echo ""
log "Starting system update..."
echo ""

# 1. Update current subsystem (if in Debian/Ubuntu subsystem)
if command_exists apt; then
    log "Detected APT-based subsystem - updating current subsystem"
    run_cmd "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y" "Update current APT-based subsystem"
    
    # Check for snapd in this subsystem
    if command_exists snap; then
        run_cmd "sudo snap refresh" "Update snaps in current subsystem"
    fi
fi

# 2. Update Flatpak applications
if command_exists flatpak; then
    log "Updating Flatpak applications"
    run_cmd "flatpak update -y" "Update Flatpak applications"
    run_cmd "flatpak uninstall --unused -y" "Remove unused Flatpak runtimes"
else
    warning "Flatpak not found in current environment"
fi

# 3. Try to update host Vanilla OS system
log "Attempting to update host Vanilla OS system"

# Note: `vso update` in vso 3.x spawns a shell command on the host that uses
# bash-only option toggles (e.g. `set -o pty`). When the host user's login
# shell is zsh, this fails with "zsh: no such option: pty". We can't work
# around this from inside pico because host-spawn runs on the host using the
# host login shell, regardless of any env we set here.
#
# Instead, call `abroot upgrade` on the host. Notes:
#   * `abroot` in pico is a symlink dispatched to the host via host-shell.
#   * `abroot` itself requires root ("You must be root to run this command")
#     and does not always self-escalate, so we run it through `pkexec` to
#     get a polkit prompt. `sudo` is not installed in pico and is not needed.
#   * `abroot` is inconsistent about exit codes: it may exit 0 when printing
#     an `ERROR` line, and it may exit non-zero for the benign "No update
#     available" case. We inspect the output to decide.
upgrade_host() {
    local cmd="$1"
    local description="$2"
    local output
    local status

    log "Running: $description"
    output=$(eval "$cmd" 2>&1)
    status=$?
    printf '%s\n' "$output"

    # "No update available" is a success, regardless of exit status.
    if printf '%s\n' "$output" | grep -qE 'No update available\.?'; then
        success "$description (no update available)"
        return 0
    fi

    # An explicit ERROR line means failure even if abroot exited 0.
    if printf '%s\n' "$output" | grep -qE '^\s*ERROR\b'; then
        error "Failed to: $description"
        return 1
    fi

    if [ "$status" -ne 0 ]; then
        error "Failed to: $description"
        return 1
    fi

    success "$description completed"
}

if command_exists pkexec && command_exists abroot; then
    log "Upgrading host system via pkexec abroot"
    upgrade_host "pkexec abroot upgrade" "Update host Vanilla OS system (pkexec abroot)" \
        || warning "abroot upgrade failed - you may need to run it from a host terminal"
elif command_exists host-shell; then
    log "Falling back to host-shell -> pkexec abroot upgrade"
    upgrade_host "host-shell pkexec abroot upgrade" "Update host Vanilla OS system (pkexec abroot via host-shell)" \
        || warning "abroot upgrade failed - you may need to run it from a host terminal"
elif command_exists abroot; then
    # No pkexec/host-shell available; try abroot directly and hope it escalates
    log "pkexec not available - attempting plain abroot upgrade"
    upgrade_host "abroot upgrade" "Update host Vanilla OS system (abroot)" \
        || warning "abroot upgrade failed - run 'pkexec abroot upgrade' from the host directly"
else
    warning "No host-upgrade tool available (abroot/host-shell). Host system update skipped."
    warning "Run 'pkexec abroot upgrade' from the host system directly."
fi

echo ""
echo "==================================="
echo "   APX Subsystems Update"
echo "==================================="

# 4. Update APX subsystems (if available)
APX_UPDATE_SUCCESS=false
if command_exists apx; then
    log "Checking for APX subsystems to update"
    
    # List and update all APX subsystems
    log "Running: apx subsystems list"
    apx_subsystems_raw=$(apx subsystems list 2>/dev/null || true)
    log "APX subsystems list output:"
    echo "$apx_subsystems_raw" | sed 's/^/    /'
    
    apx_subsystems=$(echo "$apx_subsystems_raw" | grep '┊.*┊.*┊.*┊' | grep -v 'NAME.*STACK.*STATUS.*PKGS' | awk -F'┊' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); if($2 != "") print $2}' || true)
    
    log "Parsed subsystem names: $apx_subsystems"
    
    if [ -n "$apx_subsystems" ]; then
        for subsystem in $apx_subsystems; do
            echo ""
            log "=== Updating APX subsystem: $subsystem ==="
            
            # Use apx surface to update the subsystem
            #
            # Note: we run `full-upgrade` instead of `upgrade`. Plain
            # `apt upgrade` (which is what `apx <subsystem> upgrade` maps to)
            # is conservative and refuses to upgrade a package when its new
            # version adds new Recommends/Depends, even if resolving them
            # would not actually install anything. `full-upgrade`
            # (a.k.a. `dist-upgrade`) uses the stronger solver and upgrades
            # those kept-back packages (e.g. VS Code adding `bubblewrap`,
            # `socat` to its Recommends).
            #
            # `apx <subsystem>` only accepts a fixed set of wrapper
            # subcommands (install/upgrade/etc.), so to invoke apt-get with
            # `full-upgrade` we go through `apx <subsystem> run ...` which
            # executes a raw command inside the subsystem.
            log "Step 1: Updating package lists"
            if run_cmd "apx surface update" "Update package list for APX subsystem: $subsystem"; then
                log "Step 2: Upgrading packages (full-upgrade)"
                # `--` stops apx from parsing the subcommand's flags
                # (otherwise `apx surface run` complains about `-y`).
                if run_cmd "apx surface run -- sudo apt-get -y full-upgrade" "Full-upgrade packages in APX subsystem: $subsystem"; then
                    success "Successfully updated APX subsystem: $subsystem"
                    APX_UPDATE_SUCCESS=true
                else
                    warning "Failed to full-upgrade packages in APX subsystem: $subsystem"
                    APX_UPDATE_SUCCESS=false
                fi
            else
                warning "Failed to update package list for APX subsystem: $subsystem"
                APX_UPDATE_SUCCESS=false
            fi
        done
    else
        warning "No APX subsystems found or failed to parse subsystem names"
        log "This might be because:"
        log "  - No subsystems are created yet"
        log "  - The parsing logic needs adjustment for your APX version"
        log "  - APX subsystems list format has changed"
    fi
else
    log "APX command not found - skipping subsystem updates"
fi

# 5. Update other package managers that might be available
# Check for additional package managers
if command_exists brew; then
    log "Updating Homebrew packages"
    run_cmd "brew update && brew upgrade" "Update Homebrew packages"
fi

if command_exists pip3; then
    log "Updating pip packages"
    run_cmd "pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U" "Update pip packages" || warning "Some pip packages may have failed to update"
fi

# 6. System maintenance
log "Performing system maintenance"

# Clean package caches
if command_exists apt; then
    run_cmd "sudo apt autoclean" "Clean APT cache"
fi

# Update locate database if available
if command_exists updatedb; then
    run_cmd "sudo updatedb" "Update locate database"
fi

# 7. Final summary
echo ""
echo "==================================="
echo "   Update Summary"
echo "==================================="

if command_exists apt; then
    echo "✓ APT-based subsystem updated"
fi

if command_exists flatpak; then
    echo "✓ Flatpak applications updated"
fi

if command_exists host-shell || command_exists abroot; then
    echo "✓ Host Vanilla OS system update attempted (via abroot)"
else
    echo "⚠ Host Vanilla OS system update may need manual intervention"
fi

if command_exists apx; then
    if [ "$APX_UPDATE_SUCCESS" = true ]; then
        echo "✓ APX subsystems successfully updated"
    else
        echo "⚠ APX subsystems checked but updates may have failed"
    fi
fi

echo ""
success "System update completed!"
echo ""
echo "Note: If you're running this from within the vso-pico subsystem,"
echo "the host OS upgrade is performed by 'abroot upgrade' (which is"
echo "dispatched to the host and self-escalates via pkexec)."
echo "Run it directly from the host if you need to intervene manually."
