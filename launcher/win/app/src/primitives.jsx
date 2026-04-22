/* global React */
const { useState, useEffect, useRef } = React;

/* ---------- Brand marks ---------- */
function EnzoMark({ size = 36 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 999,
      background: "radial-gradient(circle at 30% 25%, #8fff10 0%, var(--venom) 45%, #4a9500 100%)",
      display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
      boxShadow: "0 0 0 1px rgba(122,242,1,0.35), 0 6px 14px rgba(0,0,0,0.5)",
      position: "relative", overflow: "hidden"
    }}>
      <div style={{
        fontFamily: "Nunito, sans-serif", fontWeight: 900,
        fontSize: size * 0.52, color: "#0f1619", lineHeight: 1,
        letterSpacing: "-0.04em"
      }}>E</div>
    </div>
  );
}

function UserAvatar({ name = "RC", size = 32, accent = "#e63946" }) {
  const initials = name.split(" ").map(w => w[0]).slice(0, 2).join("").toUpperCase();
  return (
    <div style={{
      width: size, height: size, borderRadius: 999,
      background: `linear-gradient(135deg, ${accent} 0%, #7e1a22 100%)`,
      display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
      color: "#fff", fontFamily: "Nunito, sans-serif", fontWeight: 800,
      fontSize: size * 0.4, letterSpacing: "-0.02em",
      boxShadow: "0 2px 6px rgba(0,0,0,0.4)"
    }}>{initials}</div>
  );
}

/* ---------- Checker band (horizontal pattern) ---------- */
function CheckerBand({ rows = 2, size = 8, style = {} }) {
  const cells = [];
  const cols = 80;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      cells.push(
        <div key={`${r}-${c}`} style={{
          width: size, height: size,
          background: (r + c) % 2 === 0 ? "#fff" : "#0a0d10"
        }}/>
      );
    }
  }
  return (
    <div style={{
      display: "grid",
      gridTemplateColumns: `repeat(${cols}, ${size}px)`,
      gridAutoRows: `${size}px`,
      overflow: "hidden",
      ...style
    }}>{cells}</div>
  );
}

/* ---------- Typing dots ---------- */
function TypingDots() {
  return (
    <div style={{ display: "inline-flex", gap: 4, padding: "6px 2px", alignItems: "center" }}>
      {[0, 0.15, 0.3].map((d, i) => (
        <div key={i} style={{
          width: 7, height: 7, borderRadius: 999, background: "var(--venom)",
          animation: `enzoBlink 1.2s infinite ${d}s`
        }}/>
      ))}
    </div>
  );
}

