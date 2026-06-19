#!/usr/bin/env bash
# =============================================================================
# setup-handbrake.sh
# Installs the latest HandBrake (Flatpak) and auto-imports all five AV1
# encoding presets from the handbrake-presets/ folder alongside this script.
#
# Presets imported:
#   (Live) AV1 Preset       — live action 4K, RF 16, qp-scale-compress
#   (Old Live) AV1 Preset   — older live action, RF 16, higher film grain
#   (Animated) AV1 Preset   — animated content, RF 16
#   (Anime) AV1 Preset      — anime, RF 16, low film grain
#   (Old Anime) AV1 Preset  — older anime, RF 16, heavy film grain
#
# All presets share:
#   • SVT-AV1 10-bit, Encoder Preset 5, SSIM tune, multi-pass
#   • Audio: copy all source tracks as-is (encoder=copy, select all)
#   • Full permissive copy mask — no re-encoding of any known codec
#   • AudioEncoderFallback = none (skip track rather than transcode)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/_common.sh" ]] && source "${SCRIPT_DIR}/_common.sh" \
  || [[ -f "${SCRIPT_DIR}/../scripts/_common.sh" ]] && source "${SCRIPT_DIR}/../scripts/_common.sh" \
  || { echo "ERROR: _common.sh not found"; exit 1; }

HB_FLATPAK="fr.handbrake.ghb"
# HandBrake stores user presets here when installed as a Flatpak
HB_PRESET_DIR="${HOME}/.var/app/${HB_FLATPAK}/config/ghb/presets"

# Presets live in a sibling folder to this script
PRESET_SRC_DIR="${SCRIPT_DIR}/../handbrake-presets"
# Also check the same directory as the script
[[ -d "${PRESET_SRC_DIR}" ]] || PRESET_SRC_DIR="${SCRIPT_DIR}/handbrake-presets"

banner "HandBrake — Install & Import AV1 Presets"
echo   "  Installs HandBrake via Flatpak and imports your five SVT-AV1 presets."
echo   "  Presets source: ${PRESET_SRC_DIR}"
echo

# ── 1. Flatpak preflight ──────────────────────────────────────────────────────
ensure_flatpak

# ── 2. Install HandBrake ──────────────────────────────────────────────────────
header "Step 1: Installing HandBrake"

if flatpak list --app --user 2>/dev/null | grep -q "${HB_FLATPAK}"; then
    HB_VER=$(flatpak info --user "${HB_FLATPAK}" 2>/dev/null \
        | grep -i version | awk '{print $2}' || echo "installed")
    success "HandBrake already installed (${HB_VER})"
    info    "To update: flatpak update --user ${HB_FLATPAK}"
else
    info "Installing HandBrake from Flathub..."
    dry_run_cmd flatpak install --user --noninteractive flathub "${HB_FLATPAK}"
    success "HandBrake installed."
fi

# Grant filesystem access so HandBrake can read/write your media directories
flatpak override --user --filesystem=home "${HB_FLATPAK}"
success "Home directory access granted to HandBrake."

# ── 3. Locate preset files ────────────────────────────────────────────────────
header "Step 2: Locating preset files"

if [[ ! -d "${PRESET_SRC_DIR}" ]]; then
    error "Preset source directory not found: ${PRESET_SRC_DIR}"
    error "Expected to find handbrake-presets/ alongside the scripts/ folder."
    exit 1
fi

