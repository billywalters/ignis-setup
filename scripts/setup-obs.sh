#!/usr/bin/env bash
# =============================================================================
# setup-obs.sh
# Installs OBS Studio (Flatpak), grants webcam/screen/home permissions,
# and writes a pre-configured profile with the right encoder for your GPU
# and the output resolution you choose.
#
# Usage:
#   bash setup-obs.sh                         # interactive prompts
#   bash setup-obs.sh --resolution 1080p      # non-interactive
#   bash setup-obs.sh --resolution 1440p --gpu amd
#   bash setup-obs.sh --resolution 4k --gpu nvidia
#
# Resolutions: 720p | 1080p | 1440p | 4k
# GPUs:        amd | nvidia | intel | cpu   (cpu = software x264)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/_common.sh" ]] && source "${SCRIPT_DIR}/_common.sh" \
  || [[ -f "${SCRIPT_DIR}/../scripts/_common.sh" ]] && source "${SCRIPT_DIR}/../scripts/_common.sh" \
  || { echo "ERROR: _common.sh not found"; exit 1; }

OBS_FLATPAK="com.obsproject.Studio"
# Flatpak OBS config lives here
OBS_CONFIG_DIR="${HOME}/.var/app/${OBS_FLATPAK}/config/obs-studio"
OBS_PROFILE_DIR="${OBS_CONFIG_DIR}/basic/profiles/Ignis"

# ── Parse arguments ───────────────────────────────────────────────────────────
RESOLUTION=""
GPU_VENDOR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --resolution) RESOLUTION="$2"; shift 2 ;;
        --gpu)        GPU_VENDOR="$2";  shift 2 ;;
        *) shift ;;
    esac
done

banner "OBS Studio — Install & Configure"
echo   "  Installs OBS Studio, sets up Flatpak permissions for webcam/screen share,"
echo   "  and writes a pre-configured streaming profile for your GPU and resolution."
echo

# ── 1. Flatpak preflight ──────────────────────────────────────────────────────
ensure_flatpak

# ── 2. Detect GPU if not provided ────────────────────────────────────────────
header "Step 1: Detecting GPU vendor"
if [[ -z "${GPU_VENDOR}" ]]; then
    if lspci 2>/dev/null | grep -qi "radeon\|amd\|advanced micro"; then
        GPU_VENDOR="amd"
    elif lspci 2>/dev/null | grep -qi "nvidia\|geforce"; then
        GPU_VENDOR="nvidia"
    elif lspci 2>/dev/null | grep -qi "intel.*graphics\|iris\|uhd\|arc"; then
        GPU_VENDOR="intel"
    else
        GPU_VENDOR="cpu"
        warn "Could not detect GPU vendor — will use CPU (x264) encoder."
    fi
fi
success "GPU vendor: ${GPU_VENDOR}"

# Map GPU to OBS encoder string
case "${GPU_VENDOR}" in
    amd)    ENCODER="amd_amf_h264" ;  ENCODER_LABEL="AMD AMF H.264" ;;
    nvidia) ENCODER="jim_nvenc" ;     ENCODER_LABEL="NVIDIA NVENC H.264" ;;
    intel)  ENCODER="obs_qsv11" ;     ENCODER_LABEL="Intel Quick Sync H.264" ;;
    *)      ENCODER="obs_x264" ;      ENCODER_LABEL="CPU x264 (software)" ;;
esac
info "Will configure encoder: ${ENCODER_LABEL}"

# ── 3. Interactive resolution prompt ─────────────────────────────────────────
header "Step 2: Output resolution"
if [[ -z "${RESOLUTION}" ]]; then
    echo   "  What resolution do you want to stream/record at?"
    echo   "    1) 720p  (1280×720)  — Light on GPU, good for most internet connections"
    echo   "    2) 1080p (1920×1080) — Standard, recommended for most users"
    echo   "    3) 1440p (2560×1440) — High quality, needs good upload speed"
    echo   "    4) 4K    (3840×2160) — Maximum quality, needs very fast upload"
    echo
    read -rp "  Enter 1-4 [default: 2]: " RES_CHOICE
    case "${RES_CHOICE:-2}" in
        1) RESOLUTION="720p"  ;;
        2) RESOLUTION="1080p" ;;
        3) RESOLUTION="1440p" ;;
        4) RESOLUTION="4k"    ;;
        *) RESOLUTION="1080p" ; warn "Invalid choice, defaulting to 1080p." ;;
    esac
