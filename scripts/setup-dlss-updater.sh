#!/usr/bin/env bash
# =============================================================================
# setup-dlss-updater.sh
# Installs DLSS Updater (Flatpak bundle, latest release from GitHub)
# and grants it access to your Steam game library paths.
# Safe to re-run — skips install if already up to date.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

FLATPAK_APP_ID="io.github.recol.dlss-updater"
GITHUB_REPO="Recol/DLSS-Updater"
TMP_DIR="$(mktemp -d)"; trap 'rm -rf "${TMP_DIR}"' EXIT

banner "DLSS Updater — Install & Configure"
echo   "  Keeps all the DLSS/XeSS DLLs in your Steam games up to date."
echo   "  Installed as a Flatpak for clean sandboxing on all supported distros."
echo

# ── 1. Flatpak preflight ──────────────────────────────────────────────────────
ensure_flatpak

# ── 2. Already installed? ─────────────────────────────────────────────────────
header "Checking current installation"
if flatpak list --app --user 2>/dev/null | grep -q "${FLATPAK_APP_ID}"; then
    INSTALLED_VER=$(flatpak info --user "${FLATPAK_APP_ID}" 2>/dev/null \
        | grep -i version | awk '{print $2}' || echo "unknown")
    success "DLSS Updater already installed (version: ${INSTALLED_VER})"
    info    "Skipping download — jumping straight to permissions check."
    SKIP_INSTALL=true
else
    SKIP_INSTALL=false
fi

if [[ "${SKIP_INSTALL}" == "false" ]]; then
    # ── 3. Fetch latest release ───────────────────────────────────────────────
    header "Fetching latest release from GitHub"
    RELEASE_JSON="${TMP_DIR}/release.json"
    fetch_github_release_json "${GITHUB_REPO}" "${RELEASE_JSON}"

    FLATPAK_URL=$(parse_asset_url "${RELEASE_JSON}" '\.flatpak$')
    RELEASE_TAG=$(parse_release_tag "${RELEASE_JSON}")

    if [[ -z "${FLATPAK_URL}" ]]; then
        error "No .flatpak asset found in the latest release."
        error "Download manually: https://github.com/${GITHUB_REPO}/releases"
        error "Then run:  flatpak install --user DLSS_Updater-X.Y.Z.flatpak"
        exit 1
    fi

    success "Latest release: ${RELEASE_TAG}"
    info    "URL: ${FLATPAK_URL}"

    # ── 4. Download ───────────────────────────────────────────────────────────
    header "Downloading Flatpak bundle"
    FLATPAK_FILE="${TMP_DIR}/DLSS_Updater.flatpak"
    dry_run_cmd curl -sSfL --progress-bar "${FLATPAK_URL}" -o "${FLATPAK_FILE}"
    success "Download complete ($(du -sh "${FLATPAK_FILE}" | cut -f1))"

    # ── 5. Install ────────────────────────────────────────────────────────────
    header "Installing Flatpak bundle"
    if ! dry_run_cmd flatpak install --user --noninteractive "${FLATPAK_FILE}"; then
        error "Flatpak install failed."
        error "You may need to install the runtime first:"
        error "  flatpak install --user flathub org.freedesktop.Platform//24.08"
        exit 1
    fi
    success "DLSS Updater installed."
fi

# ── 6. Permissions ────────────────────────────────────────────────────────────
header "Granting Steam library filesystem permissions"

PATHS_TO_GRANT=(
    "${HOME}/.steam"
    "${HOME}/.local/share/Steam"
    "${HOME}/Games"          # Lutris
    "${HOME}/.wine"          # Wine prefix
)

for path in "${PATHS_TO_GRANT[@]}"; do
    if [[ -d "${path}" ]]; then
        flatpak override --user --filesystem="${path}" "${FLATPAK_APP_ID}" \
            && success "  Granted: ${path}" \
            || warn    "  Could not grant: ${path}"
    else
        info "  Skipping (not found): ${path}"
    fi
done

# ── 7. Done ───────────────────────────────────────────────────────────────────
header "Done"
VER=$(flatpak info --user "${FLATPAK_APP_ID}" 2>/dev/null \
    | grep -i version | awk '{print $2}' || echo "installed")
success "DLSS Updater ${VER} is ready."
echo
echo -e "  ${BOLD}Launch:${RESET}  flatpak run ${FLATPAK_APP_ID}"
echo    "  Or search 'DLSS Updater' in your KDE application launcher."
echo    "  On first launch it will auto-scan your Steam library for DLL updates."
echo
