# CLAUDE.md — Ignis Setup

This file is read automatically by Claude Code at the start of every session.
It gives you the full context you need to work on this project effectively.

---

## What this project is

**Ignis** is a native Linux desktop application (Tauri 2 + React) that
automates the setup and configuration of a Linux gaming and media PC. It detects
the user's OS, GPU, and hardware at runtime and installs apps using the correct
package manager for their distro.

**GitHub:** https://github.com/billywalters/ignis-setup  
**Owner:** @billywalters  
**Stack:** Rust (Tauri 2 backend) + React (Vite frontend) + Bash (setup scripts)

---

## Development commands

```bash
# Start the app in hot-reload dev mode
npm run tauri dev

# Build frontend only (Vite)
npm run build

# Build the full native app (AppImage + .deb + .rpm)
npm run tauri build
# or use the helper script:
bash build.sh

# Check shell script syntax
bash -n scripts/<scriptname>.sh

# Lint shell scripts
shellcheck --severity=error --exclude=SC2034,SC1091 scripts/*.sh

# Check Rust (fast — no full compile)
cd src-tauri && cargo check

# Rust lint
cd src-tauri && cargo clippy -- -D warnings

# Dry-run the full setup (shows what would be installed, no changes made)
bash scripts/setup-all.sh --dry-run
```

---

## Project structure

```
ignis-setup/
│
├── src/                            React frontend
│   ├── App.jsx                     Main orchestrator — pages + panels wired together
│   ├── main.jsx                    React entry point
│   ├── styles.css                  CSS custom properties (--accent, --surface, etc.)
│   │
│   ├── components/                 Reusable UI components
│   │   ├── ui.jsx                  ALL shared primitives: Btn, Badge, NavBtn, Terminal,
│   │   │                           Spinner, Modal, ModalHeader, GpuCompatBadge,
│   │   │                           OsSupportBadge, plus the `s` style token object
│   │   ├── AppPanels.jsx           OBSPanel, DiscordPanel, HandbrakePanel
│   │   ├── GeProtonPanel.jsx       GE-Proton install + Steam default manager
│   │   └── WelcomeScreen.jsx       First-run welcome flow (3 steps)
│   │
│   ├── context/
│   │   └── SysInfoContext.js       React context for system info — import from HERE,
│   │                               never from App.jsx
│   │
│   ├── hooks/
│   │   └── useInstallLog.js        Persistent install log + staggered GitHub version
│   │                               fetching with 10-min session cache
│   │
│   └── lib/
│       ├── apps.js                 App catalogue — installMethods, osSupport, gpuSupport
│       ├── tauri.js                ALL Tauri IPC bindings (invoke wrappers)
│       └── network.js              IP/CIDR/DNS validation helpers
│
├── src-tauri/                      Rust/Tauri backend
│   ├── build.rs                    Required tauri-build entry point
│   ├── Cargo.toml                  Rust dependencies
│   ├── tauri.conf.json             Tauri configuration (CSP, window size, bundle targets)
│   ├── icons/                      App icons — must be replaced before building a release
│   │                               See icons/README.md for generation instructions
│   └── src/
│       ├── lib.rs                  Thin orchestrator: mod declarations + invoke handler
│       ├── main.rs                 Binary entry point (one line)
│       ├── types.rs                CommandResult, run_cmd, run_sudo_cmd, dirs_home
│       ├── system.rs               OS detection + get_system_info command
│       ├── installs.rs             install_flatpak, run_ujust, install_pacman, etc.
│       ├── network.rs              nmcli, NAS mount, fstab, ping
│       ├── jellyfin.rs             Podman Quadlet install + service control
│       ├── ge_proton.rs            GE-Proton status, install, set Steam default
│       └── install_log.rs          Persistent install log at ~/.local/share/ignis-setup/
│
├── scripts/                        Standalone bash scripts (also called by the GUI)
│   ├── _common.sh                  *** SOURCE THIS FIRST in every script ***
│   │                               Provides: OS detection (OS_ID, OS_FAMILY, OS_PRETTY),
│   │                               pkg_install(), pkg_install_aur(), dry_run_cmd(),
│   │                               ensure_flatpak(), check_reboot_pending(),
│   │                               fetch_github_release_json(), parse_asset_url()
│   ├── setup-all.sh                Orchestrator — runs all scripts (supports --dry-run,
│   │                               --skip-emudeck, --skip-obs, --skip-discord)
│   ├── setup-mpv-hdr.sh            mpv + HDR passthrough config
│   ├── setup-dlss-updater.sh       DLSS Updater (Flatpak)
│   ├── setup-optiscaler-client.sh  OptiScaler Client (AppImage)
│   ├── setup-ge-proton.sh          GE-Proton download + config.vdf default
│   │                               (Includes Bottles + Ludusavi as simple Flatpak installs)
│   ├── setup-handbrake.sh          HandBrake + SVT-AV1 preset import
│   ├── setup-obs.sh                OBS Studio + GPU encoder config (--resolution, --gpu)
│   ├── setup-discord.sh            Discord + Wayland/PipeWire/webcam fixes
│   ├── setup-emudeck.sh            EmuDeck install + per-emulator resolution scaling
│   │                               Phase 1: install (ujust or curl)
│   │                               Phase 2: --configure --res 720p|1080p|1440p|4k
│   │                               Configures: RetroArch, Dolphin, PCSX2, DuckStation,
│   │                               PPSSPP, and Cemu. Default resolution: 4k.
│   └── migrate-jellyfin.sh         Jellyfin Windows → Linux migration
│                                   (--mode clean|full --source path --map WIN::LINUX)
│
├── handbrake-presets/              HandBrake SVT-AV1 preset JSON files (RF 16, copy audio)
│
└── .github/
    ├── workflows/
    │   ├── ci.yml                  PR checks: shellcheck + Vite build + cargo check
    │   ├── nightly.yml             AppImage build on every merge to main (7-day artifact)
    │   ├── release.yml             Full build + GitHub Release on version tag push
    │   └── dependency-review.yml   CVE scan for new dependencies in PRs
    ├── ISSUE_TEMPLATE/             Bug report, feature request, OS compat report
    ├── pull_request_template.md    PR checklist
    ├── CODEOWNERS                  @billywalters on all paths
    └── dependabot.yml              Weekly updates for npm, Cargo, Actions
```