fi

# Map resolution to values
case "${RESOLUTION}" in
    720p)  OUT_W=1280;  OUT_H=720;  BITRATE=4000;  REC_BITRATE=15000 ;;
    1080p) OUT_W=1920;  OUT_H=1080; BITRATE=6000;  REC_BITRATE=30000 ;;
    1440p) OUT_W=2560;  OUT_H=1440; BITRATE=9000;  REC_BITRATE=50000 ;;
    4k)    OUT_W=3840;  OUT_H=2160; BITRATE=15000; REC_BITRATE=80000 ;;
    *)     OUT_W=1920;  OUT_H=1080; BITRATE=6000;  REC_BITRATE=30000
           warn "Unknown resolution '${RESOLUTION}', defaulting to 1080p." ;;
esac

success "Output: ${OUT_W}×${OUT_H} at ${BITRATE} kbps streaming / ${REC_BITRATE} kbps recording"

# ── 4. Install OBS ────────────────────────────────────────────────────────────
header "Step 3: Installing OBS Studio"
if flatpak list --app --user 2>/dev/null | grep -q "${OBS_FLATPAK}"; then
    success "OBS Studio already installed."
else
    info "Installing OBS Studio from Flathub..."
    dry_run_cmd flatpak install --user --noninteractive flathub "${OBS_FLATPAK}"
    success "OBS Studio installed."
fi

# ── 5. Flatpak permissions ────────────────────────────────────────────────────
header "Step 4: Configuring Flatpak permissions"

# All devices: webcam + capture cards
flatpak override --user --device=all "${OBS_FLATPAK}"
success "  Granted: all devices (webcam, capture cards)"

# Home filesystem: for recordings and scene sources
flatpak override --user --filesystem=home "${OBS_FLATPAK}"
success "  Granted: home directory (recordings, media sources)"

# Wayland socket (for Wayland window capture)
flatpak override --user --socket=wayland "${OBS_FLATPAK}"
success "  Granted: Wayland socket (screen capture)"

# PipeWire / XDG portals for audio and screen share
flatpak override --user --filesystem=xdg-run/pipewire-0 "${OBS_FLATPAK}" 2>/dev/null || true
success "  Granted: PipeWire socket (audio capture)"

# ── 6. Write OBS profile ──────────────────────────────────────────────────────
header "Step 5: Writing OBS profile — '${RESOLUTION} / ${ENCODER_LABEL}'"

mkdir -p "${OBS_PROFILE_DIR}"

# Determine FPS — 4K at 60fps is demanding; offer 30 for 4K
FPS_NUM=60
FPS_DEN=1
if [[ "${RESOLUTION}" == "4k" ]]; then
    FPS_NUM=30
    warn "4K recording defaults to 30fps to prevent dropped frames. Change in OBS Settings → Video."
fi

cat > "${OBS_PROFILE_DIR}/basic.ini" << INI
[General]
Name=Ignis ${RESOLUTION}

[Video]
BaseCX=${OUT_W}
BaseCY=${OUT_H}
OutputCX=${OUT_W}
OutputCY=${OUT_H}
FPSType=0
FPSCommon=60
FPSInt=${FPS_NUM}
FPSNum=${FPS_NUM}
FPSDen=${FPS_DEN}
ScaleType=bicubic
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial

[Output]
Mode=Advanced
FilenameFormatting=%CCYY-%MM-%DD %hh-%mm-%ss
OverwriteIfExists=false
RecRB=false
RecRBTime=20
RecRBSize=512

[AdvOut]
; Streaming
TrackIndex=1
RecType=Standard
RecTrackIndex=1
FfmpegOutputToFile=false
FFOutputToFile=false
Encoder=${ENCODER}
RescaleRes=${OUT_W}x${OUT_H}
RescaleFilter=bicubic
TrackIndex=1
VodTrackIndex=2
ApplyServiceSettings=true

; Recording — higher bitrate, MKV (remux to MP4 later)
RecFormat=mkv
RecEncoder=${ENCODER}
RecFilePath=${HOME}/Videos/OBS
RecQuality=Small
RecRescaleRes=${OUT_W}x${OUT_H}

; Audio tracks
Track1Name=Main Audio
Track2Name=Desktop Audio
Track3Name=Mic Only

