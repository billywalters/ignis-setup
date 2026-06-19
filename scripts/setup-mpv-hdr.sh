#!/usr/bin/env bash
# =============================================================================
# setup-mpv-hdr.sh
# Installs mpv and configures HDR passthrough via dmabuf-wayland.
# Sets mpv as the default video player for all common video formats.
#
# Supported OS families: fedora-atomic (rpm-ostree), arch (pacman),
#                        steamos (flatpak), debian (apt), any (flatpak)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

MPV_CONF_DIR="${HOME}/.config/mpv"
MPV_CONF="${MPV_CONF_DIR}/mpv.conf"
INPUT_CONF="${MPV_CONF_DIR}/input.conf"

# On SteamOS + Flatpak mpv, config lives in the Flatpak data dir
MPV_FLATPAK_CONF="${HOME}/.var/app/io.mpv.mpv/config/mpv"

banner "MPV — HDR Install & Configure"
echo   "  OS: ${OS_PRETTY} (${OS_FAMILY})"
echo   "  Installs mpv and configures HDR passthrough via dmabuf-wayland."
echo   "  Sets mpv as the default player for all video formats."
echo

# ── 1. Install mpv ────────────────────────────────────────────────────────────
header "Step 1: Installing mpv"

if command -v mpv &>/dev/null || \
   flatpak list --app 2>/dev/null | grep -q "io.mpv.mpv"; then
    success "mpv already installed."
else
    case "${OS_FAMILY}" in
        fedora-atomic)
            info "rpm-ostree install mpv — a reboot will be required."
            if dry_run_cmd rpm-ostree install --idempotent mpv; then
                success "mpv staged for install."
                check_reboot_pending
                echo -e "  ${YELLOW}Please reboot and re-run this script to complete configuration.${RESET}"
                exit 0
            else
                error "rpm-ostree install failed. Falling back to Flatpak."
                dry_run_cmd flatpak install --user --noninteractive flathub io.mpv.mpv
                MPV_CONF_DIR="${MPV_FLATPAK_CONF}"
            fi
            ;;
        arch)
            info "pacman -S mpv"
            dry_run_cmd sudo pacman -S --noconfirm --needed mpv
            success "mpv installed."
            ;;
        steamos)
            steamos_persist_warn
            info "Installing mpv as Flatpak (persists across SteamOS updates)."
            dry_run_cmd flatpak install --user --noninteractive flathub io.mpv.mpv
            MPV_CONF_DIR="${MPV_FLATPAK_CONF}"
            success "mpv installed as Flatpak."
            ;;
        debian)
            info "apt install mpv"
            dry_run_cmd sudo apt-get install -y mpv
            success "mpv installed."
            ;;
        *)
            info "Installing mpv as Flatpak (fallback for unknown OS)."
            ensure_flatpak
            dry_run_cmd flatpak install --user --noninteractive flathub io.mpv.mpv
            MPV_CONF_DIR="${MPV_FLATPAK_CONF}"
            success "mpv installed as Flatpak."
            ;;
    esac
fi

# Warn if native mpv version < 0.40 (required for native dmabuf-wayland HDR)
if command -v mpv &>/dev/null; then
    MPV_MINOR=$(mpv --version 2>/dev/null | grep -oP 'mpv 0\.\K[0-9]+' | head -1 || echo "99")
    if (( MPV_MINOR < 40 )); then
        warn "mpv appears to be < 0.40 — dmabuf-wayland HDR requires 0.40+."
    fi
fi

# ── 2. mpv.conf ───────────────────────────────────────────────────────────────
header "Step 2: Writing ~/.config/mpv/mpv.conf"
mkdir -p "${MPV_CONF_DIR}"

[[ -f "${MPV_CONF}" ]] && \
    cp "${MPV_CONF}" "${MPV_CONF}.bak.$(date +%Y%m%d_%H%M%S)" && \
    warn "Existing mpv.conf backed up."

cat > "${MPV_CONF}" << 'EOF'
# ── MPV config — HDR HTPC (Bazzite / Linux / Wayland) ─────────────────────────

