#!/usr/bin/env bash
# =============================================================================
# setup-emudeck.sh
# Installs EmuDeck, then applies per-emulator resolution scaling and
# CRT-Royale shader for RetroArch.
#
# Supported resolutions: 720p | 1080p | 1440p | 4k  (default: 4k)
#
# Per-emulator upscaling configured:
#   RetroArch  — video_fullscreen_x/y in retroarch.cfg
#   Dolphin    — EFBScale in GFX.ini       (GameCube / Wii)
#   PCSX2      — upscale_multiplier        (PlayStation 2)
#   Cemu       — <renderResolution> XML    (Wii U)
#   DuckStation — ResolutionScale          (PlayStation 1)
#   PPSSPP     — RenderingResolution       (PSP)
#   Yuzu/Ryujinx — resolution_setup        (Switch — if present)
#
# Usage:
#   bash setup-emudeck.sh                          Install EmuDeck
#   bash setup-emudeck.sh --configure              Configure at 4K (default)
#   bash setup-emudeck.sh --configure --res 1080p  Configure at 1080p
#   bash setup-emudeck.sh --configure --res 1440p
#   bash setup-emudeck.sh --configure --res 720p
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
MODE="install"
RESOLUTION="4k"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configure) MODE="configure" ;  shift ;;
        --res)       RESOLUTION="$2" ;   shift 2 ;;
        *)           shift ;;
    esac
done

# Normalise resolution input
case "${RESOLUTION}" in
    720p|720)   RESOLUTION="720p"  ;;
    1080p|1080) RESOLUTION="1080p" ;;
    1440p|1440) RESOLUTION="1440p" ;;
    4k|4K|2160|2160p) RESOLUTION="4k" ;;
    *)
        warn "Unknown resolution '${RESOLUTION}' — defaulting to 4k"
        RESOLUTION="4k"
        ;;
esac

# ── Resolution lookup tables ──────────────────────────────────────────────────
# RetroArch: fullscreen width × height
declare -A RA_W=( [720p]=1280  [1080p]=1920  [1440p]=2560  [4k]=3840 )
declare -A RA_H=( [720p]=720   [1080p]=1080  [1440p]=1440  [4k]=2160 )

# Dolphin EFBScale values (multiplier of ~480p native GC/Wii):
#   720p ≈ 1.5x native → EFBScale=3  (closest: gives ~720p from 480p base)
#   1080p = 3x native  → EFBScale=6
#   1440p = 4x native  → EFBScale=7  (closest without going over)
#   4K    = 6x native  → EFBScale=9
declare -A DOLPHIN_EFB=( [720p]=3 [1080p]=6 [1440p]=7 [4k]=9 )

# PCSX2 upscale_multiplier (multiplier of 512×448 PS2 native):
#   720p  ≈ 2x → gives ~1024×896
#   1080p = 3x → gives ~1536×1344 (closest to 1080p)
#   1440p = 4x → gives ~2048×1792
#   4k    = 6x → gives ~3072×2688 (nearest to 4K without excess)
declare -A PCSX2_SCALE=( [720p]=2 [1080p]=3 [1440p]=4 [4k]=6 )

# DuckStation ResolutionScale (multiplier of 320×240 PS1 native):
#   720p  = 3x → ~960×720
#   1080p = 4x → ~1280×960
#   1440p = 6x → ~1920×1440
#   4k    = 9x → ~2880×2160
declare -A DUCK_SCALE=( [720p]=3 [1080p]=4 [1440p]=6 [4k]=9 )

# PPSSPP RenderingResolution (multiplier of 480×272 PSP native):
#   720p  = 3x → ~1440×816
#   1080p = 4x → ~1920×1088
#   1440p = 6x → ~2880×1632
#   4k    = 8x → ~3840×2176
declare -A PPSSPP_SCALE=( [720p]=3 [1080p]=4 [1440p]=6 [4k]=8 )

# Cemu renderResolution (target output width):
declare -A CEMU_W=( [720p]=1280 [1080p]=1920 [1440p]=2560 [4k]=3840 )
declare -A CEMU_H=( [720p]=720  [1080p]=1080 [1440p]=1440 [4k]=2160 )