/* ---------- Icons (inline SVG, 1.75 stroke) ---------- */
const iconProps = {
  width: 18, height: 18, viewBox: "0 0 24 24", fill: "none",
  stroke: "currentColor", strokeWidth: 1.75, strokeLinecap: "round", strokeLinejoin: "round"
};
const Icons = {
  plus: () => <svg {...iconProps}><path d="M12 5v14M5 12h14"/></svg>,
  send: () => <svg {...iconProps}><path d="M22 2 11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg>,
  search: () => <svg {...iconProps}><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>,
  settings: () => <svg {...iconProps}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c0 .66.39 1.25 1 1.51H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>,
  trash: () => <svg {...iconProps}><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M6 6l1 14a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-14"/></svg>,
  pin: () => <svg {...iconProps}><path d="M12 2v7l4 4v3H8v-3l4-4V2zM12 16v6"/></svg>,
  edit: () => <svg {...iconProps}><path d="M12 20h9M16.5 3.5a2.12 2.12 0 1 1 3 3L7 19l-4 1 1-4 12.5-12.5z"/></svg>,
  copy: () => <svg {...iconProps}><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>,
  thumbsUp: () => <svg {...iconProps}><path d="M7 10v12M15 5.88 14 10h5.83a2 2 0 0 1 1.96 2.4l-1.67 8A2 2 0 0 1 18.17 22H7V10l5.84-7.84A2 2 0 0 1 15 5.88z"/></svg>,
  thumbsDown: () => <svg {...iconProps}><path d="M17 14V2M9 18.12 10 14H4.17a2 2 0 0 1-1.96-2.4l1.67-8A2 2 0 0 1 5.83 2H17v12l-5.84 7.84A2 2 0 0 1 9 18.12z"/></svg>,
  refresh: () => <svg {...iconProps}><path d="M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5"/></svg>,
  sparkles: () => <svg {...iconProps}><path d="M12 3l1.9 5.8L20 10l-5.8 1.9L12 18l-2.1-6.1L4 10l6.1-1.2L12 3zM19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15zM5 16l.6 1.4L7 18l-1.4.6L5 20l-.6-1.4L3 18l1.4-.6L5 16z"/></svg>,
  attach: () => <svg {...iconProps}><path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>,
  mic: () => <svg {...iconProps}><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3"/></svg>,
  menu: () => <svg {...iconProps}><path d="M3 12h18M3 6h18M3 18h18"/></svg>,
  close: () => <svg {...iconProps}><path d="M18 6 6 18M6 6l12 12"/></svg>,
  chevron: () => <svg {...iconProps}><path d="m9 18 6-6-6-6"/></svg>,
  package: () => <svg {...iconProps}><path d="M16.5 9.4 7.5 4.21M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16zM3.27 6.96 12 12.01l8.73-5.05M12 22.08V12"/></svg>,
  flag: () => <svg {...iconProps}><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22V15"/></svg>,
  trophy: () => <svg {...iconProps}><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6M18 9h1.5a2.5 2.5 0 0 0 0-5H18M4 22h16M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22M18 2H6v7a6 6 0 0 0 12 0V2z"/></svg>,
  zap: () => <svg {...iconProps}><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>,
  chart: () => <svg {...iconProps}><path d="M3 3v18h18M7 16l4-4 4 4 6-6"/></svg>,
  users: () => <svg {...iconProps}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/><circle cx="9" cy="7" r="4"/></svg>,
  folder: () => <svg {...iconProps}><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>,
  more: () => <svg {...iconProps}><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>,
  archive: () => <svg {...iconProps}><rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8M10 12h4"/></svg>,
  logout: () => <svg {...iconProps}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>,
  wrench: () => <svg {...iconProps}><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>,
  book: () => <svg {...iconProps}><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>,
  check: () => <svg {...iconProps}><path d="M20 6 9 17l-5-5"/></svg>,
};

/* ---------- Product / result card (inline) ---------- */
function ProductRef({ p }) {
  return (
    <div style={{
      marginTop: 10, background: "rgba(10,13,16,0.65)",
      border: "1px solid var(--steel)", borderRadius: 8,
      display: "flex", alignItems: "stretch", gap: 0, overflow: "hidden",
      transition: "border-color var(--dur-sm) var(--ease)"
    }}
    onMouseEnter={e => e.currentTarget.style.borderColor = "var(--venom)"}
    onMouseLeave={e => e.currentTarget.style.borderColor = "var(--steel)"}
    >
      <div style={{
        width: 88, minHeight: 72,
        background: `
          linear-gradient(135deg, rgba(122,242,1,0.12) 0%, transparent 60%),
          repeating-linear-gradient(45deg, #1a1f22 0 6px, #242a2e 6px 12px)
        `,
        display: "flex", alignItems: "center", justifyContent: "center",
        borderRight: "1px solid var(--steel)", flexShrink: 0
      }}>
        <svg width="42" height="22" viewBox="0 0 42 22" fill="none">
          <path d="M2 14 L8 6 L20 6 L26 2 L36 2 L40 8 L40 14 Z" fill="var(--venom)" opacity="0.85"/>
          <circle cx="12" cy="16" r="4" fill="#0a0d10" stroke="var(--venom)" strokeWidth="1.5"/>
          <circle cx="32" cy="16" r="4" fill="#0a0d10" stroke="var(--venom)" strokeWidth="1.5"/>
        </svg>
      </div>
      <div style={{ flex: 1, padding: "10px 12px", display: "flex", flexDirection: "column", justifyContent: "center", gap: 4 }}>
        <div style={{ fontFamily: "Nunito, sans-serif", fontWeight: 800, fontSize: 13, color: "var(--bone)", letterSpacing: "-0.01em" }}>{p.name}</div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ color: "var(--venom)", fontWeight: 800, fontSize: 13, fontVariantNumeric: "tabular-nums" }}>${p.price.toFixed(2)}</span>
          {p.sku && <span style={{ color: "var(--fg3)", fontSize: 11, fontFamily: "JetBrains Mono, monospace" }}>{p.sku}</span>}
          {p.stock && <span style={{
            background: p.stock === "In Stock" ? "rgba(122,242,1,0.12)" : "rgba(242,193,78,0.15)",
            color: p.stock === "In Stock" ? "var(--venom)" : "var(--flag-yellow)",
            fontSize: 10, fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase",
            padding: "2px 6px", borderRadius: 3
          }}>{p.stock}</span>}
        </div>
      </div>
      <button style={{
        margin: 8, background: "transparent", border: "1px solid var(--steel)",
        color: "var(--bone)", padding: "0 14px", borderRadius: 6,
        fontFamily: "Nunito, sans-serif", fontWeight: 800, fontSize: 11,
        letterSpacing: "0.12em", cursor: "pointer", textTransform: "uppercase",
        transition: "all var(--dur-sm) var(--ease)"
      }}
      onMouseEnter={e => { e.currentTarget.style.background = "var(--venom)"; e.currentTarget.style.color = "#0a0d10"; e.currentTarget.style.borderColor = "var(--venom)"; }}
      onMouseLeave={e => { e.currentTarget.style.background = "transparent"; e.currentTarget.style.color = "var(--bone)"; e.currentTarget.style.borderColor = "var(--steel)"; }}
      >View</button>
    </div>
  );
}