# Native Wayland HDR passthrough path (mpv 0.40+)
# Passes HDR10 metadata straight to KWin → TV does its own tone mapping.
vo=dmabuf-wayland

# VA-API hardware decode via AMD GPU; falls back to software on errors
hwdec=auto-safe

# Pass HDR/colorspace metadata to the Wayland compositor (KWin)
# rather than tone-mapping internally — lets the TV/display do what it does best
target-colorspace-hint=yes

# High-quality upscaling for 1080p remuxes on a 4K screen
scale=ewa_lanczossharp
cscale=ewa_lanczossharp
dscale=mitchell
correct-downscaling=yes
sigmoid-upscaling=yes

# Audio — let PipeWire/HDMI handle the bitstream
volume=100
volume-max=100

# Subtitles
sub-auto=fuzzy
sub-font-size=42
sub-border-size=2
sub-color="#FFFFFFFF"
sub-border-color="#FF000000"

# HTPC quality-of-life
keep-open=yes
save-position-on-quit=yes
msg-level=all=warn
EOF
success "mpv.conf written."

# ── 3. input.conf ─────────────────────────────────────────────────────────────
header "Step 3: Writing ~/.config/mpv/input.conf"
[[ -f "${INPUT_CONF}" ]] && \
    cp "${INPUT_CONF}" "${INPUT_CONF}.bak.$(date +%Y%m%d_%H%M%S)" && \
    warn "Existing input.conf backed up."

cat > "${INPUT_CONF}" << 'EOF'
# HTPC keybinds
a           cycle audio
A           cycle audio down
s           cycle sub
S           cycle sub down
i           script-binding stats/display-stats-toggle
RIGHT       seek  5
LEFT        seek -5
UP          seek  30
DOWN        seek -30
WHEEL_UP    add volume 2
WHEEL_DOWN  add volume -2
EOF
success "input.conf written."

# ── 4. Set as default video player ────────────────────────────────────────────
header "Step 4: Setting mpv as default video player"

VIDEO_MIMES=(
    video/mp4 video/x-matroska video/x-msvideo video/mpeg
    video/ogg video/webm video/quicktime video/x-ms-wmv
    video/x-flv video/3gpp video/mp2t video/dvd video/x-theora
)

# Detect correct .desktop name
if flatpak list --app 2>/dev/null | grep -q "io.mpv.mpv"; then
    DESKTOP_ENTRY="io.mpv.mpv.desktop"
else
    DESKTOP_ENTRY="mpv.desktop"
fi
info "Using desktop entry: ${DESKTOP_ENTRY}"

MIMEAPPS="${HOME}/.config/mimeapps.list"
[[ ! -f "${MIMEAPPS}" ]] && echo "[Default Applications]" > "${MIMEAPPS}"

for mime in "${VIDEO_MIMES[@]}"; do
    xdg-mime default "${DESKTOP_ENTRY}" "${mime}" 2>/dev/null || true
    if grep -q "^${mime}=" "${MIMEAPPS}" 2>/dev/null; then
        sed -i "s|^${mime}=.*|${mime}=${DESKTOP_ENTRY}|" "${MIMEAPPS}"
    else
        sed -i "/^\[Default Applications\]/a ${mime}=${DESKTOP_ENTRY}" "${MIMEAPPS}"
    fi
    success "  Default set: ${mime}"
done

# ── 5. Done ───────────────────────────────────────────────────────────────────
header "Done"
success "mpv is configured for HDR passthrough."
echo
echo -e "  ${BOLD}Key settings:${RESET}"
echo    "    vo=dmabuf-wayland          Native Wayland HDR path"
echo    "    hwdec=auto-safe            VA-API AMD hardware decode"
echo    "    target-colorspace-hint=yes Pass HDR metadata to KWin/TV"
echo    "    scale=ewa_lanczossharp     Quality upscaling for 1080p→4K"
echo
echo -e "  ${BOLD}During playback, press 'i' to show the stats overlay.${RESET}"
echo    "  Confirm 'VO: dmabuf-wayland' is shown to verify HDR is active."
echo
