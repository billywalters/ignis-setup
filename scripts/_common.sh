#!/usr/bin/env bash
# =============================================================================
# _common.sh  —  Shared helpers sourced by every setup script.
# Do NOT run this file directly.
# =============================================================================

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }
banner()  {
    echo -e "\n${BOLD}${CYAN}################################################################################${RESET}"
    echo -e "${BOLD}${CYAN}## $*${RESET}"
    echo -e "${BOLD}${CYAN}################################################################################${RESET}"
}

# =============================================================================
# OS detection
# Sets globals used by all helper functions:
#   OS_ID       — raw ID from /etc/os-release  (e.g. "bazzite", "cachyos", "steamos")
#   OS_FAMILY   — normalised family:
#                   "fedora-atomic"  Bazzite, Fedora Silverblue, uBlue variants
#                   "arch"           CachyOS, Arch, Manjaro
#                   "steamos"        SteamOS 3 / HoloISO (immutable Arch)
#                   "debian"         Ubuntu, Debian, Pop!_OS
#                   "unknown"        anything else
#   OS_PRETTY   — human-readable name
# =============================================================================
detect_os() {
    OS_ID=""
    OS_FAMILY="unknown"
    OS_PRETTY="Unknown Linux"

    if [[ -f /etc/os-release ]]; then
        # Source safely — only pull ID, ID_LIKE, PRETTY_NAME
        local id="" id_like="" pretty=""
        while IFS='=' read -r key val; do
            val="${val%\"}"    # strip trailing quote
            val="${val#\"}"    # strip leading quote
            case "${key}" in
                ID)          id="${val,,}" ;;        # lowercase
                ID_LIKE)     id_like="${val,,}" ;;
                PRETTY_NAME) pretty="${val}" ;;
            esac
        done < /etc/os-release

        OS_ID="${id}"
        OS_PRETTY="${pretty}"

        # Classify into families
        case "${id}" in
            bazzite|silverblue|kinoite|aurora|bluefin|ucore|ublue*)
                OS_FAMILY="fedora-atomic" ;;
            steamos|holo|holoiso)
                OS_FAMILY="steamos" ;;
            cachyos|arch|endeavouros|garuda|manjaro|artix)
                OS_FAMILY="arch" ;;
            ubuntu|debian|pop|linuxmint|elementary|zorin|neon)
                OS_FAMILY="debian" ;;
            fedora|nobara)
                # Fedora without atomic/ostree — treat as mutable fedora
                if command -v rpm-ostree &>/dev/null; then
                    OS_FAMILY="fedora-atomic"
                else
                    OS_FAMILY="fedora"
                fi
                ;;
            *)
                # Fall back to ID_LIKE
                if [[ "${id_like}" == *"arch"* ]]; then
                    # Distinguish SteamOS from generic Arch
                    if [[ -f /etc/steamos-release ]] || systemctl --version 2>/dev/null | grep -qi "steamos"; then
                        OS_FAMILY="steamos"
                    else
                        OS_FAMILY="arch"
                    fi
                elif [[ "${id_like}" == *"fedora"* ]] || [[ "${id_like}" == *"rhel"* ]]; then
                    OS_FAMILY="fedora-atomic"
                elif [[ "${id_like}" == *"debian"* ]] || [[ "${id_like}" == *"ubuntu"* ]]; then
                    OS_FAMILY="debian"
                fi
                ;;
        esac
    fi

    # Additional SteamOS heuristic: read-only root + steamos-readonly tool
    if [[ "${OS_FAMILY}" == "unknown" ]] && command -v steamos-readonly &>/dev/null; then
        OS_FAMILY="steamos"
        OS_ID="steamos"
    fi
}

# Run detection immediately so globals are available
detect_os

# ── OS-aware package installer ────────────────────────────────────────────────
# pkg_install PACKAGE [PACKAGE...]   — installs via the right package manager
# pkg_install_aur PACKAGE            — installs from AUR (arch/cachyos only)
# pkg_available PACKAGE              — returns 0 if the package is installed

pkg_install() {
    local packages=("$@")
    case "${OS_FAMILY}" in
        fedora-atomic)
            info "Installing via rpm-ostree: ${packages[*]}"
            rpm-ostree install --idempotent "${packages[@]}"
            ;;
        arch|steamos)
            if [[ "${OS_FAMILY}" == "steamos" ]]; then
                warn "SteamOS: system packages are wiped on OS updates."
                warn "Using pacman with read-only disabled (temporary install)."
                sudo steamos-readonly disable 2>/dev/null || true
                sudo pacman -S --noconfirm --needed "${packages[@]}"
                sudo steamos-readonly enable 2>/dev/null || true
            else
                sudo pacman -S --noconfirm --needed "${packages[@]}"
            fi
            ;;
        debian)
            sudo apt-get install -y "${packages[@]}"
            ;;
        fedora)
            sudo dnf install -y "${packages[@]}"
            ;;
        *)
            error "Unsupported OS family '${OS_FAMILY}' — cannot install: ${packages[*]}"
            return 1
            ;;
    esac
}

