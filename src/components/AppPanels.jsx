// src/components/AppPanels.jsx
// OBSPanel, DiscordPanel, HandbrakePanel — extracted from App.jsx

import React, { useState, useEffect } from "react";
import { Btn, Badge, Spinner, Terminal, Modal, ModalHeader, s } from "./ui.jsx";
import { checkFlatpak, runScript, runScriptArgs } from "../lib/tauri.js";

// ── OBS Studio ────────────────────────────────────────────────────────────────
export function OBSPanel({ onClose, gpuVendor }) {
  const [resolution, setResolution] = useState("1080p");
  const [termLines,  setTermLines]  = useState([]);
  const [busy,       setBusy]       = useState(false);
  const [installed,  setInstalled]  = useState(null);

  const log = (text, type="muted") => setTermLines(p => [...p, {text,type}]);

  useEffect(() => {
    checkFlatpak("com.obsproject.Studio")
      .then(r => setInstalled(r.success)).catch(() => setInstalled(false));
  }, []);

  const encoderLabel = {
    amd:"AMD AMF (hardware)", nvidia:"NVIDIA NVENC (hardware)", intel:"Intel Quick Sync (hardware)",
  }[gpuVendor] || "CPU x264 (software)";

  const resOptions = [
    { value:"720p",  label:"720p  (1280×720)",  note:"Light on GPU · good for most connections" },
    { value:"1080p", label:"1080p (1920×1080)", note:"Standard · recommended for most users" },
    { value:"1440p", label:"1440p (2560×1440)", note:"High quality · needs ~10 Mbps upload" },
    { value:"4k",    label:"4K    (3840×2160)", note:"Max quality · needs ~20 Mbps · 30fps default" },
  ];

  const install = async () => {
    setBusy(true); setTermLines([]);
    log(`Installing OBS Studio + configuring ${resolution} / ${encoderLabel}...`, "info");
    try {
      const r = await runScriptArgs("./scripts/setup-obs.sh",
        ["--resolution", resolution, "--gpu", gpuVendor || "cpu"]);
      if (r.success) log(r.stdout || "✓ OBS installed and configured.", "ok");
      else           log("✗ " + (r.stderr || r.stdout), "err");
    } catch(e) { log("✗ " + e, "err"); }
    const check = await checkFlatpak("com.obsproject.Studio").catch(() => ({success:false}));
    setInstalled(check.success);
    setBusy(false);
  };

  return (
    <Modal onClose={onClose} width={560}>
      <ModalHeader icon="🎥" title="OBS Studio Setup" subtitle="Screen recording & live streaming" onClose={onClose}/>

      <div style={{...s.row, marginBottom:14}}>
        {installed === null  && <Badge type="checking"><Spinner/> Checking…</Badge>}
        {installed === true  && <Badge type="installed">✓ OBS Installed</Badge>}
        {installed === false && <Badge type="missing">Not installed</Badge>}
        <span style={{fontSize:12,color:"var(--muted)"}}>
          Encoder: <strong style={{color:"var(--text)"}}>{encoderLabel}</strong>
        </span>
      </div>

      {gpuVendor && (
        <div style={{background:"rgba(78,166,245,.08)",border:"1px solid rgba(78,166,245,.2)",
          borderRadius:6,padding:"8px 12px",fontSize:12,color:"var(--blue)",marginBottom:14}}>
          ℹ Detected GPU: <strong>{gpuVendor.toUpperCase()}</strong> — will configure
          <strong> {encoderLabel}</strong> automatically.
        </div>
      )}

      <div style={{marginBottom:16}}>
        <div style={{fontWeight:600,marginBottom:8,fontSize:13}}>Stream / record output resolution</div>
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:8}}>
          {resOptions.map(opt => (
            <label key={opt.value} style={{
              ...s.card, cursor:"pointer", padding:"10px 12px",
              borderColor: resolution===opt.value ? "var(--accent)" : "var(--border)",
              background:  resolution===opt.value ? "rgba(224,92,42,.08)" : "var(--surface)",
            }}>
              <div style={{...s.row}}>
                <input type="radio" name="resolution" value={opt.value}
                  checked={resolution===opt.value} onChange={() => setResolution(opt.value)}
                  style={{accentColor:"var(--accent)"}}/>
                <div>
                  <div style={{fontWeight:700,fontSize:13,fontFamily:"var(--mono)"}}>{opt.label}</div>
                  <div style={{fontSize:11,color:"var(--muted)",marginTop:2}}>{opt.note}</div>
                </div>
              </div>
            </label>
          ))}
        </div>
      </div>

      <div style={{fontSize:12,color:"var(--muted)",lineHeight:1.6,marginBottom:14}}>
        <strong style={{color:"var(--text)"}}>Configured automatically:</strong><br/>
        ✓ Hardware encoder · ✓ Correct bitrates · ✓ Webcam + screen capture permissions<br/>
        ✓ PipeWire audio · ✓ Recording folder at ~/Videos/OBS · ✓ MKV format
      </div>

      <Btn onClick={install} disabled={busy}>
        {busy ? <><Spinner/> Configuring…</> : installed ? "Reconfigure" : "Install & configure OBS"}
      </Btn>
      <Terminal lines={termLines}/>
    </Modal>
  );
}

