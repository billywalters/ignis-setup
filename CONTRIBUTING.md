# Contributing to Ignis

Thank you for your interest in contributing! This document explains how to get
involved, what to work on, and how to submit changes.

---

## Ways to contribute

- **File a bug report** — use the [Bug report](.github/ISSUE_TEMPLATE/bug_report.md) template
- **Suggest a feature or new app** — use the [Feature request](.github/ISSUE_TEMPLATE/feature_request.md) template
- **Report OS compatibility** — use the [OS compatibility report](.github/ISSUE_TEMPLATE/os_compat_report.md) template
- **Submit a pull request** — see the workflow below

---

## Development setup

### Prerequisites

- Linux (Bazzite, CachyOS, Ubuntu 22.04+, or SteamOS)
- Node.js ≥ 18, npm ≥ 9
- Rust stable toolchain (`rustup install stable`)
- WebKitGTK 4.1 dev libraries (see `build.sh` for the install command per distro)

### Running locally

```bash
git clone https://github.com/billywalters/ignis-setup.git
cd ignis-setup
npm install
npm run tauri dev      # hot-reload dev mode
```

### Building a release binary

```bash
bash build.sh          # handles all deps automatically
# Output: src-tauri/target/release/bundle/appimage/*.AppImage
```

---

## Project structure

```
src/                    React frontend
  App.jsx               Main orchestrator
  components/           Reusable UI components
  pages/                Page-level components
  context/              React contexts
  lib/                  Utility modules (tauri IPC, network validation, apps catalogue)
  hooks/                Custom React hooks
src-tauri/src/          Rust backend
  lib.rs                Module declarations + invoke handler
  system.rs             OS/hardware detection
  installs.rs           Package manager commands
  network.rs            nmcli, NAS mount, fstab
  jellyfin.rs           Jellyfin Podman Quadlet
  ge_proton.rs          GE-Proton install + Steam default
  install_log.rs        Persistent install log
scripts/                Standalone bash setup scripts
  _common.sh            OS detection + shared helpers (sourced by all scripts)
```

---

## Adding a new app to the catalogue

1. Add an entry to `src/lib/apps.js` with:
   - `installMethods` — one key per OS family (`fedora-atomic`, `arch`, `steamos`, `debian`, `any`)
   - `osSupport` — level (`full`/`partial`/`unavailable`) + plain-English note per OS family
   - `gpuSupport` — level per GPU vendor if relevant
2. Optionally add a script to `scripts/` — source `_common.sh` and use `pkg_install` / `dry_run_cmd`
3. If the app needs a configuration panel, add a component to `src/components/`

---

## Pull request guidelines

- **One concern per PR.** A PR that adds a new app, fixes a bug, and refactors a module is three PRs.
- **Shell scripts must pass `bash -n` and `shellcheck --severity=error`** — the CI will catch failures.
- **Rust code must pass `cargo clippy -- -D warnings`** — the CI will catch failures.
- **Frontend must build cleanly with `npm run build`** — the CI will catch failures.
- **No hardcoded paths, usernames, or machine-specific values.** The tool must work on any system.
- **Test on at least one supported OS before opening a PR.**
- Add a brief description of what changed and why to the PR body.

---

## Commit style

No strict convention enforced, but please be descriptive:

```
Add Heroic Launcher to app catalogue
Fix dry_run_cmd not wrapping apt-get install in setup-discord.sh
Refactor NetworkPage into src/pages/NetworkPage.jsx
```

---

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
