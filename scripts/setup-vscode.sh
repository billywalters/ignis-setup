#!/usr/bin/env bash
# =============================================================================
# setup-vscode.sh
# Installs Visual Studio Code and configures it for Linux development.
#
# Install method per OS:
#   fedora-atomic  → Flatpak (com.visualstudio.code) + home dir permission
#   arch/CachyOS   → AUR (visual-studio-code-bin) with paru/yay fallback,
#                    then Flatpak if AUR is unavailable
#   steamos        → Flatpak + home dir permission (survives OS updates)
#   debian/ubuntu  → Microsoft apt repository (best update experience)
#   any other      → Flatpak fallback
#
# After install: grants --filesystem=home so VS Code can open any project folder.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

VSCODE_FLATPAK="com.visualstudio.code"

banner "VS Code — Install"
echo   "  OS: ${OS_PRETTY} (${OS_FAMILY})"
echo

# ── Install ───────────────────────────────────────────────────────────────────
header "Step 1: Installing VS Code"

case "${OS_FAMILY}" in
    # ── Bazzite / Fedora Atomic ───────────────────────────────────────────────
    # Flatpak is the right choice here. The Bazzite docs explicitly warn against
    # layering Electron apps via rpm-ostree as they can block future OS updates.
    fedora-atomic)
        ensure_flatpak
        if flatpak list --app --user 2>/dev/null | grep -q "${VSCODE_FLATPAK}"; then
            success "VS Code already installed."
        else
            info "Installing VS Code from Flathub..."
            dry_run_cmd flatpak install --user --noninteractive flathub "${VSCODE_FLATPAK}"
            success "VS Code installed."
        fi
        ;;

    # ── CachyOS / Arch ────────────────────────────────────────────────────────
    # visual-studio-code-bin from the AUR gives the full Microsoft binary
    # with the Extensions Marketplace, Settings Sync, and all proprietary features.
    # Falls back to Flatpak if no AUR helper is found.
    arch)
        if command -v paru &>/dev/null || command -v yay &>/dev/null; then
            if pacman -Qi visual-studio-code-bin &>/dev/null 2>&1; then
                success "VS Code (visual-studio-code-bin) already installed."
            else
                info "Installing visual-studio-code-bin from AUR..."
                dry_run_cmd pkg_install_aur "visual-studio-code-bin"
                success "VS Code installed via AUR."
            fi
        else
            warn "No AUR helper found (paru/yay). Falling back to Flatpak."
            ensure_flatpak
            dry_run_cmd flatpak install --user --noninteractive flathub "${VSCODE_FLATPAK}"
            success "VS Code installed via Flatpak."
        fi
        ;;

    # ── SteamOS ───────────────────────────────────────────────────────────────
    steamos)
        steamos_persist_warn
        ensure_flatpak
        if flatpak list --app --user 2>/dev/null | grep -q "${VSCODE_FLATPAK}"; then
            success "VS Code already installed."
        else
            info "Installing VS Code from Flathub (Flatpak survives SteamOS updates)..."
            dry_run_cmd flatpak install --user --noninteractive flathub "${VSCODE_FLATPAK}"
            success "VS Code installed."
        fi
        ;;

    # ── Debian / Ubuntu ───────────────────────────────────────────────────────
    # Microsoft's official apt repo gives the best update experience on Debian:
    # VS Code updates via apt alongside your normal system packages.
    debian)
        if command -v code &>/dev/null; then
            success "VS Code already installed: $(code --version 2>/dev/null | head -1)"
        else
            info "Adding Microsoft apt repository..."
            dry_run_cmd sudo apt-get install -y wget gpg apt-transport-https

            if [[ "${DRY_RUN}" == "false" ]]; then
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                    | gpg --dearmor > /tmp/packages.microsoft.gpg
                sudo install -D -o root -g root -m 644 \
                    /tmp/packages.microsoft.gpg \
                    /usr/share/keyrings/packages.microsoft.gpg
                echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
                    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
                rm -f /tmp/packages.microsoft.gpg
                sudo apt-get update -q
            else
                info "[DRY-RUN] Would add Microsoft apt repository and run apt-get update"
            fi

            dry_run_cmd sudo apt-get install -y code
            success "VS Code installed via Microsoft apt repository."
            info "Future updates: sudo apt-get update && sudo apt-get upgrade"
        fi
        ;;

    # ── Fallback ──────────────────────────────────────────────────────────────
    *)
        warn "Unknown OS family '${OS_FAMILY}' — using Flatpak."
        ensure_flatpak
        dry_run_cmd flatpak install --user --noninteractive flathub "${VSCODE_FLATPAK}"
        success "VS Code installed via Flatpak."
        ;;
esac

# ── Flatpak: grant home directory access ─────────────────────────────────────
# Without this, the VS Code Flatpak can only see a limited set of paths.
# This lets you open any project folder from your home directory.
if flatpak list --app --user 2>/dev/null | grep -q "${VSCODE_FLATPAK}"; then
    header "Step 2: Granting home directory access"
    dry_run_cmd flatpak override --user --filesystem=home "${VSCODE_FLATPAK}"
    success "Home directory access granted."

    # Also grant access to common development paths
    dry_run_cmd flatpak override --user \
        --filesystem=xdg-run/gnupg:ro \
        --socket=ssh-auth \
        "${VSCODE_FLATPAK}" 2>/dev/null || true
    success "SSH agent socket access granted (for Git over SSH)."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
banner "VS Code Setup Complete"
echo
success "VS Code is installed and ready."
echo
echo -e "  ${BOLD}Launch:${RESET}"
if command -v code &>/dev/null; then
    echo    "    code               (open VS Code)"
    echo    "    code .             (open current folder in VS Code)"
    echo    "    code /path/to/dir  (open a specific folder)"
elif flatpak list --app --user 2>/dev/null | grep -q "${VSCODE_FLATPAK}"; then
    echo    "    flatpak run ${VSCODE_FLATPAK}"
    echo    "    Or search 'VS Code' in your app launcher"
fi
echo
echo -e "  ${BOLD}Recommended first steps:${RESET}"
echo    "    1. Sign in with your Microsoft account → Settings Sync across machines"
echo    "    2. Install the extensions you need from the Extensions panel (Ctrl+Shift+X)"
echo    "    3. For working on Ignis: install 'Rust Analyzer' and 'ES7+ React/Redux' extensions"
echo
if [[ "${OS_FAMILY}" == "arch" ]] && command -v code &>/dev/null; then
    echo -e "  ${YELLOW}Note (AUR install):${RESET} The full Microsoft binary is installed."
    echo    "  Extensions Marketplace, Settings Sync, and GitHub Copilot all work."
    echo
elif flatpak list --app --user 2>/dev/null | grep -q "${VSCODE_FLATPAK}"; then
    echo -e "  ${YELLOW}Note (Flatpak install):${RESET} If a terminal inside VS Code can't find"
    echo    "  a command (e.g. cargo, node, git), check that the path is in your"
    echo    "  \$PATH inside the Flatpak environment. Most tools work fine."
    echo
fi