---

## Architecture: how the two halves talk

The React frontend calls Rust backend functions via Tauri's IPC:

```
React component
  → import from src/lib/tauri.js        (all IPC in one place)
  → invoke("rust_command_name", args)
  → src-tauri/src/<module>.rs           (business logic)
  → CommandResult { success, stdout, stderr, exit_code }
```

**Rules:**
- All `invoke()` calls live in `src/lib/tauri.js` — never call `invoke` directly from a component
- All shared UI primitives (Btn, Badge, etc.) live in `src/components/ui.jsx`
- `SysInfoContext` must be imported from `src/context/SysInfoContext.js`, never from App.jsx
- GitHub version fetching uses `fetchLatestGithubVersionCached()` from `src/hooks/useInstallLog.js` — never the raw fetch, to avoid rate limiting

---

## OS families

The app detects one of these OS families at startup:

| Family | Distros | Package manager | Notes |
|--------|---------|-----------------|-------|
| `fedora-atomic` | Bazzite, Silverblue, Kinoite | `rpm-ostree` | System installs require reboot |
| `arch` | CachyOS, Arch, EndeavourOS | `pacman` + `paru`/`yay` (AUR) | Installs immediate |
| `steamos` | SteamOS 3, HoloISO | `flatpak-only` | System installs wiped on OS update |
| `debian` | Ubuntu, Debian, Pop!_OS | `apt` | Standard |
| `unknown` | Anything else | Flatpak fallback | Best-effort |

The OS family drives which `installMethods` entry is used per app in `apps.js`.

---

## Adding a new app — checklist

1. **`src/lib/apps.js`** — add an entry with:
   - `installMethods` — at minimum an `"any"` key; add per-family overrides as needed
   - `osSupport` — one entry per family with `level` (`full`/`partial`/`unavailable`) and `note`
   - `gpuSupport` — only needed if GPU vendor affects functionality
   - `checkFlatpakId` — set this instead of (or alongside) `checkCmd` when the app is
     installed as a Flatpak and doesn't put a binary in PATH. Used by `checkStatuses()`
     to correctly detect installed state. Without it, Flatpak apps always show "Not installed".
   - `preinstalled: true` only when the app is pre-installed on ALL supported OS families.
     For OS-specific pre-installs (e.g. MangoHud on Bazzite/SteamOS but not Arch/Ubuntu),
     use `method: "preinstalled"` in the specific `installMethods` entry instead.
