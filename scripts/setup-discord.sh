#!/usr/bin/env bash
# =============================================================================
# setup-discord.sh
# Installs Discord (Flatpak), then applies every known fix for audio, webcam,
# screen sharing, and Wayland on Linux.
#
# What this does:
#   1. Installs Discord from Flathub
#   2. Grants Wayland socket access (native Wayland since Discord 0.0.94)
#   3. Grants device=all (webcam, capture devices)
#   4. Grants home filesystem access (file attachments)
#   5. Grants PipeWire socket (voice + audio streaming)
#   6. Creates the Rich Presence IPC symlink (so games can show activity)
#   7. Enables hardware video acceleration via flags
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/_common.sh" ]] && source "${SCRIPT_DIR}/_common.sh" \
  || [[ -f "${SCRIPT_DIR}/../scripts/_common.sh" ]] && source "${SCRIPT_DIR}/../scripts/_common.sh" \
  || { echo "ERROR: _common.sh not found"; exit 1; }

DISCORD_FLATPAK="com.discordapp.Discord"
DISCORD_CONFIG="${HOME}/.var/app/${DISCORD_FLATPAK}/config/discord"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

banner "Discord — Install & Configure"
echo   "  Installs Discord and applies all Linux/Wayland/PipeWire fixes for"
echo   "  audio, voice, webcam, and screen sharing."
echo

# ── 1. Flatpak preflight ──────────────────────────────────────────────────────
ensure_flatpak

# ── 2. Install ────────────────────────────────────────────────────────────────
header "Step 1: Installing Discord"
if flatpak list --app --user 2>/dev/null | grep -q "${DISCORD_FLATPAK}"; then
    VER=$(flatpak info --user "${DISCORD_FLATPAK}" 2>/dev/null | grep -i version | awk '{print $2}' || echo "installed")
    success "Discord already installed (${VER})"
else
    info "Installing Discord from Flathub..."
    dry_run_cmd flatpak install --user --noninteractive flathub "${DISCORD_FLATPAK}"
    success "Discord installed."
fi

# ── 3. Wayland socket ─────────────────────────────────────────────────────────
# Native Wayland is enabled by default since Discord 0.0.94, but we ensure
# the socket permission is explicitly set for older Flatpak runtimes.
header "Step 2: Enabling native Wayland"
flatpak override --user --socket=wayland "${DISCORD_FLATPAK}"
success "Wayland socket access granted."

# ── 4. Webcam + capture devices ───────────────────────────────────────────────
header "Step 3: Granting webcam and device access"
flatpak override --user --device=all "${DISCORD_FLATPAK}"
success "All devices granted (webcam, capture cards)."

# ── 5. File attachments ───────────────────────────────────────────────────────
header "Step 4: Granting filesystem access for file attachments"
flatpak override --user --filesystem=home "${DISCORD_FLATPAK}"
success "Home directory access granted."

# ── 6. PipeWire audio socket ──────────────────────────────────────────────────
# Required for PipeWire-based voice and audio streaming on Wayland
header "Step 5: Granting PipeWire audio access"
flatpak override --user \
    --filesystem=xdg-run/pipewire-0 \
    "${DISCORD_FLATPAK}" 2>/dev/null || true

# Also grant PulseAudio socket as fallback
flatpak override --user --socket=pulseaudio "${DISCORD_FLATPAK}" 2>/dev/null || true
success "PipeWire and PulseAudio sockets granted."

# ── 7. Rich Presence IPC symlink ──────────────────────────────────────────────
# Games and apps report "playing X" status to Discord through a Unix socket.
# The Flatpak sandbox puts Discord's socket in a different path than what apps
# expect. This symlink bridges the gap.
header "Step 6: Setting up Rich Presence IPC symlink"
DISCORD_IPC_SOURCE="${RUNTIME_DIR}/app/${DISCORD_FLATPAK}/discord-ipc-0"
DISCORD_IPC_TARGET="${RUNTIME_DIR}/discord-ipc-0"

