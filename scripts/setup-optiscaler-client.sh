#!/usr/bin/env bash
# =============================================================================
# setup-optiscaler-client.sh
# Downloads the latest OptiScaler Client AppImage from GitHub,
# installs it to ~/.local/bin/, and creates a KDE .desktop launcher.
# Safe to re-run — skips download if already on the latest version.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

GITHUB_REPO="Agustinm28/Optiscaler-Client"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_NAME="OptiscalerClient"
INSTALL_PATH="${INSTALL_DIR}/${INSTALL_NAME}"
VERSION_FILE="${INSTALL_DIR}/.optiscaler-client-version"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/optiscaler-client.desktop"
TMP_DIR="$(mktemp -d)"; trap 'rm -rf "${TMP_DIR}"' EXIT

banner "OptiScaler Client — Install"
echo   "  Manages OptiScaler (FSR4 / DLSS spoof / XeSS) across your Steam library."
echo   "  Installed as a local AppImage — no root required."
echo   "  Enables DLSS inputs via FakeNvapi spoof on AMD GPUs."
echo

# ── 1. Fetch release info ─────────────────────────────────────────────────────
header "Fetching latest release from GitHub"
RELEASE_JSON="${TMP_DIR}/release.json"
fetch_github_release_json "${GITHUB_REPO}" "${RELEASE_JSON}"

APPIMAGE_URL=$(parse_asset_url "${RELEASE_JSON}" '\.AppImage$')
RELEASE_TAG=$(parse_release_tag "${RELEASE_JSON}")

if [[ -z "${APPIMAGE_URL}" ]]; then
    error "No AppImage asset found in the latest release."
    error "Check: https://github.com/${GITHUB_REPO}/releases"
    exit 1
fi

success "Latest release: ${RELEASE_TAG}"

# ── 2. Check if already current ───────────────────────────────────────────────
header "Checking current installation"
if [[ -f "${INSTALL_PATH}" && -f "${VERSION_FILE}" ]]; then
    INSTALLED_TAG=$(cat "${VERSION_FILE}")
    if [[ "${INSTALLED_TAG}" == "${RELEASE_TAG}" ]]; then
        success "Already up to date (${INSTALLED_TAG}). Nothing to do."
        echo
        echo -e "  To force a reinstall: rm ${VERSION_FILE} then re-run."
        exit 0
    else
        info "Update available: ${INSTALLED_TAG} → ${RELEASE_TAG}"
    fi
else
    info "Not installed yet — proceeding with fresh install."
fi

# ── 3. Download ───────────────────────────────────────────────────────────────
header "Downloading AppImage"
APPIMAGE_TMP="${TMP_DIR}/OptiscalerClient.AppImage"
dry_run_cmd curl -sSfL --progress-bar "${APPIMAGE_URL}" -o "${APPIMAGE_TMP}"
success "Download complete ($(du -sh "${APPIMAGE_TMP}" | cut -f1))"

# ── 4. Install ────────────────────────────────────────────────────────────────
header "Installing to ${INSTALL_PATH}"
mkdir -p "${INSTALL_DIR}"
cp "${APPIMAGE_TMP}" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"
echo "${RELEASE_TAG}" > "${VERSION_FILE}"
success "Installed: ${INSTALL_PATH}"

# ── 5. Desktop launcher ───────────────────────────────────────────────────────
header "Creating KDE application launcher"
mkdir -p "${DESKTOP_DIR}"

cat > "${DESKTOP_FILE}" << EOF
[Desktop Entry]
Name=OptiScaler Client
GenericName=GPU Upscaler Manager
Comment=Manage OptiScaler (FSR4/DLSS/XeSS) upscalers across your Steam library
Exec=${INSTALL_PATH}
Icon=applications-games
Terminal=false
Type=Application
Categories=Game;Utility;
Keywords=optiscaler;fsr4;dlss;xess;upscaler;amd;rdna4;gaming;fakenvapi;
StartupNotify=true
EOF

command -v update-desktop-database &>/dev/null \
    && update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
success "Launcher created: search 'OptiScaler' in KDE menu"

# ── 6. PATH check ─────────────────────────────────────────────────────────────
header "Checking PATH"
if echo "${PATH}" | grep -q "${HOME}/.local/bin"; then
    success "~/.local/bin is already in your PATH."
else
    warn "~/.local/bin is not in PATH. Add this to ~/.bashrc or ~/.zshrc:"
    echo
    echo '    export PATH="$HOME/.local/bin:$PATH"'
fi

# ── 7. Done ───────────────────────────────────────────────────────────────────
header "Done"
success "OptiScaler Client ${RELEASE_TAG} is installed."
echo
echo -e "  ${BOLD}Launch from terminal:${RESET}  OptiscalerClient"
echo -e "  ${BOLD}Or from KDE menu:${RESET}      search 'OptiScaler'"
echo
echo -e "  ${YELLOW}AMD GPU tip:${RESET} Most DLSS games require FakeNvapi to show the DLSS"
echo    "  option at all. In OptiScaler Client, enable 'FakeNvapi / NVAPI Spoof'"
echo    "  per game. Without it, DLSS simply won't appear in the game's menu."
echo
