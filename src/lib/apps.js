// =============================================================================
// apps.js — Central app catalogue
//
// Each app has:
//   installMethods  — map of OS family → install instructions
//                     "any" is the fallback
//   osSupport       — level: "full" | "partial" | "unavailable" per OS family
//   gpuSupport      — level: "full" | "partial" | "none" per GPU vendor
//   checkFlatpakId  — if present, used for install-status check instead of checkCmd
//                     (needed when the binary isn't in PATH but Flatpak is installed)
// =============================================================================

export const APPS = [
  // ── Gaming ──────────────────────────────────────────────────────────────────
  {
    id: "dlss-updater",
    name: "DLSS Updater",
    icon: "🔄",
    iconBg: "#0d1b2a",
    category: "Gaming",
    desc: "Keeps DLSS/XeSS DLLs up to date across your Steam library. Particularly useful on NVIDIA for DLSS preset overrides; DLL updates work on any GPU.",
    githubRepo: "Recol/DLSS-Updater",
    checkCmd: null,
    checkFlatpakId: "io.github.recol.dlss-updater",
    preinstalled: false,
    installMethods: {
      any: { method: "flatpak", flatpakId: "io.github.recol.dlss-updater", scriptFile: "setup-dlss-updater.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Installs as user Flatpak" },
      { family: "arch",          level: "full",    note: "Installs as user Flatpak" },
      { family: "steamos",       level: "full",    note: "Installs as user Flatpak — survives OS updates" },
      { family: "debian",        level: "full",    note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "nvidia", level: "full",    note: "Full support including DLSS preset overrides (RTX 20+)" },
      { gpu: "amd",    level: "partial", note: "DLL updates work; DLSS SR Preset Override requires NVIDIA GPU" },
      { gpu: "intel",  level: "partial", note: "XeSS DLL updates work; DLSS preset features require NVIDIA" },
    ],
  },
  {
    id: "optiscaler",
    name: "OptiScaler Client",
    icon: "⚡",
    iconBg: "#1a0d2e",
    category: "Gaming",
    desc: "Manage OptiScaler per game. On AMD: inject FSR4 into DLSS games. On NVIDIA: upgrade upscalers. Works on all GPUs.",
    githubRepo: "Agustinm28/Optiscaler-Client",
    checkCmd: "OptiscalerClient",
    preinstalled: false,
    installMethods: {
      any: { method: "appimage", scriptFile: "setup-optiscaler-client.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "AppImage installed to ~/.local/bin" },
      { family: "arch",          level: "full",    note: "AppImage installed to ~/.local/bin" },
      { family: "steamos",       level: "full",    note: "AppImage in home directory — survives OS updates" },
      { family: "debian",        level: "full",    note: "AppImage installed to ~/.local/bin" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full",    note: "Full FSR4 quality on RDNA4 (RX 9000 series)" },
      { gpu: "nvidia", level: "full",    note: "Replace/upgrade upscalers in DLSS games" },
      { gpu: "intel",  level: "partial", note: "XeSS-based features work; FSR4 neural path limited on Arc" },
    ],
  },
  {
    id: "ge-proton",
    name: "GE-Proton",
    icon: "🧪",
    iconBg: "#1a1000",
    category: "Gaming",
    desc: "Community Proton build with extra game patches. Installs latest version and sets it as your global Steam default. Includes ProtonUp-Qt for managing multiple Proton builds.",
    githubRepo: "GloriousEggroll/proton-ge-custom",
    checkCmd: null,
    preinstalled: false,
    hasPanel: true,
    installMethods: {
      any: { method: "script", scriptFile: "setup-ge-proton.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Installs to ~/.local/share/Steam/compatibilitytools.d" },
      { family: "arch",          level: "full", note: "Installs to ~/.local/share/Steam/compatibilitytools.d" },
      { family: "steamos",       level: "full", note: "Home directory install — survives OS updates" },
      { family: "debian",        level: "full", note: "Installs to ~/.local/share/Steam/compatibilitytools.d" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Full support" },
      { gpu: "nvidia", level: "full", note: "Full support" },
      { gpu: "intel",  level: "full", note: "Full support" },
    ],
  },
  {
    id: "heroic",
    name: "Heroic Games Launcher",
    icon: "🦸",
    iconBg: "#1a1200",
    category: "Gaming",
    desc: "Open-source launcher for Epic Games, GOG, and Amazon. Plays non-Steam titles via Proton on Linux.",
    githubRepo: "Heroic-Games-Launcher/HeroicGamesLauncher",
    checkCmd: null,
    checkFlatpakId: "com.heroicgameslauncher.hgl",
    preinstalled: false,
    installMethods: {
      arch: { method: "aur-or-flatpak", aur: "heroic-games-launcher-bin", flatpakId: "com.heroicgameslauncher.hgl" },
      any:  { method: "flatpak",         flatpakId: "com.heroicgameslauncher.hgl" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Installs as user Flatpak" },
      { family: "arch",          level: "full", note: "Available via AUR (heroic-games-launcher-bin) or Flatpak" },
      { family: "steamos",       level: "full", note: "Installs as user Flatpak" },
      { family: "debian",        level: "full", note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Full support" },
      { gpu: "nvidia", level: "full", note: "Full support" },
      { gpu: "intel",  level: "full", note: "Full support" },
    ],
  },
  {
    id: "bottles",
    name: "Bottles",
    icon: "🍾",
    iconBg: "#1a0a1a",
    category: "Gaming",
    desc: "Run Windows applications and games in isolated Wine environments. Great for modding tools, game launchers, and utilities that don't have a Linux version.",
    githubRepo: "bottlesdevs/Bottles",
    checkCmd: null,
    checkFlatpakId: "com.usebottles.bottles",
    preinstalled: false,
    installMethods: {
      any: { method: "flatpak", flatpakId: "com.usebottles.bottles" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Installs as user Flatpak" },
      { family: "arch",          level: "full",    note: "Installs as user Flatpak; also available via AUR: bottles" },
      { family: "steamos",       level: "full",    note: "Installs as user Flatpak — survives OS updates" },
      { family: "debian",        level: "full",    note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Full support via DXVK/VKD3D" },
      { gpu: "nvidia", level: "full", note: "Full support via DXVK/VKD3D" },
      { gpu: "intel",  level: "full", note: "Full support via DXVK/VKD3D" },
    ],
  },
  {
    id: "ludusavi",
    name: "Ludusavi",
    icon: "💾",
    iconBg: "#001a0d",
    category: "Gaming",
    desc: "Back up save data from 19,000+ games across Steam, Heroic, GOG, Lutris, and more. Handles Proton save locations automatically. Essential when migrating from Windows.",
    githubRepo: "mtkennerly/ludusavi",
    checkCmd: null,
    checkFlatpakId: "com.github.mtkennerly.ludusavi",
    preinstalled: false,
    installMethods: {
      arch: { method: "pacman-or-flatpak", pkg: "ludusavi", flatpakId: "com.github.mtkennerly.ludusavi" },
      any:  { method: "flatpak",           flatpakId: "com.github.mtkennerly.ludusavi" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Installs as user Flatpak" },
      { family: "arch",          level: "full", note: "Available via pacman (ludusavi) or Flatpak" },
      { family: "steamos",       level: "full", note: "Installs as user Flatpak — survives OS updates" },
      { family: "debian",        level: "full", note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "GPU-agnostic utility" },
      { gpu: "nvidia", level: "full", note: "GPU-agnostic utility" },
      { gpu: "intel",  level: "full", note: "GPU-agnostic utility" },
    ],
  },
  // ── Emulation ────────────────────────────────────────────────────────────────
  {
    id: "emudeck",
    name: "EmuDeck",
    icon: "🕹️",
    iconBg: "#0d2a1a",
    category: "Emulation",
    desc: "Retro emulation suite. Configures RetroArch, Dolphin, PCSX2, DuckStation, PPSSPP, and Cemu with upscaling to your chosen resolution (720p / 1080p / 1440p / 4K) and CRT-Royale shader for RetroArch.",
    githubRepo: "dragoonDorise/EmuDeck",
    checkCmd: null,
    preinstalled: false,
    hasEmuDeckPanel: true,
    installMethods: {
      "fedora-atomic": { method: "ujust",  ujustRecipe: "install-emudeck", scriptFile: "setup-emudeck.sh" },
      arch:            { method: "script", scriptFile: "setup-emudeck.sh" },
      steamos:         { method: "script", scriptFile: "setup-emudeck.sh" },
      any:             { method: "script", scriptFile: "setup-emudeck.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Via ujust install-emudeck" },
      { family: "arch",          level: "full",    note: "EmuDeck supports Arch-based distros" },
      { family: "steamos",       level: "full",    note: "Native SteamOS support — EmuDeck's primary target" },
      { family: "debian",        level: "partial", note: "EmuDeck supports Debian/Ubuntu but testing is limited" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full",    note: "Full support. 4K EFBScale on Dolphin is GPU-intensive; RDNA2+ handles it well." },
      { gpu: "nvidia", level: "full",    note: "Full support" },
      { gpu: "intel",  level: "partial", note: "Integrated graphics may struggle at 4K EFBScale; use 1080p or 1440p on older Intel GPUs" },
    ],
  },
  // ── Media ─────────────────────────────────────────────────────────────────────
  {
    id: "handbrake",
    name: "HandBrake",
    icon: "🎞",
    iconBg: "#1a0d00",
    category: "Media",
    desc: "Video transcoder. Installs HandBrake and auto-imports five SVT-AV1 10-bit presets at RF 16 with full audio passthrough.",
    githubRepo: "HandBrake/HandBrake",
    checkCmd: null,
    checkFlatpakId: "fr.handbrake.ghb",
    preinstalled: false,
    hasHandbrakePanel: true,
    installMethods: {
      arch: { method: "pacman-or-flatpak", pkg: "handbrake", flatpakId: "fr.handbrake.ghb", scriptFile: "setup-handbrake.sh" },
      any:  { method: "flatpak",           flatpakId: "fr.handbrake.ghb",                   scriptFile: "setup-handbrake.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Installs as user Flatpak" },
      { family: "arch",          level: "full", note: "Available via pacman (handbrake) or Flatpak" },
      { family: "steamos",       level: "full", note: "Installs as user Flatpak" },
      { family: "debian",        level: "full", note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "SVT-AV1 CPU encoding used in these presets" },
      { gpu: "nvidia", level: "full", note: "SVT-AV1 CPU encoding used in these presets" },
      { gpu: "intel",  level: "full", note: "SVT-AV1 CPU encoding used in these presets" },
    ],
  },
  {
    id: "mpv",
    name: "mpv",
    icon: "🎬",
    iconBg: "#1a1a2e",
    category: "Media",
    desc: "HDR video player with dmabuf-wayland passthrough. Best for 4K HDR10 remuxes on a large OLED.",
    githubRepo: "mpv-player/mpv",
    checkCmd: "mpv",
    preinstalled: false,
    installMethods: {
      "fedora-atomic": { method: "rpm-ostree", pkg: "mpv",       scriptFile: "setup-mpv-hdr.sh" },
      arch:            { method: "pacman",     pkg: "mpv",       scriptFile: "setup-mpv-hdr.sh" },
      steamos:         { method: "flatpak",    flatpakId: "io.mpv.mpv", scriptFile: "setup-mpv-hdr.sh" },
      debian:          { method: "apt",        pkg: "mpv",       scriptFile: "setup-mpv-hdr.sh" },
      any:             { method: "flatpak",    flatpakId: "io.mpv.mpv", scriptFile: "setup-mpv-hdr.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Installed via rpm-ostree; requires reboot" },
      { family: "arch",          level: "full",    note: "Installed via pacman (immediate)" },
      { family: "steamos",       level: "partial", note: "Installed as Flatpak; HDR passthrough still works; config path differs" },
      { family: "debian",        level: "full",    note: "Installed via apt" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full",    note: "Full HDR passthrough via VA-API" },
      { gpu: "nvidia", level: "partial", note: "HDR passthrough works but may need nvidia-vaapi-driver" },
      { gpu: "intel",  level: "partial", note: "HDR via VA-API; depends on iHD driver version" },
    ],
  },
  {
    id: "jellyfin",
    name: "Jellyfin Server",
    icon: "📺",
    iconBg: "#00141e",
    category: "Media",
    desc: "Self-hosted media server. Streams your movie/TV library to any device on your network. Installed as a Podman Quadlet.",
    githubRepo: "jellyfin/jellyfin",
    checkCmd: null,
    preinstalled: false,
    installMethods: {
      any: { method: "podman-quadlet" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Podman is pre-installed on Bazzite" },
      { family: "arch",          level: "full",    note: "Requires podman: sudo pacman -S podman" },
      { family: "steamos",       level: "partial", note: "Podman Quadlet works; linger must be enabled manually" },
      { family: "debian",        level: "full",    note: "Requires podman: sudo apt install podman" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "HW transcoding via VA-API (enable in Jellyfin dashboard)" },
      { gpu: "nvidia", level: "full", note: "HW transcoding via NVENC (enable in Jellyfin dashboard)" },
      { gpu: "intel",  level: "full", note: "HW transcoding via Quick Sync (enable in Jellyfin dashboard)" },
    ],
  },
  // ── Streaming & Chat ──────────────────────────────────────────────────────────
  {
    id: "sunshine",
    name: "Sunshine",
    icon: "☀️",
    iconBg: "#1a1400",
    category: "Streaming & Chat",
    desc: "Self-hosted game streaming server. Stream your PC to any TV, phone, tablet, or Steam Deck on your network via Moonlight. Pre-installed on Bazzite — just needs enabling.",
    githubRepo: "LizardByte/Sunshine",
    checkCmd: null,
    checkFlatpakId: "dev.lizardbyte.app.Sunshine",
    preinstalled: false,
    installMethods: {
      "fedora-atomic": { method: "ujust", ujustRecipe: "setup-sunshine",
                         note: "Pre-installed on Bazzite — ujust just enables the service" },
      arch:            { method: "aur-or-flatpak", aur: "sunshine-bin",
                         flatpakId: "dev.lizardbyte.app.Sunshine" },
      steamos:         { method: "flatpak", flatpakId: "dev.lizardbyte.app.Sunshine" },
      any:             { method: "flatpak", flatpakId: "dev.lizardbyte.app.Sunshine" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Pre-installed on Bazzite; ujust setup-sunshine enables it as a systemd user service" },
      { family: "arch",          level: "full",    note: "Available via AUR (sunshine-bin) or Flatpak" },
      { family: "steamos",       level: "full",    note: "Installs as user Flatpak — survives OS updates" },
      { family: "debian",        level: "full",    note: "Installs as user Flatpak" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Hardware-accelerated encoding via VA-API/AMF" },
      { gpu: "nvidia", level: "full", note: "Hardware-accelerated encoding via NVENC" },
      { gpu: "intel",  level: "full", note: "Hardware-accelerated encoding via Quick Sync" },
    ],
  },
  {
    id: "obs",
    name: "OBS Studio",
    icon: "🎥",
    iconBg: "#1a0020",
    category: "Streaming & Chat",
    desc: "Screen recorder and live streaming software. Pre-configured with the correct hardware encoder for your GPU and your chosen output resolution.",
    githubRepo: "obsproject/obs-studio",
    checkCmd: null,
    checkFlatpakId: "com.obsproject.Studio",
    preinstalled: false,
    hasOBSPanel: true,
    installMethods: {
      arch: { method: "pacman-or-flatpak", pkg: "obs-studio", flatpakId: "com.obsproject.Studio", scriptFile: "setup-obs.sh" },
      any:  { method: "flatpak",           flatpakId: "com.obsproject.Studio",                    scriptFile: "setup-obs.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Installs as user Flatpak (official OBS recommendation for non-Ubuntu)" },
      { family: "arch",          level: "full", note: "Available via pacman (obs-studio) or Flatpak" },
      { family: "steamos",       level: "full", note: "Installs as user Flatpak" },
      { family: "debian",        level: "full", note: "Installs as user Flatpak (official OBS recommendation)" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "AMF hardware encoder (H.264/HEVC)" },
      { gpu: "nvidia", level: "full", note: "NVENC hardware encoder (H.264/HEVC/AV1 on RTX 40+)" },
      { gpu: "intel",  level: "full", note: "Quick Sync hardware encoder; Intel Arc supports AV1" },
    ],
  },
  {
    id: "discord",
    name: "Discord",
    icon: "💬",
    iconBg: "#0d0d2a",
    category: "Streaming & Chat",
    desc: "Voice, video, and text chat. Configured with Wayland, PipeWire, webcam, and screen-share permissions for Linux.",
    githubRepo: null,
    checkCmd: null,
    checkFlatpakId: "com.discordapp.Discord",
    preinstalled: false,
    hasDiscordPanel: true,
    installMethods: {
      arch: { method: "aur-or-flatpak", aur: "discord", flatpakId: "com.discordapp.Discord", scriptFile: "setup-discord.sh" },
      any:  { method: "flatpak",        flatpakId: "com.discordapp.Discord",                 scriptFile: "setup-discord.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Installs as user Flatpak with Wayland/PipeWire fixes applied" },
      { family: "arch",          level: "full",    note: "Available via AUR (discord) or Flatpak" },
      { family: "steamos",       level: "full",    note: "Installs as user Flatpak; Wayland support built-in since 0.0.94" },
      { family: "debian",        level: "full",    note: "Installs as user Flatpak with Wayland/PipeWire fixes applied" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full",    note: "Full support" },
      { gpu: "nvidia", level: "partial", note: "Works; hardware acceleration may need extra driver setup" },
      { gpu: "intel",  level: "full",    note: "Full support with iHD driver" },
    ],
  },
  // ── Development ──────────────────────────────────────────────────────────────
  {
    id: "vscode",
    name: "VS Code",
    icon: "🖥",
    iconBg: "#001833",
    category: "Development",
    desc: "Microsoft's code editor. IntelliSense, debugging, Git integration, terminal, and a huge extension marketplace. The standard editor for working on Ignis itself.",
    githubRepo: "microsoft/vscode",
    checkCmd: "code",
    checkFlatpakId: "com.visualstudio.code",
    preinstalled: false,
    installMethods: {
      // Bazzite/Fedora Atomic: Flatpak is the right choice — rpm-ostree would require
      // a reboot and layering an Electron app is exactly what the Bazzite docs warn against
      "fedora-atomic": { method: "flatpak", flatpakId: "com.visualstudio.code",
                         scriptFile: "setup-vscode.sh" },
      // CachyOS/Arch: AUR gives full Microsoft binary (extensions marketplace, telemetry etc)
      // pacman gives VSCodium (open-source build, same features minus a few MS-specific ones)
      arch:            { method: "aur-or-flatpak", aur: "visual-studio-code-bin",
                         flatpakId: "com.visualstudio.code", scriptFile: "setup-vscode.sh" },
      steamos:         { method: "flatpak", flatpakId: "com.visualstudio.code",
                         scriptFile: "setup-vscode.sh" },
      debian:          { method: "script", scriptFile: "setup-vscode.sh",
                         note: "Installs via Microsoft's official apt repository" },
      any:             { method: "flatpak", flatpakId: "com.visualstudio.code",
                         scriptFile: "setup-vscode.sh" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",    note: "Installs as user Flatpak. Home directory access granted automatically." },
      { family: "arch",          level: "full",    note: "Full Microsoft binary via AUR (visual-studio-code-bin). Native install, best terminal/file access." },
      { family: "steamos",       level: "full",    note: "Installs as user Flatpak — survives OS updates." },
      { family: "debian",        level: "full",    note: "Installs via Microsoft's official apt repository for best update experience." },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "GPU-accelerated rendering via Electron/Chromium. GPU-agnostic tool." },
      { gpu: "nvidia", level: "full", note: "GPU-accelerated rendering via Electron/Chromium. GPU-agnostic tool." },
      { gpu: "intel",  level: "full", note: "GPU-accelerated rendering via Electron/Chromium. GPU-agnostic tool." },
    ],
  },
  // ── System ────────────────────────────────────────────────────────────────────
  {
    id: "lact",
    name: "LACT — GPU Control",
    icon: "🌡️",
    iconBg: "#2a0800",
    category: "System",
    desc: "GPU overclocking, fan curves, and power control. Works on AMD, NVIDIA (Maxwell+), and Intel GPUs.",
    githubRepo: "ilya-zlobintsev/LACT",
    checkCmd: "lact",
    checkFlatpakId: "com.lact.LACT",   // used as fallback when binary not in PATH (Flatpak installs)
    preinstalled: false,
    installMethods: {
      "fedora-atomic": { method: "ujust",  ujustRecipe: "install-lact" },
      arch:            { method: "pacman", pkg: "lact" },
      steamos:         { method: "unavailable" },
      any:             { method: "flatpak", flatpakId: "com.lact.LACT" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",        note: "Via ujust install-lact" },
      { family: "arch",          level: "full",        note: "Available in official CachyOS/Arch repos: pacman -S lact" },
      { family: "steamos",       level: "unavailable", note: "LACT daemon requires persistent system access; not compatible with SteamOS immutable root" },
      { family: "debian",        level: "partial",     note: "Via Flatpak; some features require manual system daemon setup" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full",    note: "Full support: OC, fan curves, power limit, V/F curve" },
      { gpu: "nvidia", level: "partial", note: "Fan curves and power limit. Requires proprietary driver + CUDA libs" },
      { gpu: "intel",  level: "partial", note: "Power and thermal monitoring. Fan control not supported by driver" },
    ],
  },
  {
    id: "coolercontrol",
    name: "CoolerControl",
    icon: "❄️",
    iconBg: "#001020",
    category: "System",
    desc: "System-wide fan controller. Custom curves for all CPU and case fans from one interface.",
    githubRepo: "codifryed/coolercontrol",
    checkCmd: null,
    checkFlatpakId: "org.coolercontrol.CoolerControl",
    preinstalled: false,
    installMethods: {
      "fedora-atomic": { method: "ujust",   ujustRecipe: "install-coolercontrol" },
      arch:            { method: "aur",     aur: "coolercontrol" },
      steamos:         { method: "unavailable" },
      any:             { method: "flatpak", flatpakId: "org.coolercontrol.CoolerControl" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full",        note: "Via ujust install-coolercontrol" },
      { family: "arch",          level: "full",        note: "Available via AUR: coolercontrol" },
      { family: "steamos",       level: "unavailable", note: "Requires persistent system daemon; not compatible with SteamOS" },
      { family: "debian",        level: "partial",     note: "Via Flatpak; daemon install may require manual steps" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Full support" },
      { gpu: "nvidia", level: "full", note: "Full support" },
      { gpu: "intel",  level: "full", note: "Full support" },
    ],
  },
  {
    id: "flatseal",
    name: "Flatseal",
    icon: "🔒",
    iconBg: "#001a1a",
    category: "System",
    desc: "GUI for managing Flatpak permissions. Grant apps access to cameras, game folders, or network paths.",
    githubRepo: "tchx84/Flatseal",
    checkCmd: null,
    checkFlatpakId: "com.github.tchx84.Flatseal",
    preinstalled: false,
    installMethods: {
      any: { method: "flatpak", flatpakId: "com.github.tchx84.Flatseal" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "GPU-agnostic utility" },
      { family: "arch",          level: "full", note: "GPU-agnostic utility" },
      { family: "steamos",       level: "full", note: "Particularly useful on SteamOS for managing Flatpak sandboxes" },
      { family: "debian",        level: "full", note: "GPU-agnostic utility" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "GPU-agnostic" },
      { gpu: "nvidia", level: "full", note: "GPU-agnostic" },
      { gpu: "intel",  level: "full", note: "GPU-agnostic" },
    ],
  },
  {
    id: "mangohud",
    name: "MangoHud",
    icon: "📊",
    iconBg: "#0a1a00",
    category: "System",
    desc: "In-game FPS/GPU/temp overlay. Pre-installed on Bazzite and SteamOS. Add MANGOHUD=1 to Steam launch options.",
    githubRepo: "flightlessmango/MangoHud",
    checkCmd: "mangohud",
    preinstalled: true,   // pre-installed on Bazzite + SteamOS; checkCmd handles other distros
    installMethods: {
      "fedora-atomic": { method: "preinstalled", note: "Pre-installed on Bazzite" },
      steamos:         { method: "preinstalled", note: "Pre-installed on SteamOS" },
      arch:            { method: "pacman",       pkg: "mangohud" },
      any:             { method: "flatpak",      flatpakId: "org.freedesktop.Platform.VulkanLayer.MangoHud" },
    },
    osSupport: [
      { family: "fedora-atomic", level: "full", note: "Pre-installed on Bazzite" },
      { family: "arch",          level: "full", note: "Available via pacman: mangohud" },
      { family: "steamos",       level: "full", note: "Pre-installed on SteamOS" },
      { family: "debian",        level: "full", note: "Available as Flatpak extension" },
    ],
    gpuSupport: [
      { gpu: "amd",    level: "full", note: "Full support" },
      { gpu: "nvidia", level: "full", note: "Full support" },
      { gpu: "intel",  level: "full", note: "Full support" },
    ],
  },
];

export const CATEGORIES = ["All", ...Array.from(new Set(APPS.map(a => a.category)))];

// ── Helper: resolve best install method for detected OS ───────────────────────
export function getInstallMethod(app, osFamily) {
  if (!app.installMethods) return null;
  return app.installMethods[osFamily]
    || app.installMethods["any"]
    || null;
}

// ── Helper: get OS support entry ──────────────────────────────────────────────
export function getOsSupport(app, osFamily) {
  if (!app.osSupport || !osFamily) return null;
  return app.osSupport.find(o => o.family === osFamily) || null;
}

// ── Helper: get GPU compat entry ──────────────────────────────────────────────
export function getGpuCompat(app, gpuVendor) {
  if (!gpuVendor || !app.gpuSupport) return null;
  return app.gpuSupport.find(g => g.gpu === gpuVendor) || null;
}