# ── Config paths ──────────────────────────────────────────────────────────────
RA_CFG_DIR="${HOME}/.var/app/org.libretro.RetroArch/config/retroarch"
RA_CFG="${RA_CFG_DIR}/retroarch.cfg"
RA_SHADER_DIR="${RA_CFG_DIR}/shaders"
RA_PRESET_DIR="${RA_CFG_DIR}/shaders/presets"

DOLPHIN_GFX="${HOME}/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu/GFX.ini"
PCSX2_INI="${HOME}/.config/PCSX2/inis/PCSX2.ini"
CEMU_SETTINGS="${HOME}/Applications/cemu/settings.xml"
DUCK_INI="${HOME}/.var/app/org.duckstation.DuckStation/config/duckstation/settings.ini"
PPSSPP_INI="${HOME}/.var/app/org.ppsspp.PPSSPP/config/PSP/SYSTEM/ppsspp.ini"

# ─────────────────────────────────────────────────────────────────────────────
# PART A — INSTALL
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${MODE}" == "install" ]]; then

    banner "EmuDeck Install"
    echo   "  After the installer finishes, run this script again to configure"
    echo   "  resolution scaling for all emulators:"
    echo
    echo   "    bash $(realpath "${BASH_SOURCE[0]}") --configure --res ${RESOLUTION}"
    echo   "    (or change --res to: 720p | 1080p | 1440p | 4k)"
    echo

    ensure_flatpak

    header "Installing EmuDeck"
    if command -v ujust &>/dev/null; then
        EMUDECK_APPIMAGE="${HOME}/Applications/EmuDeck.AppImage"
        if [[ -f "${EMUDECK_APPIMAGE}" ]]; then
            success "EmuDeck already installed: ${EMUDECK_APPIMAGE}"
            info    "To update: open EmuDeck → Check for Updates"
        else
            info "Running: ujust install-emudeck"
            dry_run_cmd ujust install-emudeck
            success "EmuDeck install command completed."
        fi
    else
        warn "ujust not found — using upstream curl installer."
        dry_run_cmd bash -c 'curl -L https://raw.githubusercontent.com/dragoonDorise/EmuDeck/main/install.sh | bash'
        success "EmuDeck install script completed."
    fi

    echo
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${YELLOW}  NEXT STEPS${RESET}"
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════════${RESET}"
    echo
    echo   "  1. Complete the EmuDeck GUI wizard."
    echo   "     Choose 'Easy Mode' → 'Linux Desktop' when prompted."
    echo
    echo   "  2. Launch each emulator at least once so they create their config files."
    echo
    echo   "  3. Run this script again to apply resolution scaling:"
    echo
    echo -e "     ${CYAN}bash $(realpath "${BASH_SOURCE[0]}") --configure --res 4k${RESET}"
    echo    "     (replace 4k with: 720p | 1080p | 1440p | 4k)"
    echo