// ── Discord ───────────────────────────────────────────────────────────────────
export function DiscordPanel({ onClose }) {
  const [termLines, setTermLines] = useState([]);
  const [busy,      setBusy]      = useState(false);
  const [installed, setInstalled] = useState(null);

  const log = (text, type="muted") => setTermLines(p => [...p, {text,type}]);

  useEffect(() => {
    checkFlatpak("com.discordapp.Discord")
      .then(r => setInstalled(r.success)).catch(() => setInstalled(false));
  }, []);

  const install = async () => {
    setBusy(true); setTermLines([]);
    log("Installing Discord + configuring Wayland/PipeWire permissions...", "info");
    try {
      const r = await runScript("./scripts/setup-discord.sh");
      if (r.success) log(r.stdout || "✓ Done.", "ok");
      else           log("✗ " + (r.stderr || r.stdout), "err");
    } catch(e) { log("✗ " + e, "err"); }
    const check = await checkFlatpak("com.discordapp.Discord").catch(() => ({success:false}));
    setInstalled(check.success);
    setBusy(false);
  };

  const fixes = [
    ["🔊","Audio",       "PipeWire socket for voice and audio streaming"],
    ["📷","Webcam",      "Device access for camera in video calls"],
    ["🖥", "Screen share","Wayland + XDG portal for screen sharing"],
    ["📁","File access", "Home directory for file attachments"],
    ["🔗","Rich Presence","IPC symlink so games can show Discord activity"],
    ["🎨","Wayland",     "Native Wayland rendering (default since 0.0.94)"],
  ];

  return (
    <Modal onClose={onClose} width={540}>
      <ModalHeader icon="💬" title="Discord Setup"
        subtitle="Voice, video, and text — optimised for Linux/Wayland" onClose={onClose}/>

      <div style={{...s.row, marginBottom:14}}>
        {installed === null  && <Badge type="checking"><Spinner/> Checking…</Badge>}
        {installed === true  && <Badge type="installed">✓ Discord Installed</Badge>}
        {installed === false && <Badge type="missing">Not installed</Badge>}
      </div>

      <div style={{fontWeight:600,fontSize:13,marginBottom:8}}>What this configures:</div>
      <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:6,marginBottom:16}}>
        {fixes.map(([icon,title,desc]) => (
          <div key={title} style={{...s.card,background:"var(--surface2)",padding:"10px 12px"}}>
            <div style={{...s.row,marginBottom:4}}>
              <span>{icon}</span>
              <span style={{fontWeight:600,fontSize:13}}>{title}</span>
            </div>
            <p style={{fontSize:11,color:"var(--muted)",lineHeight:1.5}}>{desc}</p>
          </div>
        ))}
      </div>

      <div style={{background:"rgba(245,197,66,.08)",border:"1px solid rgba(245,197,66,.2)",
        borderRadius:6,padding:"8px 12px",fontSize:12,color:"var(--yellow)",marginBottom:14}}>
        ⚠ After install: Discord → Settings → Voice & Video — confirm your mic and camera.
      </div>

      <Btn onClick={install} disabled={busy}>
        {busy ? <><Spinner/> Configuring…</> : installed ? "Reconfigure permissions" : "Install & configure Discord"}
      </Btn>
      <Terminal lines={termLines}/>
    </Modal>
  );
}