/* ---------- Order / data ref card (for biz queries) ---------- */
function OrderRef({ o }) {
  return (
    <div style={{
      marginTop: 10, background: "rgba(10,13,16,0.65)", border: "1px solid var(--steel)",
      borderRadius: 8, padding: 12, display: "flex", flexDirection: "column", gap: 8
    }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
        <div style={{ fontFamily: "JetBrains Mono, monospace", fontSize: 12, color: "var(--fg2)", letterSpacing: "0.04em" }}>{o.id}</div>
        <span style={{
          background: o.status === "Shipped" ? "rgba(122,242,1,0.14)" : o.status === "Pending" ? "rgba(242,193,78,0.15)" : "rgba(230,57,70,0.15)",
          color: o.status === "Shipped" ? "var(--venom)" : o.status === "Pending" ? "var(--flag-yellow)" : "var(--race-red)",
          fontSize: 10, fontWeight: 800, letterSpacing: "0.1em", textTransform: "uppercase",
          padding: "3px 8px", borderRadius: 3
        }}>{o.status}</span>
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
        <div>
          <div style={{ fontSize: 13, fontWeight: 700, color: "var(--bone)" }}>{o.customer}</div>
          <div style={{ fontSize: 12, color: "var(--fg3)", marginTop: 2 }}>{o.items} · ${o.total.toFixed(2)}</div>
        </div>
        <div style={{ fontSize: 11, color: "var(--fg3)", fontFamily: "JetBrains Mono, monospace" }}>{o.date}</div>
      </div>
    </div>
  );
}

/* ---------- Stat grid (for business answers) ---------- */
function StatGrid({ stats }) {
  return (
    <div style={{
      marginTop: 10, display: "grid",
      gridTemplateColumns: `repeat(${Math.min(stats.length, 3)}, 1fr)`,
      gap: 8,
      background: "rgba(10,13,16,0.65)", border: "1px solid var(--steel)",
      borderRadius: 8, padding: 12
    }}>
      {stats.map((s, i) => (
        <div key={i} style={{
          display: "flex", flexDirection: "column", gap: 2,
          paddingLeft: i > 0 ? 12 : 0,
          borderLeft: i > 0 ? "1px solid var(--steel)" : "none"
        }}>
          <div style={{
            fontSize: 10, color: "var(--fg3)",
            fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase"
          }}>{s.label}</div>
          <div style={{
            fontFamily: "Nunito, sans-serif", fontWeight: 800, fontSize: 22,
            color: s.tone === "good" ? "var(--venom)" : s.tone === "bad" ? "var(--race-red)" : "var(--bone)",
            letterSpacing: "-0.02em", fontVariantNumeric: "tabular-nums"
          }}>{s.value}</div>
          {s.sub && <div style={{ fontSize: 11, color: "var(--fg3)" }}>{s.sub}</div>}
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { EnzoMark, UserAvatar, CheckerBand, TypingDots, Icons, ProductRef, OrderRef, StatGrid });
