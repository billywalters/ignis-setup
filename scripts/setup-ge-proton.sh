#!/usr/bin/env bash
# =============================================================================
# setup-ge-proton.sh
# 1. Downloads the latest GE-Proton into Steam's compatibilitytools.d
# 2. Sets it as the GLOBAL default Proton in Steam's config.vdf
# 3. Applies the Bazzite steamdeck-flag fix so Steam respects the default
#
# Steam MUST be closed before running this script (the script enforces this).
# After it completes, restart Steam — GE-Proton will be your default.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# _common.sh may live one level up (bazzite-setup) or alongside this script
[[ -f "${SCRIPT_DIR}/_common.sh" ]]        && source "${SCRIPT_DIR}/_common.sh" \
|| [[ -f "${SCRIPT_DIR}/../scripts/_common.sh" ]] && source "${SCRIPT_DIR}/../scripts/_common.sh" \
|| { echo "ERROR: _common.sh not found"; exit 1; }

GITHUB_REPO="GloriousEggroll/proton-ge-custom"
TMP_DIR="$(mktemp -d)"; trap 'rm -rf "${TMP_DIR}"' EXIT

# Steam can live in two places depending on install method
STEAM_NATIVE="${HOME}/.steam/steam"
STEAM_FLATPAK="${HOME}/.var/app/com.valvesoftware.Steam/data/Steam"

# ── Locate Steam root ─────────────────────────────────────────────────────────
detect_steam_root() {
    if [[ -d "${STEAM_NATIVE}/compatibilitytools.d" ]] || [[ -f "${STEAM_NATIVE}/config/config.vdf" ]]; then
        echo "${STEAM_NATIVE}"
    elif [[ -d "${STEAM_FLATPAK}/compatibilitytools.d" ]] || [[ -f "${STEAM_FLATPAK}/config/config.vdf" ]]; then
        echo "${STEAM_FLATPAK}"
    else
        # Fallback search
        local found
        found=$(find "${HOME}" -maxdepth 5 -name "config.vdf" -path "*/Steam/config/*" 2>/dev/null | head -1)
        if [[ -n "${found}" ]]; then
            dirname "$(dirname "${found}")"
        else
            echo ""
        fi
    fi
}

banner "GE-Proton — Install + Set as Global Default"
echo   "  Downloads latest GE-Proton, installs it, then edits Steam's"
echo   "  config.vdf to make it the default for ALL games."
echo   "  Steam must be closed while this runs."
echo

# ── 1. Enforce Steam is not running ──────────────────────────────────────────
header "Step 1: Checking Steam is closed"
if pgrep -x "steam" &>/dev/null || pgrep -x "steam.sh" &>/dev/null; then
    error "Steam is currently running."
    error "Please close Steam completely (right-click tray icon → Exit) and re-run."
    exit 1
fi
success "Steam is not running."

# ── 2. Locate Steam root ──────────────────────────────────────────────────────
header "Step 2: Locating Steam installation"
STEAM_ROOT=$(detect_steam_root)
if [[ -z "${STEAM_ROOT}" ]]; then
    error "Could not find a Steam installation."
    error "Checked: ${STEAM_NATIVE}  and  ${STEAM_FLATPAK}"
    exit 1
fi
COMPAT_DIR="${STEAM_ROOT}/compatibilitytools.d"
CONFIG_VDF="${STEAM_ROOT}/config/config.vdf"
success "Steam root: ${STEAM_ROOT}"

if [[ ! -f "${CONFIG_VDF}" ]]; then
    error "config.vdf not found at: ${CONFIG_VDF}"
    error "Launch Steam at least once so it initialises its config files, then re-run."
    exit 1
fi

# ── 3. Download latest GE-Proton ─────────────────────────────────────────────
header "Step 3: Fetching latest GE-Proton release"
RELEASE_JSON="${TMP_DIR}/release.json"
fetch_github_release_json "${GITHUB_REPO}" "${RELEASE_JSON}"