pkg_install_aur() {
    local package="$1"
    if [[ "${OS_FAMILY}" != "arch" ]]; then
        error "AUR installs are only available on Arch-based systems (detected: ${OS_FAMILY})"
        return 1
    fi
    # Prefer paru > yay > makepkg
    if command -v paru &>/dev/null; then
        paru -S --noconfirm --needed "${package}"
    elif command -v yay &>/dev/null; then
        yay -S --noconfirm --needed "${package}"
    else
        error "No AUR helper found (paru or yay). Install one first:"
        error "  sudo pacman -S paru"
        return 1
    fi
}

pkg_available() {
    local package="$1"
    case "${OS_FAMILY}" in
        fedora-atomic|fedora) rpm -q "${package}" &>/dev/null ;;
        arch|steamos)         pacman -Qi "${package}" &>/dev/null ;;
        debian)               dpkg -l "${package}" 2>/dev/null | grep -q "^ii" ;;
        *)                    command -v "${package}" &>/dev/null ;;
    esac
}

# ── Flatpak preflight ─────────────────────────────────────────────────────────
ensure_flatpak() {
    header "Checking Flatpak (OS: ${OS_PRETTY} / family: ${OS_FAMILY})"

    if ! command -v flatpak &>/dev/null; then
        warn "flatpak not found — attempting to install..."
        case "${OS_FAMILY}" in
            fedora-atomic)
                rpm-ostree install --idempotent flatpak
                echo -e "  ${YELLOW}Flatpak staged via rpm-ostree. Please REBOOT and re-run.${RESET}"
                exit 0
                ;;
            arch)
                sudo pacman -S --noconfirm --needed flatpak
                success "Flatpak installed."
                ;;
            steamos)
                warn "SteamOS: Flatpak should be pre-installed."
                warn "Try: sudo steamos-readonly disable && sudo pacman -S flatpak && sudo steamos-readonly enable"
                exit 1
                ;;
            debian)
                sudo apt-get install -y flatpak
                success "Flatpak installed."
                ;;
            *)
                error "Cannot install flatpak on OS family '${OS_FAMILY}'. Install it manually."
                exit 1
                ;;
        esac
    else
        success "flatpak is installed: $(flatpak --version)"
    fi

    # Ensure Flathub remote is configured
    if ! flatpak remotes --user 2>/dev/null | grep -q "flathub" && \
       ! flatpak remotes --system 2>/dev/null | grep -q "flathub"; then
        info "Adding Flathub remote..."
        flatpak remote-add --user --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
        success "Flathub remote added."
    else
        success "Flathub remote is configured."
    fi
}

# ── Reboot guard ──────────────────────────────────────────────────────────────
# Only meaningful on rpm-ostree systems. Safe to call on any OS.
check_reboot_pending() {
    if [[ "${OS_FAMILY}" == "fedora-atomic" ]]; then
        if rpm-ostree status 2>/dev/null | grep -q "pending\|staged"; then
            echo
            echo -e "  ${YELLOW}⚠  rpm-ostree has staged changes that require a reboot.${RESET}"
            echo    "  After rebooting, re-run the script to complete configuration."
            return 0
        fi
    fi
    return 1
}

# ── SteamOS persistence warning ───────────────────────────────────────────────
# Call before any system-level install on SteamOS to warn the user.
steamos_persist_warn() {
    if [[ "${OS_FAMILY}" == "steamos" ]]; then
        warn "SteamOS: system-level changes (outside your home folder) will be"
        warn "lost on the next OS update. Use Flatpak where possible."
    fi
}

# ── GitHub latest release helpers ─────────────────────────────────────────────
fetch_github_release_json() {
    local repo="$1" outfile="$2"
    if ! curl -sSfL "https://api.github.com/repos/${repo}/releases/latest" -o "${outfile}"; then
        error "Failed to fetch release info for ${repo}."
        return 1
    fi
}

parse_asset_url() {
    local json="$1" pattern="$2"
    if command -v jq &>/dev/null; then
        jq -r --arg p "${pattern}" \
            '.assets[] | select(.name | test($p;"i")) | .browser_download_url' \
            "${json}" | head -1
    else
        python3 - <<PYEOF
import json, re, sys
with open('${json}') as f:
    data = json.load(f)
pat = re.compile(r'${pattern}', re.IGNORECASE)
for a in data.get('assets', []):
    if pat.search(a['name']):
        print(a['browser_download_url']); sys.exit(0)
PYEOF
    fi
}

parse_release_tag() {
    local json="$1"
    if command -v jq &>/dev/null; then
        jq -r '.tag_name' "${json}"
    else
        python3 -c "import json; print(json.load(open('${json}')).get('tag_name',''))"
    fi
}

# ── Dry-run support ───────────────────────────────────────────────────────────
# Scripts can check $DRY_RUN before any destructive action.
# setup-all.sh sets this; individual scripts respect it if called directly.
DRY_RUN="${DRY_RUN:-false}"

# dry_run_cmd — print the command if dry-run, otherwise execute it
dry_run_cmd() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Would run: $*"
    else
        "$@"
    fi
}
