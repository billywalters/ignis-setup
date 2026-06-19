// src/hooks/useInstallLog.js
// Manages a persistent install log at ~/.local/share/ignis-setup/install-log.json
// Also provides GitHub version caching with a 10-minute TTL to avoid API rate limits.

import { invoke } from "@tauri-apps/api/core";

// ── Version cache (session-level, 10 min TTL) ─────────────────────────────────
const VERSION_CACHE = new Map(); // repo → { version, fetchedAt }
const CACHE_TTL_MS  = 10 * 60 * 1000; // 10 minutes

export async function fetchLatestGithubVersionCached(repo) {
  if (!repo) return null;

  const cached = VERSION_CACHE.get(repo);
  if (cached && (Date.now() - cached.fetchedAt) < CACHE_TTL_MS) {
    return cached.version;
  }

  try {
    const r = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
      headers: { "Accept": "application/vnd.github+json" },
    });
    if (!r.ok) return cached?.version || null; // return stale if available
    const d = await r.json();
    const version = d.tag_name || d.name || null;
    VERSION_CACHE.set(repo, { version, fetchedAt: Date.now() });
    return version;
  } catch {
    return cached?.version || null;
  }
}

// Stagger multiple GitHub API calls to stay well under the 60/hour unauthenticated limit
export async function fetchVersionsStaggered(apps) {
  const results = {};
  const STAGGER_MS = 150; // 150ms between calls → max ~6/sec, well under limit

  for (let i = 0; i < apps.length; i++) {
    const app = apps[i];
    if (app.githubRepo) {
      results[app.id] = await fetchLatestGithubVersionCached(app.githubRepo);
      if (i < apps.length - 1) {
        await new Promise(r => setTimeout(r, STAGGER_MS));
      }
    } else {
      results[app.id] = null;
    }
  }
  return results;
}

// ── Install log (written via Rust backend) ────────────────────────────────────
// Log format: { appId: { name, installedAt, method, success, version } }

const LOG_PATH_CMD = "get_install_log_path"; // Tauri command
const WRITE_LOG_CMD = "write_install_log";
const READ_LOG_CMD  = "read_install_log";

export async function readInstallLog() {
  try {
    const r = await invoke(READ_LOG_CMD);
    if (r.success && r.stdout) {
      return JSON.parse(r.stdout);
    }
  } catch {}
  return {};
}

export async function writeInstallLog(log) {
  try {
    await invoke(WRITE_LOG_CMD, { content: JSON.stringify(log, null, 2) });
  } catch (e) {
    console.warn("Could not write install log:", e);
  }
}

export async function logInstall(appId, appName, method, success, version = null) {
  const log = await readInstallLog();
  log[appId] = {
    name:        appName,
    installedAt: new Date().toISOString(),
    method,
    success,
    version,
  };
  await writeInstallLog(log);
  return log;
}

// ── First-run detection ───────────────────────────────────────────────────────
export async function isFirstRun() {
  const log = await readInstallLog();
  return Object.keys(log).length === 0;
}