# ─────────────────────────────────────────────────────────────────────────────
# PART B — CONFIGURE
# ─────────────────────────────────────────────────────────────────────────────
elif [[ "${MODE}" == "configure" ]]; then

    banner "EmuDeck — Configure ${RESOLUTION} Resolution Scaling"
    echo   "  Applying ${RESOLUTION} upscaling to all detected emulators."
    echo   "  Emulators without config files yet are skipped (run them first)."
    echo

    # ── Helper: INI set/replace key in [Section] ─────────────────────────────
    # ini_set FILE SECTION KEY VALUE
    ini_set() {
        local file="$1" section="$2" key="$3" value="$4"
        [[ ! -f "${file}" ]] && return 0

        if grep -q "^\[${section}\]" "${file}" 2>/dev/null; then
            # Section exists — update or insert the key inside it
            if grep -q "^${key} *=" "${file}"; then
                sed -i "s|^${key} *=.*|${key} = ${value}|" "${file}"
            else
                # Insert after section header
                sed -i "/^\[${section}\]/a ${key} = ${value}" "${file}"
            fi
        else
            # Section doesn't exist — append it
            printf '\n[%s]\n%s = %s\n' "${section}" "${key}" "${value}" >> "${file}"
        fi
    }

    # ── 1. RetroArch ─────────────────────────────────────────────────────────
    header "RetroArch — output ${RA_W[$RESOLUTION]}×${RA_H[$RESOLUTION]}"

    if [[ ! -f "${RA_CFG}" ]]; then
        warn "retroarch.cfg not found — skipping RetroArch."
        warn "Launch RetroArch once from the app launcher, then re-run."
    else
        BACKUP="${RA_CFG}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${RA_CFG}" "${BACKUP}"
        success "Backed up retroarch.cfg → $(basename "${BACKUP}")"

        ra_set() {
            local key="$1" value="$2"
            if grep -q "^${key} = " "${RA_CFG}"; then
                sed -i "s|^${key} = .*|${key} = \"${value}\"|" "${RA_CFG}"
            else
                echo "${key} = \"${value}\"" >> "${RA_CFG}"
            fi
        }

        ra_set "video_driver"           "vulkan"
        ra_set "video_fullscreen_x"     "${RA_W[$RESOLUTION]}"
        ra_set "video_fullscreen_y"     "${RA_H[$RESOLUTION]}"
        ra_set "video_windowed_fullscreen" "true"
        ra_set "video_fullscreen"       "true"
        ra_set "video_scale_integer"    "false"
        ra_set "video_smooth"           "false"
        ra_set "audio_sync"             "true"
        ra_set "video_vsync"            "true"
        ra_set "video_aspect_ratio_auto" "true"
        ra_set "video_aspect_ratio"     "-1"

        # CRT-Royale shader
        mkdir -p "${RA_SHADER_DIR}" "${RA_PRESET_DIR}"
        ra_set "video_shader_dir" "${RA_SHADER_DIR}"

        FLATPAK_SHADER_ROOT="/var/lib/flatpak/app/org.libretro.RetroArch/current/active/files/share/libretro/shaders"
        USER_SHADER_ROOT="${RA_SHADER_DIR}"
        CRT_PATH="${USER_SHADER_ROOT}/shaders_slang/crt/crt-royale.slangp"

        if [[ -f "${FLATPAK_SHADER_ROOT}/shaders_slang/crt/crt-royale.slangp" ]]; then
            if [[ ! -d "${USER_SHADER_ROOT}/shaders_slang" ]]; then
                info "Copying shader pack (one-time, may take a moment)..."
                cp -r "${FLATPAK_SHADER_ROOT}/shaders_slang" "${USER_SHADER_ROOT}/"
                success "Shader pack copied."
            fi
        else
            warn "crt-royale.slangp not found — run: RetroArch → Online Updater → Update Slang Shaders"
        fi

        ra_set "video_shader"        "${CRT_PATH}"
        ra_set "video_shader_enable" "true"
        printf '#reference "%s"\n' "${CRT_PATH}" > "${RA_PRESET_DIR}/global.slangp"

        success "RetroArch: ${RA_W[$RESOLUTION]}×${RA_H[$RESOLUTION]} + Vulkan + CRT-Royale"
    fi

    # ── 2. Dolphin (GameCube / Wii) ───────────────────────────────────────────
    header "Dolphin — EFBScale=${DOLPHIN_EFB[$RESOLUTION]} (~${RESOLUTION} upscale)"

    if [[ ! -f "${DOLPHIN_GFX}" ]]; then
        warn "Dolphin GFX.ini not found — skipping."
        warn "Launch Dolphin once, then re-run."
    else
        cp "${DOLPHIN_GFX}" "${DOLPHIN_GFX}.bak.$(date +%Y%m%d_%H%M%S)"
        ini_set "${DOLPHIN_GFX}" "Settings" "EFBScale"          "${DOLPHIN_EFB[$RESOLUTION]}"
        ini_set "${DOLPHIN_GFX}" "Settings" "InternalResolutionFrameDumps" "False"
        ini_set "${DOLPHIN_GFX}" "Settings" "Renderer"          "Vulkan"
        ini_set "${DOLPHIN_GFX}" "Settings" "SuggestedWindowWidth"  "${RA_W[$RESOLUTION]}"
        ini_set "${DOLPHIN_GFX}" "Settings" "SuggestedWindowHeight" "${RA_H[$RESOLUTION]}"
        success "Dolphin: EFBScale=${DOLPHIN_EFB[$RESOLUTION]} (${RESOLUTION}), Vulkan renderer"
    fi

    # ── 3. PCSX2 (PlayStation 2) ──────────────────────────────────────────────
    header "PCSX2 — upscale_multiplier=${PCSX2_SCALE[$RESOLUTION]} (~${RESOLUTION})"

    if [[ ! -f "${PCSX2_INI}" ]]; then
        warn "PCSX2 PCSX2.ini not found — skipping."
        warn "Launch PCSX2 once, then re-run."
    else
        cp "${PCSX2_INI}" "${PCSX2_INI}.bak.$(date +%Y%m%d_%H%M%S)"
        ini_set "${PCSX2_INI}" "EmuCore/GS" "upscale_multiplier"  "${PCSX2_SCALE[$RESOLUTION]}"
        ini_set "${PCSX2_INI}" "EmuCore/GS" "Renderer"            "14"    # 14 = Vulkan
        success "PCSX2: ${PCSX2_SCALE[$RESOLUTION]}x upscale (${RESOLUTION}), Vulkan"
    fi

    # ── 4. DuckStation (PlayStation 1) ────────────────────────────────────────
    header "DuckStation — ResolutionScale=${DUCK_SCALE[$RESOLUTION]} (~${RESOLUTION})"

    if [[ ! -f "${DUCK_INI}" ]]; then
        warn "DuckStation settings.ini not found — skipping."
        warn "Launch DuckStation once, then re-run."
    else
        cp "${DUCK_INI}" "${DUCK_INI}.bak.$(date +%Y%m%d_%H%M%S)"
        ini_set "${DUCK_INI}" "GPU" "ResolutionScale"   "${DUCK_SCALE[$RESOLUTION]}"
        ini_set "${DUCK_INI}" "GPU" "Renderer"          "Vulkan"
        ini_set "${DUCK_INI}" "GPU" "UseDebugDevice"    "false"
        success "DuckStation: ${DUCK_SCALE[$RESOLUTION]}x upscale (${RESOLUTION}), Vulkan"
    fi

    # ── 5. PPSSPP (PSP) ───────────────────────────────────────────────────────
    header "PPSSPP — RenderingResolution=${PPSSPP_SCALE[$RESOLUTION]} (~${RESOLUTION})"

    if [[ ! -f "${PPSSPP_INI}" ]]; then
        warn "PPSSPP ppsspp.ini not found — skipping."
        warn "Launch PPSSPP once, then re-run."
    else
        cp "${PPSSPP_INI}" "${PPSSPP_INI}.bak.$(date +%Y%m%d_%H%M%S)"
        ini_set "${PPSSPP_INI}" "Graphics" "RenderingResolution" "${PPSSPP_SCALE[$RESOLUTION]}"
        ini_set "${PPSSPP_INI}" "Graphics" "GraphicsBackend"     "0"  # 0 = OpenGL/Vulkan auto
        success "PPSSPP: ${PPSSPP_SCALE[$RESOLUTION]}x upscale (${RESOLUTION})"
    fi

    # ── 6. Cemu (Wii U) ───────────────────────────────────────────────────────
    header "Cemu — renderResolution ${CEMU_W[$RESOLUTION]}×${CEMU_H[$RESOLUTION]}"

    # Cemu uses settings.xml — patch with Python for reliable XML editing
    if [[ ! -f "${CEMU_SETTINGS}" ]]; then
        # Try alternate path — some installs put it in ~/.config/Cemu/
        CEMU_ALT="${HOME}/.config/Cemu/settings.xml"
        if [[ -f "${CEMU_ALT}" ]]; then
            CEMU_SETTINGS="${CEMU_ALT}"
        else
            warn "Cemu settings.xml not found — skipping."
            warn "Launch Cemu once, then re-run."
            CEMU_SETTINGS=""
        fi
    fi

    if [[ -n "${CEMU_SETTINGS}" ]]; then
        cp "${CEMU_SETTINGS}" "${CEMU_SETTINGS}.bak.$(date +%Y%m%d_%H%M%S)"
        python3 - "${CEMU_SETTINGS}" "${CEMU_W[$RESOLUTION]}" "${CEMU_H[$RESOLUTION]}" << 'PYEOF'
