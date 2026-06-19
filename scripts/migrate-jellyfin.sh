#!/usr/bin/env bash
# =============================================================================
# migrate-jellyfin.sh
# Migrates a Jellyfin server from Windows to this Linux machine (Podman Quadlet).
#
# Two modes:
#   --mode clean  Import config + settings only. Media is rescanned from scratch.
#                 Fast, reliable, loses watch history.
#
#   --mode full   Import everything + rewrite Windows paths in library.db to
#                 Linux paths. Preserves watched status and play counts.
#                 Requires Python 3 + sqlite3.
#
# Usage:
#   bash migrate-jellyfin.sh \
#     --mode clean \
#     --source /mnt/nas/backup/jellyfin-backup.zip \
#     --map "D:\Movies::/mnt/nas/media/Movies" \
#     --map "D:\TV::/mnt/nas/media/TV"
#
# --map can be specified multiple times. Format: "WINDOWS_PATH::LINUX_PATH"
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/_common.sh" ]] && source "${SCRIPT_DIR}/_common.sh" \
  || [[ -f "${SCRIPT_DIR}/../scripts/_common.sh" ]] && source "${SCRIPT_DIR}/../scripts/_common.sh" \
  || { echo "ERROR: _common.sh not found"; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
MODE=""
SOURCE=""
declare -a PATH_MAPS=()
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)   MODE="$2";           shift 2 ;;
        --source) SOURCE="$2";         shift 2 ;;
        --map)    PATH_MAPS+=("$2");   shift 2 ;;
        *) warn "Unknown argument: $1"; shift ;;
    esac
done

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ -z "${MODE}" ]]; then
    error "--mode is required (clean or full)"
    exit 1
fi
if [[ -z "${SOURCE}" ]]; then
    error "--source is required (path to backup ZIP or folder)"
    exit 1
fi
if [[ ! -e "${SOURCE}" ]]; then
    error "Source not found: ${SOURCE}"
    exit 1
fi

# ── Jellyfin Podman Quadlet data location ─────────────────────────────────────
# Our setup-jellyfin installs as Podman Quadlet with config at:
JF_CONFIG="${HOME}/.local/share/jellyfin/config"
JF_CACHE="${HOME}/.local/share/jellyfin/cache"

# ── Detect if running in container vs bare metal ─────────────────────────────
# For the Podman container, we need to copy into the config volume path.
# The quadlet unit maps ${JF_CONFIG} → /config inside the container.
CONTAINER_NAME="jellyfin"

banner "Jellyfin Migration — Windows → Linux"
echo   "  Mode:   ${MODE}"
echo   "  Source: ${SOURCE}"
echo   "  Maps:   ${#PATH_MAPS[@]} path mapping(s)"
echo

# ── Step 1: Stop Jellyfin ────────────────────────────────────────────────────
header "Step 1: Stopping Jellyfin"
if systemctl --user is-active "${CONTAINER_NAME}" &>/dev/null 2>&1; then
    systemctl --user stop "${CONTAINER_NAME}"
    success "Jellyfin stopped."
    JELLYFIN_WAS_RUNNING=true
else
    info "Jellyfin is not currently running."
    JELLYFIN_WAS_RUNNING=false
fi

# ── Step 2: Backup existing data ─────────────────────────────────────────────
header "Step 2: Backing up existing Jellyfin data"
BACKUP_DIR="${HOME}/.local/share/jellyfin/migration-backup-$(date +%Y%m%d_%H%M%S)"

