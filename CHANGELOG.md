# Changelog

All notable changes to Ignis will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Scope & distribution change

- **Bazzite-only.** Removed Arch/CachyOS, SteamOS, and Debian/Ubuntu support to
  focus on a single platform that can be built, tested, and shipped reliably.
  Dropped the `install_pacman_pkg`/`install_aur_pkg`/`install_apt_pkg` commands
  and trimmed each app's `installMethods`/`osSupport` to `fedora-atomic` + `any`.
- **Ships as a Flatpak.** Replaced the AppImage build with a Flatpak built against
  the GNOME runtime, which provides a matched WebKitGTK — fixing the
  `EGL_BAD_PARAMETER` and Skia font crashes seen with the AppImage on Bazzite's
  bleeding-edge Mesa stack.
- **Host command routing.** Added `host_command()` which prepends
  `flatpak-spawn --host` inside the sandbox, so the app can still run host
  commands (flatpak, systemctl, nmcli, pkexec, ujust, rpm-ostree, podman).
- **CI.** `nightly.yml` (AppImage) replaced by `flatpak.yml`, which publishes a
  rolling `nightly` `.flatpak` release on every push to `main`. Added
  `dep-update.yml` for weekly n-1 dependency updates with a supply-chain audit.

### Initial release — features shipped

**App installer**
- 15-app catalogue covering Gaming, Emulation, Media, Streaming, and System categories
- Live GitHub version checks with 10-minute session cache (avoids API rate limiting)
- Per-app GPU compatibility badges (AMD / NVIDIA / Intel) with hover tooltips
- Per-app OS compatibility badges with unavailable state (grayed out at 45% opacity)
- Persistent install log at `~/.local/share/ignis-setup/install-log.json``
- "Last installed" timestamp shown on each app card

**Multi-OS support**
- OS detection via `/etc/os-release` at startup (Rust backend + shell `_common.sh`)
- Supported families: `fedora-atomic` (Bazzite), `arch` (CachyOS), `steamos` (SteamOS), `debian` (Ubuntu)
- Per-app `installMethods` map — correct package manager used automatically per OS
- Fallback chains: `aur-or-flatpak`, `pacman-or-flatpak` for maximum compatibility
- LACT and CoolerControl shown as unavailable on SteamOS (daemon incompatibility)

**Featured app panels**
- **GE-Proton** — live status tiles, Steam-is-running pre-check with friendly blocker, update detection
- **OBS Studio** — GPU encoder auto-detection (AMF/NVENC/QSV/x264), 4 resolution options
- **Discord** — Wayland/PipeWire/webcam/screen-share/Rich Presence configured in one step
- **HandBrake** — installs and auto-imports 5 SVT-AV1 10-bit presets (RF 16, full audio passthrough)

**Network & Media**
- Static IP via `nmcli` with full input validation (CIDR, gateway, DNS format checking)
- NAS mount wizard (SMB/NFS) with ping test and optional `/etc/fstab` persistence
- Jellyfin server via Podman Quadlet (start/stop/restart, live status polling)
- Jellyfin Windows → Linux migration wizard (clean mode + full SQLite path rewrite)

**First-run experience**
- Welcome screen on first launch (3-step: intro → hardware confirm → setup choice)
- Hardware summary with OS and GPU support notes
- Full setup shortcut or browse-manually option
- Re-accessible via "? Help" button in topbar

**CI/CD (GitHub Actions)**
- `ci.yml` — runs on every PR: shellcheck, Vite build, Rust cargo check + Clippy (~5 min)
- `nightly.yml` — runs on every merge to main: full AppImage build uploaded as workflow artifact (7-day expiry)
- `release.yml` — runs on version tag push: builds AppImage + .deb + .rpm, creates GitHub Release draft
- `dependency-review.yml` — scans new dependencies in PRs for CVEs and license issues
- All workflows use `ubuntu-22.04` per Tauri's recommendation for maximum AppImage compatibility
- Rust build cache via `Swatinem/rust-cache` significantly speeds up subsequent builds
- Free and unlimited on public repositories

**GitHub community files**
- `CONTRIBUTING.md` — dev setup, how to add apps, PR guidelines
- `SECURITY.md` — vulnerability reporting policy, scope, security design notes
- `CODE_OF_CONDUCT.md` — Contributor Covenant 2.1
- `.github/pull_request_template.md` — structured PR checklist
- `.github/CODEOWNERS` — automatic review assignment
- `.github/dependabot.yml` — weekly automated dependency updates for npm, Cargo, and Actions
- `--dry-run` flag for both `build.sh` and `setup-all.sh`
- Pinned Rust toolchain (`stable`) and Tauri CLI (`^2`) for reproducibility

**Project structure**
- `src/components/ui.jsx` — all shared UI primitives (Btn, Badge, Terminal, Modal, etc.)
- `src/components/GeProtonPanel.jsx` — standalone GE-Proton panel
- `src/components/AppPanels.jsx` — OBS, Discord, HandBrake panels
- `src/components/WelcomeScreen.jsx` — first-run welcome flow
- `src/hooks/useInstallLog.js` — install log + staggered version fetching
- GitHub issue templates: bug report, feature request, OS compatibility report
