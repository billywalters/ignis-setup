#!/usr/bin/env bash
# =============================================================================
# setup-all.sh
# Master orchestrator for Ignis.
# Runs every setup script in order on a fresh Bazzite install.
#
# Safe to re-run at any time — every individual script is idempotent and
# skips steps that are already done.
#
# Usage:
#   bash scripts/setup-all.sh                   Run everything
#   bash scripts/setup-all.sh --skip-emudeck    Skip EmuDeck (GUI wizard)
#   bash scripts/setup-all.sh --skip-obs        Skip OBS
#   bash scripts/setup-all.sh --skip-discord    Skip Discord
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

SKIP_EMUDECK=false
SKIP_OBS=false
SKIP_DISCORD=false
export DRY_RUN=false

for arg in "$@"; do
    case "${arg}" in
        --skip-emudeck) SKIP_EMUDECK=true ;;
        --skip-obs)     SKIP_OBS=true ;;
        --skip-discord) SKIP_DISCORD=true ;;
        --dry-run)      DRY_RUN=true ;;
    esac
done

[[ "${DRY_RUN}" == "true" ]] && warn "DRY-RUN mode — no changes will be made."

# =============================================================================
# Preflight
# =============================================================================
banner "Ignis — Full Setup"
echo   "  Installs and configures all apps managed by Ignis."
echo   "  OS:   ${OS_PRETTY} (family: ${OS_FAMILY})"
echo   "  Date: $(date '+%Y-%m-%d %H:%M')"
echo

header "Preflight: Checking dependencies"

# Flatpak (required by most apps)
ensure_flatpak

# Required CLI tools
MISSING_TOOLS=()
for tool in curl python3 xdg-mime; do
    if command -v "${tool}" &>/dev/null; then
        success "  Found: ${tool}"
    else
        warn "  Missing: ${tool}"
        MISSING_TOOLS+=("${tool}")
    fi
done

if (( ${#MISSING_TOOLS[@]} > 0 )); then
    warn "Installing missing tools via ${OS_FAMILY} package manager..."
    pkg_install "${MISSING_TOOLS[@]}" || true
    check_reboot_pending && {
        echo -e "  ${YELLOW}Reboot required. Re-run after rebooting.${RESET}"
        exit 0
    }
fi

# =============================================================================
# Script list
# =============================================================================
declare -a SCRIPTS=(
    "setup-mpv-hdr.sh"
    "setup-dlss-updater.sh"
    "setup-optiscaler-client.sh"
    "setup-ge-proton.sh"
    "setup-handbrake.sh"
    "setup-vscode.sh"
)

[[ "${SKIP_OBS}"     == "false" ]] && SCRIPTS+=("setup-obs.sh")
[[ "${SKIP_DISCORD}" == "false" ]] && SCRIPTS+=("setup-discord.sh")
[[ "${SKIP_EMUDECK}" == "false" ]] && SCRIPTS+=("setup-emudeck.sh")

# =============================================================================
# Run each script
# =============================================================================
FAILED=()
SKIPPED=()

for script in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="${SCRIPT_DIR}/${script}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        warn "Script not found, skipping: ${script}"
        SKIPPED+=("${script}")
        continue
    fi

    chmod +x "${SCRIPT_PATH}"
    banner "Running: ${script}"

    if bash "${SCRIPT_PATH}"; then
        success "${script} — completed."
    else
        error "${script} — failed (exit code $?)."
        FAILED+=("${script}")
        warn "Continuing with remaining scripts..."
    fi
done

# =============================================================================
# Summary
# =============================================================================
banner "Setup Summary"
echo

TOTAL=${#SCRIPTS[@]}
FAIL_COUNT=${#FAILED[@]}
SKIP_COUNT=${#SKIPPED[@]}
PASS_COUNT=$(( TOTAL - FAIL_COUNT - SKIP_COUNT ))

echo -e "  ${GREEN}✓ Passed:${RESET}   ${PASS_COUNT} / ${TOTAL}"

if (( SKIP_COUNT > 0 )); then
    echo -e "  ${YELLOW}⚠ Skipped:${RESET}  ${SKIP_COUNT} (script file missing)"
    printf   "      - %s\n" "${SKIPPED[@]}"
fi

if (( FAIL_COUNT > 0 )); then
    echo -e "  ${RED}✗ Failed:${RESET}   ${FAIL_COUNT}"
    printf   "      - %s\n" "${FAILED[@]}"
    echo
    warn "Re-run failed scripts individually to see the full error:"
    for s in "${FAILED[@]}"; do
        echo -e "    ${CYAN}bash ${SCRIPT_DIR}/${s}${RESET}"
    done
    exit 1
fi

echo
success "All scripts completed."

if [[ "${SKIP_EMUDECK}" == "false" ]]; then
    echo
    echo -e "  ${YELLOW}EmuDeck reminder:${RESET} Complete the EmuDeck GUI wizard if it opened,"
    echo    "  then run:  bash ${SCRIPT_DIR}/setup-emudeck.sh --configure"
fi

check_reboot_pending || true
echo