2. **`scripts/setup-<name>.sh`** (optional) — if the install needs custom steps beyond a
   simple `pkg_install`. Start with:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/_common.sh"
   ```
   Use `pkg_install pkg-name` for system packages, `dry_run_cmd` for any destructive operations.
3. **Panel component** (optional) — if the app needs a config UI, add it to
   `src/components/AppPanels.jsx` or as its own file. Set `hasXxxPanel: true` in the app
   catalogue entry and wire it in `AppsPage` in `App.jsx`.

---

## Adding a new Tauri command — checklist

1. Write `pub fn my_command(arg: String) -> CommandResult` in the appropriate module
   under `src-tauri/src/`
2. Annotate with `#[tauri::command]`
3. Register in `lib.rs` invoke handler: `tauri::generate_handler![..., my_command]`
4. Export from `src/lib/tauri.js`: `export const myCommand = (arg) => invoke("my_command", { arg });`
5. Import in the component that needs it — never call `invoke` directly

---

## Script conventions

Every script in `scripts/` must:
- `source "${SCRIPT_DIR}/_common.sh"` as the first substantive line
- Use `pkg_install` (not raw `apt-get`/`pacman`/`rpm-ostree`) for system packages
- Wrap destructive operations with `dry_run_cmd` so `--dry-run` works
- Use `banner()`, `header()`, `success()`, `info()`, `warn()`, `error()` for output
- Call `ensure_flatpak` before any `flatpak install`
- Call `check_reboot_pending` after any `rpm-ostree install`

---

## CSS design tokens (from styles.css)

```
--bg          #0f1117   page background
--surface     #181c27   card/panel background
--surface2    #1f2436   input/secondary background
--border      #2a3050   borders
--accent      #e05c2a   primary orange (buttons, active states)
--accent2     #f07d4a   lighter orange (hover, headings)
--green       #3ddc84   success / installed
--yellow      #f5c542   warning / partial
--red         #ff5f5f   error / unavailable
--blue        #4ea6f5   info / latest version
--text        #e8eaf0   primary text
--muted       #7a84a0   secondary text
--radius      10px      border radius
--mono        JetBrains Mono / Fira Mono / monospace
```

All inline styles in components use these variables (e.g. `color: "var(--accent)"`).
Never hardcode hex colours except for `iconBg` values in `apps.js`.

---

## Release process

```bash
# 1. Update version in both files
npm pkg set version="1.1.0"
sed -i 's/^version = ".*"/version = "1.1.0"/' src-tauri/Cargo.toml

# 2. Update CHANGELOG.md — move Unreleased items under ## [1.1.0] - YYYY-MM-DD

# 3. Commit, tag, push
git add -A && git commit -m "Release v1.1.0"
git tag v1.1.0
git push && git push --tags

# GitHub Actions builds AppImage + .deb + .rpm and creates a draft release.
# Review at: https://github.com/billywalters/ignis-setup/releases
# Click Publish when ready.
```

---

## Known constraints and things to be careful about

- **Icons are placeholders** — `src-tauri/icons/` contains only a `.gitkeep`. The build will
  fail until real PNG/ICO files are provided. See `src-tauri/icons/README.md`.
- **AppImage build requires Ubuntu 22.04** — higher glibc versions break compatibility.
  The CI workflows pin to `ubuntu-22.04` for this reason. Don't change the runner.
- **SteamOS system installs are ephemeral** — anything installed outside `$HOME` on SteamOS
  is wiped on OS update. Flatpak or home-directory installs survive. The code accounts for this
  but be careful when adding new install methods for SteamOS.
- **`rpm-ostree` installs require a reboot** — always call `check_reboot_pending` after,
  and handle the case where the user hasn't rebooted yet.
- **GitHub API rate limit** — unauthenticated calls are limited to 60/hour. Always use
  `fetchLatestGithubVersionCached()` (10-min TTL) and `fetchVersionsStaggered()` (150ms
  between calls). Never call the GitHub API directly from components.
- **CSP restricts external connections** — the Tauri WebView CSP only allows
  `connect-src` to `https://api.github.com`. Any new external API call requires a CSP
  update in `src-tauri/tauri.conf.json`.
- **`run_sudo_cmd` uses `pkexec`** — this shows a GUI polkit password prompt. Never use
  silent `sudo` in Rust code; always go through `run_sudo_cmd` or `dry_run_cmd`.
- **`s` is the style object** — `s` is imported from `components/ui.jsx` as the style
  token object. Don't shadow it with a local variable name inside closures.

---

## CI/CD at a glance

| What you do | What happens |
|-------------|--------------|
| Open a PR | CI runs: shellcheck + Vite build + cargo check + dependency review |
| Merge to main | Nightly AppImage built and uploaded (7-day artifact) |
| Push `v1.2.3` tag | Full AppImage + .deb + .rpm built, draft release created |
| Monday morning | Dependabot opens PRs for outdated npm/Cargo/Actions deps |
