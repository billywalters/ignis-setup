// src/components/GeProtonPanel.jsx
import React, { useState, useEffect } from "react";
import { Btn, Badge, Spinner, Terminal, Modal, ModalHeader, s } from "./ui.jsx";
import { geProtonStatus, installGeProton, setGeProtonDefault,
         isSteamRunning } from "../lib/tauri.js";
import { fetchLatestGithubVersionCached } from "../hooks/useInstallLog.js";

export default function GeProtonPanel({ onClose }) {
  const [status,    setStatus]    = useState(null);
  const [latest,    setLatest]    = useState(null);
  const [termLines, setTermLines] = useState([]);
  const [busy,      setBusy]      = useState(false);
  const [scriptDir, setScriptDir] = useState("./scripts");
  const [steamOpen, setSteamOpen] = useState(false); // pre-check result

  const log = (text, type="muted") => setTermLines(p => [...p, {text,type}]);

  const refresh = async () => {
    try {
      const [st, lv] = await Promise.all([
        geProtonStatus(),
        fetchLatestGithubVersionCached("GloriousEggroll/proton-ge-custom"),
      ]);
      setStatus(st);
      setLatest(lv);
    } catch(e) { log("Could not fetch status: " + e, "err"); }
  };

  // Check Steam status on mount and before install
  const checkSteam = async () => {
    try {
      const running = await isSteamRunning();
      setSteamOpen(running);
      return running;
    } catch { return false; }
  };

  useEffect(() => {
    refresh();
    checkSteam();
  }, []);

  const install = async () => {
    const running = await checkSteam();
    if (running) return; // UI already shows the warning — don't proceed

    setBusy(true); setTermLines([]);
    log("Starting GE-Proton install + set-as-default...", "info");
    try {
      const r = await installGeProton(scriptDir);
      if (r.success) {
        log(r.stdout || "✓ Done.", "ok");
        log("", "muted");
        log("Restart Steam to activate GE-Proton as your default.", "info");
      } else {
        log("✗ Failed:\n" + (r.stderr || r.stdout), "err");
      }
    } catch(e) { log("✗ " + e, "err"); }
    await refresh();
    setBusy(false);
  };

  const setDefault = async () => {
    if (!status?.installed_version) return;
    setBusy(true); setTermLines([]);
    log(`Setting ${status.installed_version} as Steam global default...`, "info");
    try {
      const r = await setGeProtonDefault(status.installed_version);
      log(r.success ? "✓ " + r.stdout : "✗ " + r.stderr, r.success ? "ok" : "err");
      if (r.success) log("Restart Steam to apply the change.", "info");
    } catch(e) { log("✗ " + e, "err"); }
    await refresh();
    setBusy(false);
  };

  const needsUpdate = status?.installed_version && latest &&
    status.installed_version !== latest.replace(/^v/, "");

  return (
    <Modal onClose={onClose} width={580}>
      <ModalHeader icon="🧪" title="GE-Proton Manager"
        subtitle="Install, update, and set as Steam's global default" onClose={onClose}/>

      {/* Steam is open — friendly blocker */}
      {steamOpen && (
        <div style={{ background:"rgba(255,95,95,.08)", border:"1px solid rgba(255,95,95,.3)",
                      borderRadius:6, padding:"12px 14px", marginBottom:14 }}>
          <div style={{ fontWeight:700, color:"var(--red)", marginBottom:4 }}>⚠ Steam is currently open</div>
          <p style={{ fontSize:12, color:"var(--muted)", lineHeight:1.6, marginBottom:10 }}>
            Steam must be fully closed before GE-Proton can be installed or set as default.
            Right-click the Steam icon in your taskbar and choose <strong>Exit</strong>, then click Refresh below.
          </p>
          <Btn variant="ghost" small onClick={checkSteam}>⟳ Check again</Btn>
        </div>
      )}

      {/* Status tiles */}
      <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:10, marginBottom:16 }}>
        {[
          ["Installed",       status?.installed_version || "—", status?.installed_version ? "var(--green)" : "var(--muted)"],
          ["Steam default",   status?.steam_default     || "—", status?.is_default        ? "var(--green)" : "var(--yellow)"],
          ["Latest on GitHub", latest || "—",                   "var(--blue)"],
        ].map(([label, value, colour]) => (
          <div key={label} style={{ ...s.card, background:"var(--surface2)", textAlign:"center" }}>
            <div style={{ fontSize:11, color:"var(--muted)", marginBottom:4 }}>{label}</div>
            <div style={{ fontSize:12, fontFamily:"var(--mono)", color:colour, fontWeight:700,
                          wordBreak:"break-all" }}>{value}</div>
          </div>
        ))}
      </div>

      {/* Contextual alerts */}
      {status && !status.is_default && status.installed_version && (
        <div style={{ background:"rgba(245,197,66,.1)", border:"1px solid rgba(245,197,66,.3)",
                      borderRadius:6, padding:"8px 12px", fontSize:12, color:"var(--yellow)", marginBottom:12 }}>
          ⚠ GE-Proton is installed but <strong>{status.steam_default || "something else"}</strong> is
          set as the Steam default. Use "Set as default" below to fix this.
        </div>
      )}
      {needsUpdate && !steamOpen && (
        <div style={{ background:"rgba(78,166,245,.1)", border:"1px solid rgba(78,166,245,.3)",
                      borderRadius:6, padding:"8px 12px", fontSize:12, color:"var(--blue)", marginBottom:12 }}>
          ⬆ Update available: {status.installed_version} → {latest}. Run "Install / update" to get it.
        </div>
      )}
      {status?.is_default && !needsUpdate && (
        <div style={{ background:"rgba(61,220,132,.1)", border:"1px solid rgba(61,220,132,.3)",
                      borderRadius:6, padding:"8px 12px", fontSize:12, color:"var(--green)", marginBottom:12 }}>
          ✓ You're on the latest GE-Proton and it's your Steam default. Nothing to do.
        </div>
      )}

      <div style={{ marginBottom:14 }}>
        <div style={s.label}>Scripts folder path</div>
        <input style={s.input} value={scriptDir} onChange={e => setScriptDir(e.target.value)}/>
        <div style={{ fontSize:11, color:"var(--muted)", marginTop:3 }}>
          Default is <code style={{ fontFamily:"var(--mono)" }}>./scripts</code> relative to where you run the app.
        </div>
      </div>

      <div style={{ ...s.row, marginBottom:4 }}>
        <Btn onClick={install} disabled={busy || steamOpen}>
          {busy ? <><Spinner/> Working…</> : needsUpdate ? `⬆ Update to ${latest}` : "Install / update GE-Proton"}
        </Btn>
        {status?.installed_version && !status.is_default && !steamOpen && (
          <Btn variant="success" onClick={setDefault} disabled={busy}>
            Set {status.installed_version} as default
          </Btn>
        )}
        <Btn variant="ghost" onClick={() => { refresh(); checkSteam(); }} disabled={busy} small>⟳</Btn>
      </div>

      <p style={{ fontSize:11, color:"var(--muted)", marginTop:6, lineHeight:1.6 }}>
        Games with per-game Proton overrides in Steam Properties are not affected by the global default.
      </p>

      <Terminal lines={termLines}/>
    </Modal>
  );
}