// ── EmuDeck ───────────────────────────────────────────────────────────────────
export function EmuDeckPanel({ onClose }) {
  const [phase,     setPhase]    = useState("install"); // "install" | "configure"
  const [res,       setRes]      = useState("4k");
  const [termLines, setTermLines]= useState([]);
  const [busy,      setBusy]     = useState(false);

  const log = (text, type="muted") => setTermLines(p => [...p, {text, type}]);

  const resOptions = [
    { value:"720p",  label:"720p",  sub:"1280×720",  note:"Light — great for less powerful hardware" },
    { value:"1080p", label:"1080p", sub:"1920×1080", note:"Standard — recommended for most setups" },
    { value:"1440p", label:"1440p", sub:"2560×1440", note:"High quality — good mid-range GPU needed" },
    { value:"4k",    label:"4K",    sub:"3840×2160", note:"Maximum — default, best on OLED/4K display" },
  ];

  const scalingTable = {
    "720p":  { dolphin:"EFBScale=3 (1.5×)", pcsx2:"2×", duck:"3×", ppsspp:"3×", cemu:"1280×720",  ra:"1280×720"  },
    "1080p": { dolphin:"EFBScale=6 (3×)",   pcsx2:"3×", duck:"4×", ppsspp:"4×", cemu:"1920×1080", ra:"1920×1080" },
    "1440p": { dolphin:"EFBScale=7 (4×)",   pcsx2:"4×", duck:"6×", ppsspp:"6×", cemu:"2560×1440", ra:"2560×1440" },
    "4k":    { dolphin:"EFBScale=9 (6×)",   pcsx2:"6×", duck:"9×", ppsspp:"8×", cemu:"3840×2160", ra:"3840×2160" },
  };

  const runInstall = async () => {
    setBusy(true); setTermLines([]);
    log("Installing EmuDeck...", "info");
    try {
      const r = await runScript("./scripts/setup-emudeck.sh");
      (r.stdout || "").split("\n").filter(Boolean).forEach(l => {
        const type = l.startsWith("[OK]") || l.startsWith("✓") ? "ok"
          : l.startsWith("[WARN]") || l.startsWith("⚠") ? "warn"
          : l.startsWith("[ERROR]") || l.startsWith("✗") ? "err"
          : l.startsWith("[INFO]") ? "info" : "muted";
        log(l, type);
      });
      if (r.success) log("✓ Done. Complete the EmuDeck wizard, then use Configure below.", "ok");
      else           log("✗ " + (r.stderr || "Script failed"), "err");
    } catch(e) { log("✗ " + e, "err"); }
    setBusy(false);
  };

  const runConfigure = async () => {
    setBusy(true); setTermLines([]);
    log(`Configuring all emulators at ${res}...`, "info");
    try {
      const r = await runScriptArgs("./scripts/setup-emudeck.sh", ["--configure", "--res", res]);
      (r.stdout || "").split("\n").filter(Boolean).forEach(l => {
        const type = l.startsWith("[OK]") || l.startsWith("✓") ? "ok"
          : l.startsWith("[WARN]") || l.startsWith("⚠") ? "warn"
          : l.startsWith("[ERROR]") || l.startsWith("✗") ? "err"
          : l.startsWith("[INFO]") ? "info" : "muted";
        log(l, type);
      });
      if (r.success) log(`✓ All emulators configured at ${res}.`, "ok");
      else           log("✗ " + (r.stderr || "Script failed"), "err");
    } catch(e) { log("✗ " + e, "err"); }
    setBusy(false);
  };

  const sc = scalingTable[res];

  return (
    <Modal onClose={onClose} width={600}>
      <ModalHeader icon="🕹️" title="EmuDeck Setup"
        subtitle="Retro emulation suite with per-emulator resolution scaling" onClose={onClose}/>

      {/* Phase tabs */}
      <div style={{ display:"flex", gap:8, marginBottom:20,
                    borderBottom:"1px solid var(--border)", paddingBottom:12 }}>
        {[["install","1  Install EmuDeck"],["configure","2  Configure resolution"]].map(([id,label]) => (
          <button key={id} onClick={() => setPhase(id)} style={{
            padding:"7px 16px", borderRadius:6, border:"none", cursor:"pointer",
            fontWeight:600, fontSize:13,
            background: phase===id ? "var(--accent)" : "var(--surface2)",
            color:       phase===id ? "#fff"          : "var(--muted)",
          }}>{label}</button>
        ))}
      </div>

      {/* ── Phase 1: Install ── */}
      {phase === "install" && (
        <div style={{...s.col}}>
          <div style={{fontSize:13, color:"var(--muted)", lineHeight:1.7}}>
            Installs EmuDeck via <code style={{fontFamily:"var(--mono)"}}>ujust install-emudeck</code>
            (Bazzite) or the upstream installer on other distros. A GUI wizard will open — complete it,
            then come back to <strong style={{color:"var(--text)"}}>Step 2</strong> to set resolution.
          </div>
          <div style={{background:"rgba(245,197,66,.08)",border:"1px solid rgba(245,197,66,.2)",
            borderRadius:6, padding:"10px 14px", fontSize:12, color:"var(--yellow)", lineHeight:1.7}}>
            ⚠ After the wizard finishes, <strong>launch each emulator once</strong> so they
            create their config files. Then return here and run Step 2.
          </div>
          <Btn onClick={runInstall} disabled={busy}>
            {busy ? <><Spinner/> Installing…</> : "Install EmuDeck"}
          </Btn>
          <Terminal lines={termLines}/>
        </div>
      )}

      {/* ── Phase 2: Configure resolution ── */}
      {phase === "configure" && (
        <div style={{...s.col}}>
          <div style={{fontWeight:600, fontSize:13, marginBottom:4}}>Choose your target output resolution</div>
          <div style={{fontSize:12, color:"var(--muted)", marginBottom:12, lineHeight:1.6}}>
            Each emulator is configured to upscale internally to this resolution.
            4K is the default — lower it if you have a 1080p or 1440p display, or a less powerful GPU.
          </div>

          <div style={{display:"grid", gridTemplateColumns:"1fr 1fr", gap:8, marginBottom:14}}>
            {resOptions.map(opt => (
              <label key={opt.value} style={{
                ...s.card, cursor:"pointer", padding:"12px 14px",
                borderColor: res===opt.value ? "var(--accent)" : "var(--border)",
                background:  res===opt.value ? "rgba(224,92,42,.07)" : "var(--surface)",
              }}>
                <div style={{display:"flex", alignItems:"center", gap:8, marginBottom:4}}>
                  <input type="radio" name="emudeckRes" value={opt.value}
                    checked={res===opt.value} onChange={() => setRes(opt.value)}
                    style={{accentColor:"var(--accent)"}}/>
                  <span style={{fontWeight:700, fontSize:14}}>{opt.label}</span>
                  <span style={{fontSize:11, color:"var(--muted)", fontFamily:"var(--mono)"}}>{opt.sub}</span>
                </div>
                <div style={{fontSize:11, color:"var(--muted)", marginLeft:22}}>{opt.note}</div>
              </label>
            ))}
          </div>

          <div style={{...s.card, background:"var(--surface2)", marginBottom:4}}>
            <div style={{fontWeight:600, fontSize:12, marginBottom:8}}>
              Upscale values at <span style={{color:"var(--accent2)"}}>{res}</span>:
            </div>
            <div style={{display:"grid", gridTemplateColumns:"130px 1fr", gap:"5px 12px", fontSize:11}}>
              {[
                ["RetroArch",   sc.ra,     "output resolution + CRT-Royale shader"],
                ["Dolphin",     sc.dolphin,"GameCube / Wii (EFBScale)"],
                ["PCSX2",       sc.pcsx2,  "PlayStation 2 (upscale multiplier)"],
                ["DuckStation", sc.duck,   "PlayStation 1 (resolution scale)"],
                ["PPSSPP",      sc.ppsspp, "PSP (rendering resolution)"],
                ["Cemu",        sc.cemu,   "Wii U (render resolution)"],
              ].map(([name, val, note]) => (
                <React.Fragment key={name}>
                  <div style={{color:"var(--text)", fontWeight:600}}>{name}</div>
                  <div style={{color:"var(--muted)"}}>
                    <span style={{fontFamily:"var(--mono)", color:"var(--green)", marginRight:6}}>{val}</span>
                    {note}
                  </div>
                </React.Fragment>
              ))}
            </div>
          </div>

          <div style={{fontSize:11, color:"var(--muted)", lineHeight:1.6}}>
            Emulators not yet launched are skipped automatically.
            Open each missing one once, then click Configure again with the same resolution.
          </div>

          <Btn onClick={runConfigure} disabled={busy}>
            {busy ? <><Spinner/> Configuring…</> : `Configure all emulators at ${res}`}
          </Btn>
          <Terminal lines={termLines}/>
        </div>
      )}
    </Modal>
  );
}

