# Ignis

**A Linux gaming setup tool.** Detects your OS and GPU, then installs and
configures the right apps for your system — no terminal required.

Built with [Tauri 2](https://tauri.app/) (Rust) + React. Works on Bazzite,
CachyOS, SteamOS, and Ubuntu.

![Platform](https://img.shields.io/badge/platform-Linux-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Built with Tauri](https://img.shields.io/badge/built%20with-Tauri%202-orange)
[![CI](https://github.com/billywalters/ignis-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/billywalters/ignis-setup/actions/workflows/ci.yml)
[![Release](https://github.com/billywalters/ignis-setup/actions/workflows/release.yml/badge.svg)](https://github.com/billywalters/ignis-setup/actions/workflows/release.yml)

---

## Download

> **No build required.** Pre-built binaries are on the
> [Releases page](https://github.com/billywalters/ignis-setup/releases).

| File | Use for |
|------|---------|
| `ignis-setup_*.AppImage` | **Recommended** — runs on any distro, no install needed |
| `ignis-setup_*.rpm` | Bazzite / Fedora permanent install |
| `ignis-setup_*.deb` | Ubuntu / Debian permanent install |

```bash
chmod +x ignis-setup_*.AppImage
./ignis-setup_*.AppImage
```

**Nightly builds** (latest `main`, expires 7 days) are available as workflow
artifacts on the
[Actions tab](https://github.com/billywalters/ignis-setup/actions/workflows/nightly.yml).

---

## What it does

Ignis starts by scanning your machine — OS family, GPU vendor, CPU, RAM — and
uses that to tailor every install decision. You get the right package manager,
the right encoder, the right upscale values. Nothing hardcoded.

### Gaming (the baseline)

| App | What it does |
|-----|-------------|
| **GE-Proton** | Installs the latest GE-Proton and sets it as your global Steam default automatically. Live update detection, Steam pre-check. |
| **DLSS Updater** | Keeps DLSS/XeSS DLLs current across your entire Steam library. |
| **OptiScaler Client** | Injects FSR4 into DLSS games (AMD) or upgrades upscalers (NVIDIA). |
| **Heroic Games Launcher** | Epic, GOG, and Amazon games via Proton. |
| **Bottles** | Run Windows modding tools and utilities in isolated Wine environments. |
| **Ludusavi** | Back up save data from 19,000+ games. Handles Proton save paths automatically — essential when migrating from Windows. |

### Emulation

| App | What it does |
|-----|-------------|
| **EmuDeck** | Full retro emulation suite. Ignis configures every emulator (RetroArch, Dolphin, PCSX2, DuckStation, PPSSPP, Cemu) to upscale to your chosen resolution — 720p, 1080p, 1440p, or 4K — with CRT-Royale shader on RetroArch. |

### Media

| App | What it does |
|-----|-------------|
| **HandBrake** | Installs HandBrake and auto-imports five tuned SVT-AV1 10-bit presets (RF 16, full audio passthrough). |
| **mpv** | HDR video player with dmabuf-wayland passthrough for 4K HDR. |
| **Jellyfin Server** | Self-hosted media server via Podman Quadlet. Includes a Windows → Linux migration wizard. |

### Streaming & Chat

| App | What it does |
|-----|-------------|
| **Sunshine** | Game streaming server. Stream your PC to any TV, phone, or Steam Deck. Pre-installed on Bazzite — Ignis just enables it. |
| **OBS Studio** | Installs and pre-configures with the correct hardware encoder (AMF/NVENC/Quick Sync) and your chosen output resolution. |
| **Discord** | Applies all Wayland/PipeWire/webcam/screen-share fixes in one step. |

### System

| App | What it does |
|-----|-------------|
| **LACT** | GPU overclocking, fan curves, power limits (AMD/NVIDIA/Intel). |
| **CoolerControl** | System-wide fan controller for all CPU and case fans. |
| **Flatseal** | GUI for managing Flatpak permissions. |
| **MangoHud** | In-game FPS/GPU/temp overlay. Pre-installed on Bazzite and SteamOS. |

---

## OS support

Ignis detects your distro at startup and uses the right package manager automatically.

| OS | Support | Package manager |
|----|---------|-----------------|
| **Bazzite** ⭐ | Full — all features | `rpm-ostree` |
| **CachyOS / Arch** ⭐ | Full — all features | `pacman` + `paru`/`yay` |
| **SteamOS** | Most features — Flatpak only | `flatpak-only` |
| **Ubuntu / Debian** | Most features | `apt` |

**SteamOS notes:** LACT and CoolerControl are unavailable (require persistent system daemons, wiped on OS update). Everything else works via Flatpak.

---

## Per-app OS compatibility

| App | Bazzite | CachyOS | SteamOS | Ubuntu |
|-----|:-------:|:-------:|:-------:|:------:|
| DLSS Updater | ✅ | ✅ | ✅ | ✅ |
| OptiScaler Client | ✅ | ✅ | ✅ | ✅ |
| GE-Proton | ✅ | ✅ | ✅ | ✅ |
| Heroic Games Launcher | ✅ | ✅ | ✅ | ✅ |
| Bottles | ✅ | ✅ | ✅ | ✅ |
| Ludusavi | ✅ | ✅ | ✅ | ✅ |
| EmuDeck | ✅ | ✅ | ✅ | ⚠️ |
| HandBrake | ✅ | ✅ | ✅ | ✅ |
| mpv | ✅ | ✅ | ⚠️ | ✅ |
| Jellyfin Server | ✅ | ✅ | ⚠️ | ✅ |
| Sunshine | ✅ | ✅ | ✅ | ✅ |
| OBS Studio | ✅ | ✅ | ✅ | ✅ |
| Discord | ✅ | ✅ | ✅ | ✅ |
| LACT | ✅ | ✅ | ❌ | ⚠️ |
| CoolerControl | ✅ | ✅ | ❌ | ⚠️ |
| Flatseal | ✅ | ✅ | ✅ | ✅ |
| MangoHud | ✅ | ✅ | ✅ | ✅ |

**Key:** ✅ Full — ⚠️ Partial/caveats — ❌ Not available

---

## GPU compatibility

Each app card shows a GPU badge (✓ / ⚠ / ✗) for your detected GPU vendor with a hover tooltip explaining any caveats. Notable cases:

- **DLSS Updater** — DLSS preset overrides require NVIDIA RTX 20+; DLL updates work on AMD/Intel
- **OptiScaler** — FSR4 neural quality requires RDNA4 (RX 9000 series)
- **OBS** — automatically configures AMF (AMD), NVENC (NVIDIA), or Quick Sync (Intel)
- **mpv** — HDR passthrough may need `nvidia-vaapi-driver` on NVIDIA
- **LACT** — full feature set on AMD; fan control not available on Intel via driver

---

## Building from source (optional)

Most users should download the AppImage from Releases. Build from source only
to modify the code or contribute.

```bash
git clone https://github.com/billywalters/ignis-setup.git
cd ignis-setup
bash build.sh
```

`build.sh` detects your OS and installs all build dependencies
(Rust, Node.js, WebKitGTK) via the correct package manager.

> **Bazzite/Fedora Atomic:** WebKitGTK installs via `rpm-ostree` and requires a
> reboot. Run `bash build.sh` again after rebooting.

Output: `src-tauri/target/release/bundle/appimage/ignis-setup_*.AppImage`

---

## Running scripts without the GUI

All scripts in `scripts/` detect your OS automatically and use the right
package manager. They can be run directly from a terminal:

```bash
# Run everything
bash scripts/setup-all.sh

# Dry-run — shows what would be installed, no changes made
bash scripts/setup-all.sh --dry-run

# Individual scripts
bash scripts/setup-ge-proton.sh
bash scripts/setup-obs.sh --resolution 1080p --gpu amd
bash scripts/setup-emudeck.sh --configure --res 4k

# Jellyfin Windows → Linux migration
bash scripts/migrate-jellyfin.sh \
  --mode clean \
  --source /mnt/nas/backup/jellyfin-backup.zip \
  --map "D:\Movies::/mnt/nas/media/Movies" \
  --map "D:\TV::/mnt/nas/media/TV"
```

---

## Project structure

```
ignis-setup/
├── build.sh                     One-command multi-OS build script (--dry-run supported)
├── handbrake-presets/           HandBrake SVT-AV1 preset JSON files (RF 16, copy audio)
├── scripts/                     Standalone bash setup scripts (OS-aware via _common.sh)
├── src/                         React frontend
│   ├── App.jsx                  Main orchestrator
│   ├── components/              UI components (panels, welcome screen, shared UI)
│   ├── context/                 React contexts (SysInfoContext)
│   ├── hooks/                   Custom hooks (install log, version caching)
│   └── lib/                     Utilities (Tauri IPC, apps catalogue, network validation)
└── src-tauri/                   Rust/Tauri backend
    └── src/                     Modular: system, installs, network, jellyfin,
                                 ge_proton, install_log, types
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, how to add apps, and PR guidelines.

### Release workflow

All builds are **free and unlimited** on public repositories.

| Workflow | Trigger | Output |
|----------|---------|--------|
| `ci.yml` | Every PR + push to `main` | Shellcheck, Vite build, cargo check + Clippy |
| `nightly.yml` | Every merge to `main` | AppImage artifact (7-day expiry) |
| `release.yml` | Push a `v*` tag | AppImage + .deb + .rpm → GitHub Release draft |
| `dependency-review.yml` | Every PR | CVE scan for new dependencies |

**To cut a release:**
```bash
npm pkg set version="1.0.0"
sed -i 's/^version = ".*"/version = "1.0.0"/' src-tauri/Cargo.toml
git add -A && git commit -m "Release v1.0.0"
git tag v1.0.0 && git push && git push --tags
# Review draft at: https://github.com/billywalters/ignis-setup/releases
```

---

## Community

- [Contributing guide](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

---

## License

MIT — see [LICENSE](LICENSE)
