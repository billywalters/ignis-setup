// src/components/ui.jsx
// Shared, stateless UI primitives used across all pages and panels.

import React, { useRef, useEffect, useState } from "react";
import { getGpuCompat, getOsSupport } from "../lib/apps.js";

// ── Style tokens (mirrors styles.css custom properties) ──────────────────────
export const s = {
  shell:       { display:"flex", flexDirection:"column", height:"100vh" },
  topbar:      { background:"var(--surface)", borderBottom:"1px solid var(--border)",
                 padding:"12px 20px", display:"flex", alignItems:"center", gap:12, flexShrink:0 },
  logoBox:     { width:32, height:32, borderRadius:8, display:"flex", alignItems:"center",
                 justifyContent:"center", fontSize:18, flexShrink:0,
                 background:"linear-gradient(135deg,#e05c2a,#c0391a)" },
  body:        { display:"flex", flex:1, overflow:"hidden" },
  sidebar:     { width:210, flexShrink:0, background:"var(--surface)",
                 borderRight:"1px solid var(--border)", padding:"14px 10px",
                 display:"flex", flexDirection:"column", gap:3, overflowY:"auto" },
  sideSection: { fontSize:10, fontWeight:700, letterSpacing:".12em", color:"var(--muted)",
                 textTransform:"uppercase", padding:"10px 10px 4px" },
  main:        { flex:1, overflowY:"auto", padding:22 },
  card:        { background:"var(--surface)", border:"1px solid var(--border)",
                 borderRadius:"var(--radius)", padding:16 },
  grid:        { display:"grid", gridTemplateColumns:"repeat(auto-fill,minmax(330px,1fr))", gap:12 },
  row:         { display:"flex", alignItems:"center", gap:8 },
  col:         { display:"flex", flexDirection:"column", gap:8 },
  label:       { fontSize:11, color:"var(--muted)", marginBottom:2 },
  input:       { background:"var(--surface2)", border:"1px solid var(--border)", borderRadius:6,
                 color:"var(--text)", padding:"7px 10px", fontSize:13, width:"100%", outline:"none" },
  select:      { background:"var(--surface2)", border:"1px solid var(--border)", borderRadius:6,
                 color:"var(--text)", padding:"7px 10px", fontSize:13, width:"100%", outline:"none" },
  mono:        { fontFamily:"var(--mono)", fontSize:11 },
  terminal:    { background:"#090c12", border:"1px solid var(--border)", borderRadius:"var(--radius)",
                 padding:"12px 14px", fontFamily:"var(--mono)", fontSize:12, lineHeight:1.7,
                 maxHeight:260, overflowY:"auto", whiteSpace:"pre-wrap", wordBreak:"break-all",
                 marginTop:14 },
};

// ── Button ────────────────────────────────────────────────────────────────────
export function Btn({ children, onClick, disabled, variant="primary", small=false, style={} }) {
  const base = {
    border:"none", borderRadius:6, cursor:"pointer", fontWeight:600,
    transition:"background .15s, border-color .15s",
    padding: small ? "5px 11px" : "8px 16px",
    fontSize: small ? 12 : 13,
    ...style,
  };
  const variants = {
    primary: { background:"var(--accent)", color:"#fff" },
    ghost:   { background:"transparent", border:"1px solid var(--border)", color:"var(--muted)" },
    danger:  { background:"rgba(255,95,95,.15)", border:"1px solid rgba(255,95,95,.3)", color:"var(--red)" },
    success: { background:"rgba(61,220,132,.15)", border:"1px solid rgba(61,220,132,.3)", color:"var(--green)" },
  };
  return (
    <button
      style={{ ...base, ...variants[variant], opacity:disabled?.4:1, cursor:disabled?"default":"pointer" }}
      onClick={disabled ? undefined : onClick}
    >
      {children}
    </button>
  );
}