// ── HandBrake ─────────────────────────────────────────────────────────────────
export function HandbrakePanel({ onClose }) {
  const [termLines, setTermLines] = useState([]);
  const [busy,      setBusy]      = useState(false);
  const [installed, setInstalled] = useState(null);

  const log = (text, type="muted") => setTermLines(p => [...p, {text,type}]);

  useEffect(() => {
    checkFlatpak("fr.handbrake.ghb")
      .then(r => setInstalled(r.success)).catch(() => setInstalled(false));
  }, []);

  const install = async () => {
    setBusy(true); setTermLines([]);
    log("Installing HandBrake and importing AV1 presets...", "info");
    try {
      const r = await runScript("./scripts/setup-handbrake.sh");
      (r.stdout || "").split("\n").filter(Boolean).forEach(l => {
        const type = l.includes("[OK]") || l.startsWith("✓") ? "ok"
          : l.includes("[WARN]") || l.startsWith("⚠") ? "warn"
          : l.includes("[ERROR]") || l.startsWith("✗") ? "err"
          : l.includes("[INFO]") || l.startsWith("→") ? "info" : "muted";
        log(l, type);
      });
      if (r.success) log("✓ Done.", "ok");
      else log("✗ " + (r.stderr || "Script failed"), "err");
    } catch(e) { log("✗ " + e, "err"); }
    const check = await checkFlatpak("fr.handbrake.ghb").catch(() => ({success:false}));
    setInstalled(check.success);
    setBusy(false);
  };

  const presets = [
    { name:"(Live) AV1",      rf:16, note:"Live action 4K · qp-scale-compress · film-grain=4" },
    { name:"(Old Live) AV1",  rf:16, note:"Older live action · film-grain=6" },
    { name:"(Animated) AV1",  rf:16, note:"Animation · chroma-qm-min=10 · film-grain=6" },
    { name:"(Anime) AV1",     rf:16, note:"Anime · minimal grain (2)" },
    { name:"(Old Anime) AV1", rf:16, note:"Older anime · heavy grain (8)" },
  ];

  return (
    <Modal onClose={onClose} width={600}>
      <ModalHeader icon="🎞" title="HandBrake Setup"
        subtitle="Video transcoder + SVT-AV1 preset auto-import" onClose={onClose}/>

      <div style={{...s.row, marginBottom:14}}>
        {installed === null  && <Badge type="checking"><Spinner/> Checking…</Badge>}
        {installed === true  && <Badge type="installed">✓ HandBrake installed</Badge>}
        {installed === false && <Badge type="missing">Not installed</Badge>}
      </div>

      <div style={{...s.card, background:"var(--surface2)", marginBottom:14}}>
        <div style={{fontWeight:600, marginBottom:10, fontSize:13}}>Presets that will be imported</div>
        <div style={{display:"grid", gridTemplateColumns:"auto 50px 1fr", gap:"5px 12px", fontSize:12}}>
          <div style={{fontWeight:700,color:"var(--muted)",fontSize:11}}>PRESET</div>
          <div style={{fontWeight:700,color:"var(--muted)",fontSize:11}}>RF</div>
          <div style={{fontWeight:700,color:"var(--muted)",fontSize:11}}>NOTES</div>
          {presets.map(p => (
            <React.Fragment key={p.name}>
              <div style={{fontFamily:"var(--mono)",fontSize:11}}>{p.name}</div>
              <div style={{fontFamily:"var(--mono)",color:"var(--green)",fontWeight:700}}>{p.rf}</div>
              <div style={{color:"var(--muted)"}}>{p.note}</div>
            </React.Fragment>
          ))}
        </div>
      </div>

      <div style={{background:"rgba(78,166,245,.07)",border:"1px solid rgba(78,166,245,.2)",
        borderRadius:6,padding:"10px 14px",fontSize:12,color:"var(--blue)",lineHeight:1.7,marginBottom:14}}>
        <strong style={{color:"var(--text)"}}>Audio: copy all source tracks as-is.</strong><br/>
        All presets use <code style={{fontFamily:"var(--mono)"}}>encoder=copy / select=all</code>.
        Every source track is copied in its original format. No re-encoding.
      </div>

      <Btn onClick={install} disabled={busy}>
        {busy ? <><Spinner/> Installing…</> : installed ? "Reinstall / reimport presets" : "Install HandBrake + import presets"}
      </Btn>
      <Terminal lines={termLines}/>
    </Modal>
  );
}
