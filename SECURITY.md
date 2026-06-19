# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Older releases | ❌ — please update |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in Ignis, please report it
privately through one of these channels:

- **GitHub private vulnerability reporting** — go to the
  [Security tab](https://github.com/billywalters/ignis-setup/security/advisories/new)
  of this repository and click "Report a vulnerability"
- **Email** — contact the maintainer directly (see GitHub profile)

Please include:

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- The version of Ignis affected
- Your OS and distro version

We will acknowledge your report within 48 hours and aim to release a fix within
14 days for confirmed vulnerabilities.

## Scope

### In scope

- The Tauri application itself (Rust backend, React frontend)
- The setup scripts in `scripts/`
- Privilege escalation via `pkexec` / `polkit`
- Insecure shell command construction in scripts

### Out of scope

- Vulnerabilities in third-party apps that Ignis installs
  (report those to the upstream projects)
- Social engineering attacks
- Physical access attacks

## Security design notes

- **Privilege escalation** — commands requiring root use `pkexec` (polkit),
  which shows a GUI password prompt. No `sudo` is ever called silently.
- **Shell injection** — script arguments are passed as arrays, not interpolated
  into strings, to prevent injection.
- **CSP** — the Tauri WebView has a Content Security Policy that restricts
  external connections to `https://api.github.com` only.
- **No telemetry** — Ignis collects no usage data.