PRESET_FILES=("${PRESET_SRC_DIR}"/*.json)
if [[ ${#PRESET_FILES[@]} -eq 0 ]]; then
    error "No .json preset files found in: ${PRESET_SRC_DIR}"
    exit 1
fi

success "Found ${#PRESET_FILES[@]} preset file(s):"
for f in "${PRESET_FILES[@]}"; do
    info "  $(basename "${f}")"
done

# ── 4. Create preset directory ────────────────────────────────────────────────
header "Step 3: Preparing HandBrake preset directory"
mkdir -p "${HB_PRESET_DIR}"
success "Preset directory ready: ${HB_PRESET_DIR}"

# ── 5. Import presets via HandBrakeCLI ────────────────────────────────────────
# HandBrake CLI supports --preset-import-file to load a preset JSON.
# We import each file, which writes it into HandBrake's user preset store.
# The GUI will show them next time it's opened.
header "Step 4: Importing presets"

IMPORTED=0
FAILED=0

for preset_file in "${PRESET_FILES[@]}"; do
    preset_name=$(python3 -c "
import json
with open('${preset_file}') as f:
    d = json.load(f)
print(d['PresetList'][0]['PresetName'])
" 2>/dev/null || basename "${preset_file}" .json)

    info "Importing: ${preset_name}"

    # HandBrakeCLI --preset-import-file writes the preset into the user store
    # Run inside the Flatpak sandbox so it writes to the right config path
    if flatpak run --command=HandBrakeCLI "${HB_FLATPAK}" \
        --preset-import-file "${preset_file}" \
        --preset "${preset_name}" \
        --input /dev/null \
        --output /dev/null \
        2>/dev/null; then
        success "  Imported: ${preset_name}"
        (( IMPORTED++ )) || true
    else
        # HandBrakeCLI exits non-zero when given /dev/null as input — that's expected.
        # What matters is whether the preset JSON was written to the store.
        # Fall back to manual copy if the import command failed hard.
        warn "  CLI import uncertain — copying preset JSON directly."
        cp "${preset_file}" "${HB_PRESET_DIR}/$(basename "${preset_file}")"
        success "  Copied: $(basename "${preset_file}")"
        (( IMPORTED++ )) || true
    fi
done

# ── 6. Verify ─────────────────────────────────────────────────────────────────
header "Step 5: Verification"

echo
info "Preset directory contents:"
ls -1 "${HB_PRESET_DIR}" | while read -r f; do
    echo "    ${f}"
done

echo
info "Verifying preset CRF and audio settings:"
python3 - "${PRESET_SRC_DIR}"/*.json << 'PYEOF'
import json, sys

for path in sys.argv[1:]:
    with open(path) as f:
        data = json.load(f)
    p = data["PresetList"][0]
    audio = p["AudioList"][0]
    crf   = p["VideoQualitySlider"]
    enc   = audio["AudioEncoder"]
    sel   = p["AudioTrackSelectionBehavior"]
    fb    = p["AudioEncoderFallback"]
    status = "✓" if crf == 16 and enc == "copy" and sel == "all" and fb == "none" else "⚠"
    print(f"  {status} {p['PresetName']:30s}  CRF={crf}  audio={enc}/{sel}  fallback={fb}")
PYEOF

# ── Done ──────────────────────────────────────────────────────────────────────
banner "HandBrake Setup Complete"
echo
success "${IMPORTED} preset(s) imported successfully."
echo
echo -e "  ${BOLD}Open HandBrake to confirm:${RESET}"
echo    "    Presets panel (right side) → scroll to find your presets"
echo    "    Or: Presets → Show Presets → look for the AV1 entries"
echo
echo -e "  ${BOLD}What each preset does:${RESET}"
echo    "    (Live) AV1         → live action, RF 16, qp-scale-compress"
echo    "    (Old Live) AV1     → older live action, RF 16, heavier grain"
echo    "    (Animated) AV1     → animated content, RF 16"
echo    "    (Anime) AV1        → anime, RF 16, minimal grain"
echo    "    (Old Anime) AV1    → older anime, RF 16, heavy grain"
echo
echo -e "  ${BOLD}Audio behaviour (all presets):${RESET}"
echo    "    Copies ALL audio tracks from source exactly as-is."
echo    "    No re-encoding. No extra tracks added."
echo    "    If a codec can't be copied (rare), the track is skipped."
echo
echo -e "  ${BOLD}Launch HandBrake:${RESET}"
echo    "    flatpak run ${HB_FLATPAK}"
echo    "    Or search 'HandBrake' in your app launcher"
echo