if [[ -L "${DISCORD_IPC_TARGET}" ]]; then
    success "Rich Presence symlink already exists."
else
    # Create it now (Discord must have been run at least once for the source to exist)
    if [[ -S "${DISCORD_IPC_SOURCE}" ]]; then
        ln -sf "${DISCORD_IPC_SOURCE}" "${DISCORD_IPC_TARGET}"
        success "Rich Presence symlink created: ${DISCORD_IPC_TARGET}"
    else
        warn "Discord IPC socket not found yet (Discord hasn't been run)."
        warn "Creating the symlink via systemd user service so it auto-creates on login."
    fi
fi

# Create a systemd user service to recreate the symlink on every login
# (the socket disappears when Discord closes)
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER_DIR}"

cat > "${SYSTEMD_USER_DIR}/discord-rpc.service" << UNIT
[Unit]
Description=Discord Rich Presence IPC symlink
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'ln -sf "${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}/app/com.discordapp.Discord/discord-ipc-0" "${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}/discord-ipc-0" 2>/dev/null || true'

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable discord-rpc.service 2>/dev/null || true
success "Rich Presence symlink service enabled (runs on every login)."

# ── 8. Hardware video acceleration flags ─────────────────────────────────────
# Improves video call quality and reduces lag on the server list.
# Stored in Discord's own settings.json inside the Flatpak data dir.
header "Step 7: Enabling hardware video acceleration"
mkdir -p "${DISCORD_CONFIG}"
SETTINGS_JSON="${DISCORD_CONFIG}/settings.json"

if [[ -f "${SETTINGS_JSON}" ]]; then
    # Merge into existing settings using Python
    python3 - "${SETTINGS_JSON}" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)
settings["SKIP_HOST_UPDATE"]                 = False
settings["IS_MAXIMIZED"]                     = False
settings["WINDOW_BOUNDS"]                    = settings.get("WINDOW_BOUNDS", {})
# Hardware acceleration flags
settings["enableHardwareAcceleration"]       = True
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
print("settings.json updated")
PYEOF
    success "Hardware acceleration enabled in settings.json"
else
    # Write fresh settings
    cat > "${SETTINGS_JSON}" << JSON
{
  "SKIP_HOST_UPDATE": false,
  "enableHardwareAcceleration": true
}
JSON
    success "settings.json created with hardware acceleration enabled."
fi

# ── 9. Verify ─────────────────────────────────────────────────────────────────
header "Step 8: Verification"
echo
info "Checking applied permissions..."
flatpak info --show-permissions --user "${DISCORD_FLATPAK}" 2>/dev/null | grep -E "socket|device|filesystems" || true

# ── Done ──────────────────────────────────────────────────────────────────────
banner "Discord Setup Complete"
echo
success "Discord is installed and configured for Linux/Wayland."
echo
echo -e "  ${BOLD}What was applied:${RESET}"
echo    "    ✓ Native Wayland rendering (socket granted)"
echo    "    ✓ Webcam + capture device access"
echo    "    ✓ Home directory (file attachments)"
echo    "    ✓ PipeWire socket (voice + audio streaming)"
echo    "    ✓ Rich Presence IPC symlink (game activity status)"
echo    "    ✓ Hardware video acceleration enabled"
echo
echo -e "  ${YELLOW}After launching Discord:${RESET}"
echo    "    Settings → Voice & Video"
echo    "    → Set your microphone and headset/speaker manually"
echo    "    → Enable noise suppression if desired"
echo    "    → Test screen share with a friend to confirm it works"
echo
echo -e "  ${YELLOW}Screen sharing tip:${RESET}"
echo    "    On Wayland, Discord uses the XDG portal for screen sharing."
echo    "    When you share a screen, KDE will show a permission dialog —"
echo    "    just click Allow to proceed."
echo