// ── Badge ─────────────────────────────────────────────────────────────────────
export function Badge({ type, children }) {
  const styles = {
    installed: { background:"rgba(61,220,132,.12)",  color:"var(--green)",  border:"1px solid rgba(61,220,132,.3)" },
    update:    { background:"rgba(245,197,66,.12)",  color:"var(--yellow)", border:"1px solid rgba(245,197,66,.3)" },
    latest:    { background:"rgba(78,166,245,.12)",  color:"var(--blue)",   border:"1px solid rgba(78,166,245,.3)" },
    missing:   { background:"rgba(255,95,95,.1)",    color:"var(--red)",    border:"1px solid rgba(255,95,95,.3)"  },
    checking:  { background:"rgba(122,132,160,.1)",  color:"var(--muted)",  border:"1px solid var(--border)"       },
    pre:       { background:"rgba(78,166,245,.12)",  color:"var(--blue)",   border:"1px solid rgba(78,166,245,.3)" },
  };
  return (
    <span style={{ display:"inline-flex", alignItems:"center", gap:4, padding:"3px 8px",
                   borderRadius:4, fontSize:11, fontFamily:"var(--mono)", fontWeight:600,
                   ...styles[type] }}>
      {children}
    </span>
  );
}

// ── NavBtn ────────────────────────────────────────────────────────────────────
export function NavBtn({ active, onClick, icon, label, count }) {
  return (
    <button onClick={onClick}
      style={{ background: active ? "rgba(224,92,42,.15)" : "transparent",
               color: active ? "var(--accent2)" : "var(--muted)",
               border:"none", width:"100%", textAlign:"left", padding:"8px 10px",
               borderRadius:6, cursor:"pointer", fontSize:13,
               display:"flex", alignItems:"center", gap:8, transition:"background .1s" }}>
      <span>{icon}</span>
      <span style={{flex:1}}>{label}</span>
      {count != null && <span style={{fontSize:11,color:"var(--muted)"}}>{count}</span>}
    </button>
  );
}

// ── Terminal ──────────────────────────────────────────────────────────────────
export function Terminal({ lines }) {
  const ref = useRef(null);
  useEffect(() => { if (ref.current) ref.current.scrollTop = ref.current.scrollHeight; }, [lines]);
  if (!lines.length) return null;
  const colours = { ok:"var(--green)", err:"var(--red)", warn:"var(--yellow)", info:"var(--blue)", muted:"var(--muted)" };
  return (
    <div style={s.terminal} ref={ref}>
      {lines.map((l,i) => <div key={i} style={{color:colours[l.type]||colours.muted}}>{l.text}</div>)}
    </div>
  );
}

// ── Spinner ───────────────────────────────────────────────────────────────────
if (!document.querySelector("#bm-spin")) {
  const st = document.createElement("style");
  st.id = "bm-spin";
  st.textContent = "@keyframes spin{to{transform:rotate(360deg)}}";
  document.head.appendChild(st);
}
export function Spinner() {
  return <span style={{ display:"inline-block", width:10, height:10,
    border:"2px solid var(--border)", borderTop:"2px solid var(--accent)",
    borderRadius:"50%", animation:"spin .7s linear infinite" }}/>;
}

// ── GPU compat badge ──────────────────────────────────────────────────────────
export function GpuCompatBadge({ app, gpuVendor }) {
  const [tip, setTip] = useState(false);
  if (!gpuVendor || gpuVendor === "unknown") return null;
  const compat = getGpuCompat(app, gpuVendor);
  if (!compat) return null;
  const cfg = {
    full:    { bg:"rgba(61,220,132,.12)", border:"rgba(61,220,132,.35)", color:"var(--green)",  icon:"✓" },
    partial: { bg:"rgba(245,197,66,.12)", border:"rgba(245,197,66,.35)", color:"var(--yellow)", icon:"⚠" },
    none:    { bg:"rgba(255,95,95,.10)",  border:"rgba(255,95,95,.35)",  color:"var(--red)",    icon:"✗" },
  }[compat.level] || {};
  const label = { full:"GPU ✓", partial:"GPU ⚠", none:"GPU ✗" }[compat.level];
  return (
    <span style={{position:"relative",display:"inline-flex"}}
          onMouseEnter={()=>setTip(true)} onMouseLeave={()=>setTip(false)}>
      <span style={{ display:"inline-flex", alignItems:"center", gap:3, padding:"2px 7px",
                     borderRadius:4, fontSize:11, fontWeight:700, cursor:"default",
                     background:cfg.bg, border:`1px solid ${cfg.border}`, color:cfg.color }}>
        {label}
      </span>
      {tip && (
        <span style={{ position:"absolute", bottom:"calc(100% + 5px)", left:0, zIndex:50,
                       background:"#1f2436", border:"1px solid var(--border)", borderRadius:6,
                       padding:"6px 10px", fontSize:11, color:"var(--text)", whiteSpace:"normal",
                       lineHeight:1.5, boxShadow:"0 4px 12px rgba(0,0,0,.5)", pointerEvents:"none",
                       maxWidth:260 }}>
          {compat.note}
        </span>
      )}
    </span>
  );
}

