#!/usr/bin/env bash
# =============================================================================
# build.sh — Build Ignis from source
#
# Detects your Linux distro and installs build dependencies via the correct
# package manager. Works on Bazzite/Fedora Atomic, CachyOS/Arch, and Ubuntu.
#
# Usage:
#   bash build.sh            Build the app
#   bash build.sh --dry-run  Show what would be installed, without doing it
#
# Output (after a successful build):
#   src-tauri/target/release/bundle/appimage/ignis-setup_*.AppImage
#   src-tauri/target/release/bundle/rpm/ignis-setup-*.rpm   (Fedora)
#   src-tauri/target/release/bundle/deb/ignis-setup-*.deb   (Debian)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source _common.sh for OS detection and pkg_install
source "${SCRIPT_DIR}/scripts/_common.sh"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Pinned versions for reproducible builds
RUST_TOOLCHAIN="stable"          # change to e.g. "1.78.0" to pin exactly
TAURI_CLI_VERSION="^2"           # Tauri CLI semver range
NODE_MIN_VERSION="18"            # minimum Node major version required

banner "Ignis — Build Script"
echo   "  OS:      ${OS_PRETTY} (${OS_FAMILY})"
echo   "  DryRun:  ${DRY_RUN}"
echo

dry() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Would run: $*"
    else
        "$@"
    fi
}

# ── 1. Rust ───────────────────────────────────────────────────────────────────
header "Rust toolchain (${RUST_TOOLCHAIN})"
if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Would run: curl rustup installer | sh"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --default-toolchain "${RUST_TOOLCHAIN}"
        source "${HOME}/.cargo/env"
        success "Rust installed: $(rustc --version)"
    fi
else
    dry rustup update "${RUST_TOOLCHAIN}" --quiet
    success "Rust: $(rustc --version 2>/dev/null || echo 'installed')"
fi
source "${HOME}/.cargo/env" 2>/dev/null || true

# ── 2. Node.js ────────────────────────────────────────────────────────────────
header "Node.js (minimum v${NODE_MIN_VERSION})"
NODE_OK=false
if command -v node &>/dev/null; then
    NODE_VER=$(node --version | tr -d 'v' | cut -d. -f1)
    if (( NODE_VER >= NODE_MIN_VERSION )); then
        success "Node: $(node --version)  npm: $(npm --version)"
        NODE_OK=true
    else
        warn "Node $(node --version) is too old (need v${NODE_MIN_VERSION}+)"
    fi
fi

if [[ "${NODE_OK}" == "false" ]]; then
    info "Installing Node.js..."
    case "${OS_FAMILY}" in
        fedora-atomic)
            if [[ "${DRY_RUN}" == "false" ]]; then
                rpm-ostree install --idempotent nodejs npm
                echo -e "  ${YELLOW}Reboot required. Re-run: bash build.sh${RESET}"
                exit 0
            else
                info "[DRY-RUN] Would run: rpm-ostree install nodejs npm  (+ reboot)"
            fi ;;
        arch)
            dry sudo pacman -S --noconfirm --needed nodejs npm ;;
        debian)
            # Use NodeSource repo for a current version
            dry sudo apt-get install -y curl
            if [[ "${DRY_RUN}" == "false" ]]; then
                curl -fsSL https://deb.nodesource.com/setup_${NODE_MIN_VERSION}.x | sudo -E bash -
                sudo apt-get install -y nodejs
            else
                info "[DRY-RUN] Would install via NodeSource repo"
            fi ;;
        *)
            error "Cannot install Node.js on OS family '${OS_FAMILY}'."
            error "Install Node.js v${NODE_MIN_VERSION}+ manually, then re-run."
            exit 1 ;;
    esac
fi

# ── 3. WebKitGTK / system build deps ─────────────────────────────────────────
header "WebKitGTK and Tauri system dependencies"
case "${OS_FAMILY}" in
    fedora-atomic|fedora)
        WEBKIT_PKGS=(webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel openssl-devel)
        MISSING_PKGS=()
        for pkg in "${WEBKIT_PKGS[@]}"; do
            rpm -q "${pkg}" &>/dev/null || MISSING_PKGS+=("${pkg}")
        done
        if (( ${#MISSING_PKGS[@]} > 0 )); then
            info "Missing: ${MISSING_PKGS[*]}"
            if [[ "${DRY_RUN}" == "false" ]]; then
                rpm-ostree install --idempotent "${MISSING_PKGS[@]}"
                echo -e "  ${YELLOW}Reboot required. Re-run: bash build.sh${RESET}"
                exit 0
            else
                info "[DRY-RUN] Would run: rpm-ostree install ${MISSING_PKGS[*]}  (+ reboot)"
            fi
        else
            success "All WebKitGTK dependencies present."
        fi ;;
    arch)
        WEBKIT_PKGS=(webkit2gtk-4.1 gtk3 libappindicator-gtk3 openssl base-devel)
        dry sudo pacman -S --noconfirm --needed "${WEBKIT_PKGS[@]}"
        success "Arch WebKitGTK dependencies installed." ;;
    debian)
        WEBKIT_PKGS=(libwebkit2gtk-4.1-dev libgtk-3-dev libappindicator3-dev libssl-dev \
                     build-essential curl wget file libayatana-appindicator3-dev librsvg2-dev)
        dry sudo apt-get install -y "${WEBKIT_PKGS[@]}"
        success "Debian WebKitGTK dependencies installed." ;;
    steamos)
        warn "SteamOS: build dependencies require read-only filesystem bypass."
        warn "Consider building on a standard Arch or Fedora machine instead."
        dry sudo steamos-readonly disable
        dry sudo pacman -S --noconfirm --needed webkit2gtk-4.1 gtk3 base-devel
        dry sudo steamos-readonly enable ;;
    *)
        warn "Unknown OS family '${OS_FAMILY}' — skipping system deps."
        warn "Ensure WebKitGTK 4.1, GTK3, and OpenSSL development libraries are installed." ;;
esac

# ── 4. Tauri CLI ──────────────────────────────────────────────────────────────
header "Tauri CLI (${TAURI_CLI_VERSION})"
if ! cargo tauri --version &>/dev/null 2>&1; then
    info "Installing Tauri CLI..."
    dry cargo install tauri-cli --version "${TAURI_CLI_VERSION}" --locked
else
    success "Tauri CLI: $(cargo tauri --version 2>/dev/null || echo 'installed')"
fi

# ── 5. npm dependencies ───────────────────────────────────────────────────────
header "npm dependencies"
dry npm install
[[ "${DRY_RUN}" == "false" ]] && success "npm packages installed."

# ── 6. Build ──────────────────────────────────────────────────────────────────
if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY-RUN] Would run: npm run tauri build"
    info "[DRY-RUN] Build complete — no files changed."
    exit 0
fi

header "Building Ignis (~3–5 min first time)"
npm run tauri build

# ── 7. Report output ──────────────────────────────────────────────────────────
header "Build complete"
echo
for pattern in \
    "src-tauri/target/release/bundle/appimage/*.AppImage" \
    "src-tauri/target/release/bundle/rpm/*.rpm" \
    "src-tauri/target/release/bundle/deb/*.deb"; do
    file=$(ls ${pattern} 2>/dev/null | head -1 || true)
    [[ -n "${file}" ]] && success "$(basename "${file%.}") → ${file}"
done
echo