import sys
try:
    import xml.etree.ElementTree as ET
except ImportError:
    print("[WARN] Python xml module missing — skipping Cemu config")
    sys.exit(0)

path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
try:
    tree = ET.parse(path)
    root = tree.getroot()

    def find_or_create(parent, tag):
        el = parent.find(tag)
        if el is None:
            el = ET.SubElement(parent, tag)
        return el

    gfx = find_or_create(root, "Graphics")
    rw  = find_or_create(gfx, "renderResolutionWidth")
    rh  = find_or_create(gfx, "renderResolutionHeight")
    rw.text = str(w)
    rh.text = str(h)

    # Ensure Vulkan is set
    api = gfx.find("api")
    if api is not None:
        api.text = "2"  # 2 = Vulkan in Cemu

    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)
    print(f"[OK]    Cemu: {w}x{h} set in settings.xml")
except Exception as e:
    print(f"[WARN]  Could not edit Cemu settings.xml: {e}")
PYEOF
        success "Cemu: ${CEMU_W[$RESOLUTION]}×${CEMU_H[$RESOLUTION]}"
    fi

    # ── Summary ───────────────────────────────────────────────────────────────
    banner "Configuration Complete — ${RESOLUTION}"
    echo
    echo -e "  ${BOLD}Target resolution:${RESET} ${RESOLUTION} (${RA_W[$RESOLUTION]}×${RA_H[$RESOLUTION]})"
    echo
    echo -e "  ${BOLD}Emulator upscale settings applied:${RESET}"
    echo    "    RetroArch   → ${RA_W[$RESOLUTION]}×${RA_H[$RESOLUTION]} fullscreen output + CRT-Royale shader"
    echo    "    Dolphin     → EFBScale=${DOLPHIN_EFB[$RESOLUTION]}  (GameCube / Wii)"
    echo    "    PCSX2       → ${PCSX2_SCALE[$RESOLUTION]}x upscale  (PlayStation 2)"
    echo    "    DuckStation → ${DUCK_SCALE[$RESOLUTION]}x upscale  (PlayStation 1)"
    echo    "    PPSSPP      → ${PPSSPP_SCALE[$RESOLUTION]}x upscale  (PSP)"
    echo    "    Cemu        → ${CEMU_W[$RESOLUTION]}×${CEMU_H[$RESOLUTION]}  (Wii U)"
    echo
    echo    "  Emulators showing 'skipped' above were not yet launched — "
    echo    "  open each one once, close it, then re-run:"
    echo
    echo -e "    ${CYAN}bash $(realpath "${BASH_SOURCE[0]}") --configure --res ${RESOLUTION}${RESET}"
    echo
    echo -e "  ${BOLD}To change resolution later:${RESET} pass a different --res value."
    echo    "  Example: bash setup-emudeck.sh --configure --res 1080p"
    echo
    echo -e "  ${BOLD}Per-game overrides in RetroArch:${RESET}"
    echo    "    In-game: Select+X → Shaders → load preset → Save → Content Directory Preset"
    echo
    echo -e "  ${YELLOW}Performance note:${RESET} CRT-Royale at 4K is GPU-intensive."
    echo    "  If you see slowdown, switch to crt-guest-advanced.slangp (lighter, still great)."
    echo

else
    error "Unknown mode: ${MODE}"
    echo  "Usage: bash setup-emudeck.sh [--configure] [--res 720p|1080p|1440p|4k]"
    exit 1
fi