[SimpleOutput]
FilePath=${HOME}/Videos/OBS
FileFormat=%CCYY-%MM-%DD %hh-%mm-%ss
RecQuality=Small
RecEncoder=x264
RecAudioEncoder=aac
RecFormat=mkv
UseAdvanced=false
EnforceBitrate=true
NBuffFrames=0
VBitrate=${BITRATE}
ABitrate=160
StreamEncoder=${ENCODER}
RecRescale=false
RecRescaleRes=${OUT_W}x${OUT_H}

[Stream1]
type=rtmp_common
key=
server=

[Hotkeys]
OBSBasic.StartRecording=
OBSBasic.StopRecording=
OBSBasic.StartStreaming=
OBSBasic.StopStreaming=
OBSBasic.StartVirtualCam=
OBSBasic.StopVirtualCam=

[Audio]
SampleRate=48000
Channels=2
MonitoringDeviceId=default
INI

# Write streaming output settings (separate ini used by OBS for stream encoder)
cat > "${OBS_PROFILE_DIR}/streamEncoder.json" << JSON
{
  "id": "${ENCODER}",
  "settings": {
    "bitrate": ${BITRATE},
    "rate_control": "CBR",
    "keyint_sec": 2,
    "profile": "high",
    "preset": "$(if [[ "$GPU_VENDOR" == "nvidia" ]]; then echo "P5: Slow (Good Quality)"; elif [[ "$GPU_VENDOR" == "amd" ]]; then echo "Quality"; else echo "Quality"; fi)"
  }
}
JSON

cat > "${OBS_PROFILE_DIR}/recordEncoder.json" << JSON
{
  "id": "${ENCODER}",
  "settings": {
    "bitrate": ${REC_BITRATE},
    "rate_control": "CQP",
    "cqp": 18,
    "profile": "high"
  }
}
JSON

success "OBS profile written to: ${OBS_PROFILE_DIR}"

# Create the default recordings folder
mkdir -p "${HOME}/Videos/OBS"
success "Recordings folder created: ${HOME}/Videos/OBS"

# ── 7. Global OBS config (set active profile) ─────────────────────────────────
GLOBAL_INI="${OBS_CONFIG_DIR}/global.ini"
mkdir -p "${OBS_CONFIG_DIR}"

if [[ -f "${GLOBAL_INI}" ]]; then
    # Update or add the profile setting
    if grep -q "^CurrentProfile=" "${GLOBAL_INI}"; then
        sed -i "s|^CurrentProfile=.*|CurrentProfile=Ignis|" "${GLOBAL_INI}"
    else
        echo "CurrentProfile=Ignis" >> "${GLOBAL_INI}"
    fi
else
    cat > "${GLOBAL_INI}" << GLOBALINI
[Basic]
CurrentProfile=Ignis
CurrentSceneCollection=Ignis
GLOBALINI
fi
success "Active OBS profile set to 'Ignis'"

# ── 8. Done ───────────────────────────────────────────────────────────────────
banner "OBS Studio Setup Complete"
echo
success "OBS is installed and configured."
echo
echo -e "  ${BOLD}Profile:${RESET}    Ignis ${RESOLUTION}"
echo -e "  ${BOLD}Encoder:${RESET}    ${ENCODER_LABEL}"
echo -e "  ${BOLD}Output:${RESET}     ${OUT_W}×${OUT_H} at ${FPS_NUM}fps"
echo -e "  ${BOLD}Bitrate:${RESET}    ${BITRATE} kbps streaming / ${REC_BITRATE} kbps recording"
echo -e "  ${BOLD}Recordings:${RESET} ${HOME}/Videos/OBS"
echo
echo -e "  ${YELLOW}First launch tip:${RESET}"
echo    "  OBS will show an Auto-Configuration Wizard — you can Skip it or run it."
echo    "  Your 'Ignis' profile is already pre-configured and will be active."
echo
echo -e "  ${YELLOW}To add your stream key:${RESET}"
echo    "  OBS → Settings → Stream → choose Twitch/YouTube/Kick → paste key"
echo
if [[ "${ENCODER}" == "obs_x264" ]]; then
    warn "x264 (CPU encoding) is in use. Your CPU will handle encoding during streams."
    warn "This works well on modern CPUs but adds load. If you install a GPU later,"
    warn "re-run this script with --gpu amd/nvidia/intel."
fi
echo
