# Ignis

**A gaming & media setup tool for [Bazzite](https://bazzite.gg/).** Detects your
GPU and hardware, then installs and configures the right apps for your system —
no terminal required.

Built with [Tauri 2](https://tauri.app/) (Rust) + React, and shipped as a
**Flatpak** so it runs cleanly on Bazzite's immutable, atomic base.

![Platform](https://img.shields.io/badge/platform-Bazzite-8839ef)
![License](https://img.shields.io/badge/license-MIT-green)
![Built with Tauri](https://img.shields.io/badge/built%20with-Tauri%202-orange)
[![CI](https://github.com/billywalters/ignis-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/billywalters/ignis-setup/actions/workflows/ci.yml)
[![Flatpak build](https://github.com/billywalters/ignis-setup/actions/workflows/flatpak.yml/badge.svg)](https://github.com/billywalters/ignis-setup/actions/workflows/flatpak.yml)

---

## Scope

Ignis targets **Bazzite only** (and other Fedora Atomic / `rpm-ostree` images
it's closely related to). Support for Arch, SteamOS, and Debian/Ubuntu was
removed so the project focuses on one platform it can build, test, and ship
reliably. If you're on another distro, this isn't the tool for you right now.

---

## Download & install

> **No build required.** Grab the latest `.flatpak` bundle from the
> [nightly release](https://github.com/billywalters/ignis-setup/releases/tag/nightly)
> (rebuilt on every push to `main`).

```bash
flatpak install --user ./ignis-setup.flatpak
flatpak run io.github.billywalters.ignis-setup
```

The Flatpak runs against the GNOME runtime, which supplies a matched WebKitGTK —
so there are no host-vs-bundled library conflicts on Bazzite's bleeding-edge
Mesa stack. Because Ignis configures the host (Flatpak, systemctl, nmcli,
rpm-ostree, ujust), it uses `flatpak-spawn --host` to run those commands
outside the sandbox.

---

## What it does

Ignis scans your machine — GPU vendor, CPU, RAM — and uses that to tailor every
install decision: the right encoder, the right upscale values. Nothing
hardcoded.

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
| **Jellyfin Server** | Self-hosted media server via Podman Quadlet. Includes a Windows → Linux migration wizard and optional Cloudflare Tunnel for remote access. |

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
| **MangoHud** | In-game FPS/GPU/temp overlay. Pre-installed on Bazzite. |

On Bazzite, each app installs via the most appropriate method — `ujust` recipes
where Bazzite provides them, `rpm-ostree` for system packages that need it, and
user Flatpaks for everything else.

---

## GPU compatibility

Each app card shows a GPU badge (✓ / ⚠ / ✗) for your detected GPU vendor with a
hover tooltip explaining any caveats. Notable cases:

- **DLSS Updater** — DLSS preset overrides require NVIDIA RTX 20+; DLL updates work on AMD/Intel
- **OptiScaler** — FSR4 neural quality requires RDNA4 (RX 9000 series)
- **OBS** — automatically configures AMF (AMD), NVENC (NVIDIA), or Quick Sync (Intel)
- **mpv** — HDR passthrough may need `nvidia-vaapi-driver` on NVIDIA
- **LACT** — full feature set on AMD; fan control not available on Intel via driver

---

## Building from source (optional)

Most users should install the Flatpak from the nightly release. Build from
source only to modify the code or contribute.

**Dev mode (hot reload):**

```bash
git clone https://github.com/billywalters/ignis-setup.git
cd ignis-setup
npm install
npm run tauri dev
```

This needs a Rust stable toolchain, Node.js, and the WebKitGTK 4.1 dev
libraries on the host.

**Build the Flatpak locally:**

```bash
flatpak install flathub org.gnome.Platform//47 org.gnome.Sdk//47 \
  org.freedesktop.Sdk.Extension.rust-stable//24.08 \
  org.freedesktop.Sdk.Extension.node20//24.08
flatpak-builder --user --install --force-clean build-dir \
  flatpak/io.github.billywalters.ignis-setup.yml
flatpak run io.github.billywalters.ignis-setup
```

---

## Project structure

```
ignis-setup/
├── flatpak/                     Flatpak manifest, desktop entry, AppStream metainfo
├── scripts/                     Standalone bash setup scripts
├── src/                         React frontend
│   ├── App.jsx                  Main orchestrator
│   ├── components/              UI components (panels, welcome screen, shared UI)
│   ├── context/                 React contexts (SysInfoContext)
│   ├── hooks/                   Custom hooks (install log, version caching)
│   └── lib/                     Utilities (Tauri IPC, apps catalogue, network validation)
└── src-tauri/                   Rust/Tauri backend
    └── src/                     Modular: system, installs, network, jellyfin,
                                 cloudflare, ge_proton, install_log, types
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, how to add apps, and PR guidelines.

### Workflows

All builds are **free and unlimited** on public repositories.

| Workflow | Trigger | Output |
|----------|---------|--------|
| `ci.yml` | Every PR + push to `main` | Shellcheck, Vite build, cargo check + Clippy |
| `flatpak.yml` | Every push to `main` | Rolling nightly `.flatpak` bundle on the [nightly release](https://github.com/billywalters/ignis-setup/releases/tag/nightly) |
| `dependency-review.yml` | Every PR | CVE scan for new dependencies |
| `dep-update.yml` | Weekly (Sunday) | n-1 dependency update PR + supply-chain audit |

---

## Community

- [Contributing guide](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

---

## License

MIT — see [LICENSE](LICENSE)