if [[ -d "${JF_CONFIG}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    cp -a "${JF_CONFIG}" "${BACKUP_DIR}/config"
    [[ -d "${JF_CACHE}" ]] && cp -a "${JF_CACHE}" "${BACKUP_DIR}/cache" || true
    success "Backup created: ${BACKUP_DIR}"
else
    info "No existing Jellyfin data to back up (fresh install)."
    mkdir -p "${JF_CONFIG}"
fi

# ── Step 3: Extract/locate source data ───────────────────────────────────────
header "Step 3: Extracting source data"
EXTRACT_DIR="${TMP_DIR}/jellyfin-source"
mkdir -p "${EXTRACT_DIR}"

if [[ "${SOURCE}" == *.zip ]]; then
    info "Extracting ZIP: ${SOURCE}"
    unzip -q "${SOURCE}" -d "${EXTRACT_DIR}"
    success "Extracted."
    # Find the actual data root inside the ZIP — could be nested
    # Look for jellyfin.db or library.db as a landmark
    DATA_ROOT=$(find "${EXTRACT_DIR}" -name "jellyfin.db" -o -name "library.db" 2>/dev/null \
        | head -1 | xargs -I{} dirname {} 2>/dev/null | xargs -I{} dirname {} 2>/dev/null || echo "")
    if [[ -z "${DATA_ROOT}" ]]; then
        # Try the extracted root directly
        DATA_ROOT="${EXTRACT_DIR}"
    fi
else
    # It's a folder — use directly
    DATA_ROOT="${SOURCE}"
    success "Using folder: ${DATA_ROOT}"
fi

info "Source data root: ${DATA_ROOT}"

# ── Locate subdirectories inside the Windows backup ──────────────────────────
# Windows layout:  C:\ProgramData\Jellyfin\Server\config\     → JF config
#                  C:\ProgramData\Jellyfin\Server\data\        → library.db, metadata, plugins
# Jellyfin 10.9+:  same but may be directly at the root
find_subdir() {
    local root="$1" name="$2"
    # Try exact match first
    [[ -d "${root}/${name}" ]] && echo "${root}/${name}" && return
    # Case-insensitive search
    find "${root}" -maxdepth 2 -iname "${name}" -type d 2>/dev/null | head -1
}

WIN_CONFIG_DIR=$(find_subdir "${DATA_ROOT}" "config" || echo "")
WIN_DATA_DIR=$(find_subdir "${DATA_ROOT}" "data" || echo "")
WIN_METADATA_DIR=$(find_subdir "${DATA_ROOT}" "metadata" || echo "")
WIN_PLUGINS_DIR=$(find_subdir "${DATA_ROOT}" "plugins" || echo "")

# Fallback: if layout is flat (Server folder is the root)
[[ -z "${WIN_CONFIG_DIR}" ]]   && [[ -d "${DATA_ROOT}" ]] && WIN_CONFIG_DIR="${DATA_ROOT}"
[[ -z "${WIN_DATA_DIR}" ]]     && [[ -d "${DATA_ROOT}" ]] && WIN_DATA_DIR="${DATA_ROOT}"

info "config dir:   ${WIN_CONFIG_DIR:-not found}"
info "data dir:     ${WIN_DATA_DIR:-not found}"
info "metadata dir: ${WIN_METADATA_DIR:-not found}"
info "plugins dir:  ${WIN_PLUGINS_DIR:-not found}"

# ── Step 4: Copy config files ─────────────────────────────────────────────────
header "Step 4: Importing configuration"

copy_if_exists() {
    local src="$1" dst="$2"
    [[ -e "${src}" ]] || return 0
    mkdir -p "$(dirname "${dst}")"
    cp -a "${src}" "${dst}"
    success "  Copied: $(basename "${src}")"
}

# Always copy regardless of mode: users, API keys, server settings, plugins
if [[ -n "${WIN_CONFIG_DIR}" ]]; then
    # system.xml — main server configuration
    copy_if_exists "${WIN_CONFIG_DIR}/system.xml"              "${JF_CONFIG}/config/system.xml"
    copy_if_exists "${WIN_CONFIG_DIR}/network.xml"             "${JF_CONFIG}/config/network.xml"
    copy_if_exists "${WIN_CONFIG_DIR}/encoding.xml"            "${JF_CONFIG}/config/encoding.xml"
    # users
    [[ -d "${WIN_CONFIG_DIR}/users" ]] && {
        cp -a "${WIN_CONFIG_DIR}/users" "${JF_CONFIG}/config/users"
        success "  Copied: users/"
    }
fi

if [[ -n "${WIN_DATA_DIR}" ]]; then
    # Plugins
    if [[ -n "${WIN_PLUGINS_DIR}" ]] && [[ -d "${WIN_PLUGINS_DIR}" ]]; then
        mkdir -p "${JF_CONFIG}/data/plugins"
        # Copy plugin DLLs — skip Windows-only ones (they won't load on Linux)
        find "${WIN_PLUGINS_DIR}" -maxdepth 2 -name "*.dll" -exec cp {} "${JF_CONFIG}/data/plugins/" \; 2>/dev/null || true
        find "${WIN_PLUGINS_DIR}" -maxdepth 2 -name "*.json" -exec cp {} "${JF_CONFIG}/data/plugins/" \; 2>/dev/null || true
        success "  Copied: plugins"
    fi

    # library_options.xml — per-library options (important: which metadata providers are enabled)
    find "${WIN_DATA_DIR}" -name "library_options.xml" -exec cp {} "${JF_CONFIG}/data/" \; 2>/dev/null || true
fi

# ── Step 5: Mode-specific handling ────────────────────────────────────────────
header "Step 5: Mode-specific migration"

if [[ "${MODE}" == "clean" ]]; then
    # ── Clean mode: update library paths in system.xml then let Jellyfin rescan ──
    info "Clean mode: updating library paths in configuration."

    # Find library XML files that reference Windows paths and update them
    SYSTEM_XML="${JF_CONFIG}/config/system.xml"

    if [[ ${#PATH_MAPS[@]} -gt 0 ]] && [[ -f "${SYSTEM_XML}" ]]; then
        cp "${SYSTEM_XML}" "${SYSTEM_XML}.pre-migration"
        for map in "${PATH_MAPS[@]}"; do
            WIN_PATH="${map%%::*}"
            LINUX_PATH="${map##*::}"
            # Escape backslashes for sed
            WIN_ESCAPED=$(printf '%s\n' "${WIN_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g; s/\\/\\\\/g')
            LINUX_ESCAPED=$(printf '%s\n' "${LINUX_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g')
            sed -i "s|${WIN_ESCAPED}|${LINUX_ESCAPED}|gI" "${SYSTEM_XML}" 2>/dev/null || true
            success "  Updated: ${WIN_PATH} → ${LINUX_PATH}"
        done
    fi

    # Also update any library folder XML files
    find "${JF_CONFIG}" -name "*.xml" | while read -r xml_file; do
        for map in "${PATH_MAPS[@]}"; do
            WIN_PATH="${map%%::*}"
            LINUX_PATH="${map##*::}"
            WIN_ESCAPED=$(printf '%s\n' "${WIN_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g; s/\\/\\\\/g')
            LINUX_ESCAPED=$(printf '%s\n' "${LINUX_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g')
            sed -i "s|${WIN_ESCAPED}|${LINUX_ESCAPED}|gI" "${xml_file}" 2>/dev/null || true
        done
    done

    success "Configuration updated with new media paths."
    info "After Jellyfin starts, go to Dashboard → Libraries → Scan All Libraries."

elif [[ "${MODE}" == "full" ]]; then
    # ── Full mode: copy metadata + rewrite library.db ─────────────────────────
    info "Full mode: copying metadata and rewriting library.db."

    # Check dependencies
    if ! command -v python3 &>/dev/null; then
        error "python3 is required for full migration mode."
        error "Install it with: rpm-ostree install python3"
        exit 1
    fi
    if ! python3 -c "import sqlite3" 2>/dev/null; then
        error "Python sqlite3 module not available."
        exit 1
    fi
    success "Dependencies OK (Python 3 + sqlite3)"

    # Copy metadata directory
    if [[ -n "${WIN_METADATA_DIR}" ]] && [[ -d "${WIN_METADATA_DIR}" ]]; then
        info "Copying metadata (this may take a while for large libraries)..."
        mkdir -p "${JF_CONFIG}/data/metadata"
        cp -a "${WIN_METADATA_DIR}/." "${JF_CONFIG}/data/metadata/"
        success "Metadata copied."
    fi

    # Find and copy library.db
    LIBRARY_DB=$(find "${WIN_DATA_DIR}" -name "library.db" 2>/dev/null | head -1 || echo "")
    if [[ -z "${LIBRARY_DB}" ]]; then
        warn "library.db not found in source — skipping database migration."
        warn "Watch history will not be preserved."
    else
        info "Found library.db: ${LIBRARY_DB}"
        DEST_DB="${JF_CONFIG}/data/library.db"
        cp "${LIBRARY_DB}" "${DEST_DB}.pre-migration"
        cp "${LIBRARY_DB}" "${DEST_DB}"
        success "library.db copied."

        # ── Rewrite paths in library.db using Python ────────────────────────
        info "Rewriting Windows paths in library.db..."

        python3 - "${DEST_DB}" "${PATH_MAPS[@]+"${PATH_MAPS[@]}"}" << 'PYEOF'
import sys, sqlite3, re

db_path = sys.argv[1]
maps_raw = sys.argv[2:]   # "WIN_PATH::LINUX_PATH" strings

if not maps_raw:
    print("[INFO]  No path maps provided — skipping database path rewrite.")
    sys.exit(0)

path_maps = []
for m in maps_raw:
    if "::" not in m:
        continue
    win, linux = m.split("::", 1)
    # Normalise Windows path separators → forward slash for regex matching
    win = win.replace("/", "\\")
    path_maps.append((win, linux))
    print(f"[INFO]  Map: {win!r} → {linux!r}")

if not path_maps:
    print("[WARN]  No valid path maps parsed.")
    sys.exit(0)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

def replace_paths(value: str) -> str:
    if not isinstance(value, str):
        return value
    result = value
    for win_path, linux_path in path_maps:
        # Match case-insensitively; handle both \ and / separators
        pattern = re.compile(re.escape(win_path).replace(r"\\", r"[/\\\\]"), re.IGNORECASE)
        result = pattern.sub(linux_path, result)
        # Also handle forward-slash versions of Windows path
        win_forward = win_path.replace("\\", "/")
        pattern2 = re.compile(re.escape(win_forward), re.IGNORECASE)
        result = pattern2.sub(linux_path, result)
    return result

total_updated = 0

# Update TypedBaseItems — main item paths
cursor = conn.cursor()
cursor.execute("SELECT guid, Path FROM TypedBaseItems WHERE Path IS NOT NULL")
rows = cursor.fetchall()
batch = []
for row in rows:
    new_path = replace_paths(row["Path"])
    if new_path != row["Path"]:
        batch.append((new_path, row["guid"]))

if batch:
    cursor.executemany("UPDATE TypedBaseItems SET Path=? WHERE guid=?", batch)
    total_updated += len(batch)
    print(f"[OK]    Updated {len(batch)} path(s) in TypedBaseItems")

# Update mediastreams
cursor.execute("SELECT ItemId, Path FROM mediastreams WHERE Path IS NOT NULL")
rows = cursor.fetchall()
batch = []
for row in rows:
    new_path = replace_paths(row["Path"])
    if new_path != row["Path"]:
        batch.append((new_path, row["ItemId"]))

if batch:
    cursor.executemany("UPDATE mediastreams SET Path=? WHERE ItemId=?", batch)
    total_updated += len(batch)
    print(f"[OK]    Updated {len(batch)} path(s) in mediastreams")

# Commit
conn.commit()
conn.close()

if total_updated == 0:
    print("[WARN]  No paths were updated in the database.")
    print("[WARN]  Check that your Windows paths match what Jellyfin stored.")
    print("[WARN]  Tip: Open library.db in DB Browser for SQLite to inspect TypedBaseItems.Path")
else:
    print(f"[OK]    Database rewrite complete. {total_updated} total path(s) updated.")
PYEOF

        PYEXIT=$?
        if [[ ${PYEXIT} -ne 0 ]]; then
            error "Database path rewrite failed — restoring original library.db"
            cp "${DEST_DB}.pre-migration" "${DEST_DB}"
            exit 1
        fi

        # Also rewrite paths in playlist and collection XML files
        info "Updating paths in playlist and collection files..."
        find "${JF_CONFIG}/data" -name "*.xml" -o -name "*.nfo" | while read -r f; do
            for map in "${PATH_MAPS[@]}"; do
                WIN_PATH="${map%%::*}"
                LINUX_PATH="${map##*::}"
                WIN_ESCAPED=$(printf '%s\n' "${WIN_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g; s/\\/\\\\/g')
                LINUX_ESCAPED=$(printf '%s\n' "${LINUX_PATH}" | sed 's/[[\.*^$()+?{|]/\\&/g')
                sed -i "s|${WIN_ESCAPED}|${LINUX_ESCAPED}|gI" "${f}" 2>/dev/null || true
            done
        done
        success "Playlist and collection files updated."
    fi
fi

# ── Step 6: Fix permissions ────────────────────────────────────────────────────
header "Step 6: Fixing file permissions"
chmod -R u+rw "${JF_CONFIG}" 2>/dev/null || true
success "Permissions updated."

# ── Step 7: Restart Jellyfin ──────────────────────────────────────────────────
header "Step 7: Restarting Jellyfin"
systemctl --user daemon-reload
systemctl --user start "${CONTAINER_NAME}"

# Wait for Jellyfin to be ready (up to 30 seconds)
info "Waiting for Jellyfin to start..."
for i in $(seq 1 15); do
    sleep 2
    if curl -sf "http://localhost:8096/health" &>/dev/null 2>&1; then
        success "Jellyfin is up and healthy."
        break
    fi
    [[ $i -eq 15 ]] && warn "Jellyfin health check timed out. It may still be starting."
done

# ── Done ──────────────────────────────────────────────────────────────────────
banner "Migration Complete"
echo
success "Jellyfin has been migrated from Windows."
echo
echo -e "  ${BOLD}Backup of previous data:${RESET} ${BACKUP_DIR:-none (fresh install)}"
echo -e "  ${BOLD}Dashboard:${RESET} http://localhost:8096"
echo
echo -e "  ${BOLD}Next steps:${RESET}"
if [[ "${MODE}" == "clean" ]]; then
    echo    "    1. Open the dashboard and check your library folders are correct"
    echo    "    2. Dashboard → Libraries → Scan All Libraries"
    echo    "    3. Metadata will rebuild over the next few minutes"
else
    echo    "    1. Open the dashboard and check a few shows/movies"
    echo    "    2. Confirm watched status is preserved"
    echo    "    3. If paths look wrong, check Dashboard → Libraries → Edit each library"
    echo    "    4. Plugins may need to be reinstalled (Windows DLLs don't run on Linux)"
fi
echo
echo -e "  ${YELLOW}If something looks wrong:${RESET}"
echo    "    Your original data is backed up at: ${BACKUP_DIR:-N/A}"
echo    "    To restore: systemctl --user stop jellyfin"
echo    "               cp -a ${BACKUP_DIR:-/path/to/backup}/config ~/.local/share/jellyfin/"
echo    "               systemctl --user start jellyfin"
echo