if command -v jq &>/dev/null; then
    TAR_URL=$(jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' "${RELEASE_JSON}" | head -1)
    RELEASE_TAG=$(jq -r '.tag_name' "${RELEASE_JSON}")
else
    TAR_URL=$(python3 -c "
import json, sys
data = json.load(open('${RELEASE_JSON}'))
assets = [a['browser_download_url'] for a in data.get('assets', []) if a['name'].endswith('.tar.gz')]
print(assets[0] if assets else '')
")
    RELEASE_TAG=$(python3 -c "import json; print(json.load(open('${RELEASE_JSON}')).get('tag_name',''))")
fi

[[ -z "${TAR_URL}" ]]    && { error "No .tar.gz asset found in latest release."; exit 1; }
[[ -z "${RELEASE_TAG}" ]] && { error "Could not determine release tag."; exit 1; }

success "Latest: ${RELEASE_TAG}"

# Strip leading 'v' from tag if present to get the directory name Steam uses
# GE-Proton releases are tagged e.g. "GE-Proton9-27" (no 'v' prefix) but
# some older ones used "v..." — normalise either way
GE_DIR_NAME="${RELEASE_TAG#v}"   # e.g.  GE-Proton9-27

# ── 4. Install (skip if already present) ─────────────────────────────────────
header "Step 4: Installing GE-Proton"
mkdir -p "${COMPAT_DIR}"

if [[ -d "${COMPAT_DIR}/${GE_DIR_NAME}" ]]; then
    success "${GE_DIR_NAME} already installed — skipping download."
else
    info "Downloading ${GE_DIR_NAME} (this is ~400 MB, give it a moment)..."
    TAR_FILE="${TMP_DIR}/ge-proton.tar.gz"
    curl -sSfL --progress-bar "${TAR_URL}" -o "${TAR_FILE}"
    success "Download complete ($(du -sh "${TAR_FILE}" | cut -f1))"

    info "Extracting to ${COMPAT_DIR}..."
    tar -xf "${TAR_FILE}" -C "${COMPAT_DIR}"

    # Verify the directory appeared
    if [[ ! -d "${COMPAT_DIR}/${GE_DIR_NAME}" ]]; then
        # tar might have extracted with a slightly different name — find it
        EXTRACTED=$(ls -1t "${COMPAT_DIR}" | head -1)
        warn "Expected directory '${GE_DIR_NAME}', found '${EXTRACTED}' — using that."
        GE_DIR_NAME="${EXTRACTED}"
    fi
    success "GE-Proton installed: ${COMPAT_DIR}/${GE_DIR_NAME}"
fi

# ── 5. Set as global default in config.vdf ────────────────────────────────────
# The mechanism:
#   "CompatToolMapping" { "0" { "name" "GE-Proton9-27"  "config" ""  "Priority" "250" } }
# AppID "0" = the global fallback used for any game that has no per-game override.
# We use Python (always available) to do a clean text-VDF edit rather than sed
# on a complex nested file.
header "Step 5: Setting ${GE_DIR_NAME} as global default in config.vdf"

# Backup first
BACKUP="${CONFIG_VDF}.bak.$(date +%Y%m%d_%H%M%S)"
cp "${CONFIG_VDF}" "${BACKUP}"
success "config.vdf backed up to: ${BACKUP}"

python3 - "${CONFIG_VDF}" "${GE_DIR_NAME}" << 'PYEOF'
import sys, re

config_path = sys.argv[1]
ge_name     = sys.argv[2]

with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ── Strategy: find or create the "0" block inside CompatToolMapping ──────────
# We look for the CompatToolMapping section and update/insert the "0" entry.

compat_block_re = re.compile(
    r'("CompatToolMapping"\s*\{)(.*?)(\n(\s*)\})',
    re.DOTALL
)

new_zero_entry = (
    '\n\t\t\t"0"\n'
    '\t\t\t{\n'
    f'\t\t\t\t"name"\t\t"{ge_name}"\n'
    '\t\t\t\t"config"\t\t""\n'
    '\t\t\t\t"Priority"\t\t"250"\n'
    '\t\t\t}'
)

def update_compat(match):
    header   = match.group(1)   # "CompatToolMapping" {
    body     = match.group(2)   # everything inside
    footer   = match.group(3)   # closing \n    }
    indent   = match.group(4)   # leading whitespace before the closing brace

    # Remove any existing "0" entry
    body_clean = re.sub(
        r'\s*"0"\s*\{[^{}]*\}',
        '',
        body,
        flags=re.DOTALL
    )

    return header + new_zero_entry + body_clean + footer

if compat_block_re.search(content):
    new_content = compat_block_re.sub(update_compat, content, count=1)
else:
    # CompatToolMapping block doesn't exist — this can happen on fresh installs.
    # Inject it into the InstallConfigStore > Software > Valve > Steam section.
    inject = (
        '\t\t\t"CompatToolMapping"\n'
        '\t\t\t{\n'
        f'\t\t\t\t"0"\n'
        '\t\t\t\t{\n'
        f'\t\t\t\t\t"name"\t\t"{ge_name}"\n'
        '\t\t\t\t\t"config"\t\t""\n'
        '\t\t\t\t\t"Priority"\t\t"250"\n'
        '\t\t\t\t}\n'
        '\t\t\t}\n'
    )
    # Find the closing brace of the "Steam" section and insert before it
    steam_section_re = re.compile(r'("Steam"\s*\{)(.*?)(\n\t\t\})', re.DOTALL)
    def inject_into_steam(m):
        return m.group(1) + m.group(2) + '\n' + inject + m.group(3)
    new_content = steam_section_re.sub(inject_into_steam, content, count=1)
    if new_content == content:
        print("WARNING: Could not locate CompatToolMapping or Steam section — config.vdf may have an unexpected structure.")
        sys.exit(1)

with open(config_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"config.vdf updated: CompatToolMapping[0] = {ge_name}")
PYEOF

PYTHON_EXIT=$?
if [[ ${PYTHON_EXIT} -ne 0 ]]; then
    error "config.vdf edit failed — restoring backup."
    cp "${BACKUP}" "${CONFIG_VDF}"
    exit 1
fi
success "Global default set to: ${GE_DIR_NAME}"

# ── 6. Bazzite steamdeck-flag fix ─────────────────────────────────────────────
# On Bazzite, Steam runs with steamdeck flags that can override the user's
# chosen default Proton. Touching this file tells Bazzite not to set those flags.
header "Step 6: Applying Bazzite/uBlue steamdeck-flag fix (Bazzite only)"
BAZZITE_FLAG_DIR="${HOME}/.config/bazzite"
BAZZITE_FLAG_FILE="${BAZZITE_FLAG_DIR}/disable_steamdeck_flag"

mkdir -p "${BAZZITE_FLAG_DIR}"
if [[ -f "${BAZZITE_FLAG_FILE}" ]]; then
    success "disable_steamdeck_flag already present — nothing to do."
else
    touch "${BAZZITE_FLAG_FILE}"
    success "Created: ${BAZZITE_FLAG_FILE}"
    info    "This prevents the Bazzite Steam launch wrapper from overriding your"
    info    "chosen default Proton version."
fi

# ── 7. Verify the edit ────────────────────────────────────────────────────────
header "Step 7: Verifying config.vdf"
if grep -q "\"${GE_DIR_NAME}\"" "${CONFIG_VDF}"; then
    success "Verified: ${GE_DIR_NAME} is present in config.vdf"
else
    warn "Could not verify the entry in config.vdf — please check manually."
    warn "File: ${CONFIG_VDF}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
banner "GE-Proton Setup Complete"
echo
success "${GE_DIR_NAME} is installed and set as your global Steam default."
echo
echo -e "  ${BOLD}What happens next:${RESET}"
echo    "    1. Start Steam"
echo    "    2. Go to Settings → Compatibility"
echo    "    3. Confirm '${GE_DIR_NAME}' is selected as the default tool"
echo    "    4. Any game without a per-game Proton override will now use GE-Proton"
echo
echo -e "  ${YELLOW}Note:${RESET} Per-game overrides in Steam take priority over this global setting."
echo    "  If a specific game still uses a different Proton, right-click it in Steam"
echo    "  → Properties → Compatibility → Force the use of: ${GE_DIR_NAME}"
echo
echo -e "  ${YELLOW}EAC / BattlEye games:${RESET} Some anti-cheat games require official Proton 9+."
echo    "  Set those games to official Proton individually in their Properties."
echo
echo -e "  ${BOLD}Backup of original config.vdf:${RESET} ${BACKUP}"
echo