// ── OS support badge ──────────────────────────────────────────────────────────
export function OsSupportBadge({ app, osFamily }) {
  const [tip, setTip] = useState(false);
  if (!osFamily) return null;
  const support = getOsSupport(app, osFamily);
  if (!support) return null;
  const cfg = {
    full:        { bg:"rgba(61,220,132,.12)", border:"rgba(61,220,132,.35)", color:"var(--green)",  label:"OS ✓" },
    partial:     { bg:"rgba(245,197,66,.12)", border:"rgba(245,197,66,.35)", color:"var(--yellow)", label:"OS ⚠" },
    unavailable: { bg:"rgba(255,95,95,.10)",  border:"rgba(255,95,95,.35)",  color:"var(--red)",    label:"OS ✗" },
  }[support.level] || {};
  return (
    <span style={{position:"relative",display:"inline-flex"}}
          onMouseEnter={()=>setTip(true)} onMouseLeave={()=>setTip(false)}>
      <span style={{ display:"inline-flex", alignItems:"center", gap:3, padding:"2px 7px",
                     borderRadius:4, fontSize:11, fontWeight:700, cursor:"default",
                     background:cfg.bg, border:`1px solid ${cfg.border}`, color:cfg.color }}>
        {cfg.label}
      </span>
      {tip && (
        <span style={{ position:"absolute", bottom:"calc(100% + 5px)", left:0, zIndex:51,
                       background:"#1f2436", border:"1px solid var(--border)", borderRadius:6,
                       padding:"6px 10px", fontSize:11, color:"var(--text)", whiteSpace:"normal",
                       lineHeight:1.5, boxShadow:"0 4px 12px rgba(0,0,0,.5)", pointerEvents:"none",
                       maxWidth:260 }}>
          {support.note}
        </span>
      )}
    </span>
  );
}

// ── Modal wrapper ─────────────────────────────────────────────────────────────
export function Modal({ onClose, width=560, children }) {
  return (
    <div style={{ position:"fixed", inset:0, background:"rgba(0,0,0,.65)",
                  display:"flex", alignItems:"center", justifyContent:"center", zIndex:100 }}
         onClick={e => e.target===e.currentTarget && onClose()}>
      <div style={{ ...s.card, width, maxHeight:"82vh", overflowY:"auto", position:"relative" }}>
        {children}
      </div>
    </div>
  );
}

// ── Modal header row ──────────────────────────────────────────────────────────
export function ModalHeader({ icon, title, subtitle, onClose }) {
  return (
    <div style={{ display:"flex", alignItems:"flex-start", gap:12, marginBottom:16 }}>
      <span style={{fontSize:22}}>{icon}</span>
      <div style={{flex:1}}>
        <div style={{fontWeight:700, fontSize:16}}>{title}</div>
        {subtitle && <div style={{fontSize:12, color:"var(--muted)"}}>{subtitle}</div>}
      </div>
      <button onClick={onClose}
        style={{background:"none",border:"none",color:"var(--muted)",fontSize:18,cursor:"pointer"}}>✕</button>
    </div>
  );
}
