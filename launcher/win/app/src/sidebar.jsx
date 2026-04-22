/* global React, EnzoMark, UserAvatar, Icons */
const { useState: useStateSB, useMemo: useMemoSB } = React;

function Sidebar({ threads, activeId, onSelect, onNew, onDeleteThread, onPinThread, onRenameThread, collapsed, onToggleCollapsed, config }) {
  const [query, setQuery] = useStateSB("");
  const [menuFor, setMenuFor] = useStateSB(null);
  const [renamingId, setRenamingId] = useStateSB(null);
  const [renameText, setRenameText] = useStateSB("");

  const filtered = useMemoSB(() => {
    const q = query.trim().toLowerCase();
    if (!q) return threads;
    return threads.filter(t => t.title.toLowerCase().includes(q));
  }, [threads, query]);

  const pinned = filtered.filter(t => t.pinned);
  const recent = filtered.filter(t => !t.pinned).sort((a, b) => {
    const ta = new Date(a.lastMessage || 0).getTime();
    const tb = new Date(b.lastMessage || 0).getTime();
    return tb - ta;
  });

  function relTime(ts) {
    if (!ts) return "";
    const diff = Date.now() - new Date(ts).getTime();
    const m = Math.floor(diff / 60000);
    if (m < 1) return "now";
    if (m < 60) return `${m}m`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h`;
    const d = Math.floor(h / 24);
    if (d < 7) return `${d}d`;
    return `${Math.floor(d / 7)}w`;
  }

  function startRename(t) {
    setRenamingId(t.id); setRenameText(t.title); setMenuFor(null);
  }
  function commitRename() {
    if (renamingId && renameText.trim()) onRenameThread(renamingId, renameText.trim());
    setRenamingId(null);
  }

  const userName = config?.userName || "Team";
  const userRole = config?.userRole || "User";
  const appName = config?.appName || "Enzo";
  const subtitle = config?.subtitle || "AI Assistant";

  if (collapsed) {
    return (
      <aside style={{ width: 56, background: "var(--bg1)", borderRight: "1px solid var(--steel)", display: "flex", flexDirection: "column", alignItems: "center", padding: "14px 0", gap: 10 }}>
        <button onClick={onToggleCollapsed} className="icon-btn" title="Expand sidebar"><Icons.menu/></button>
        <div style={{ marginTop: 6 }}><EnzoMark size={30}/></div>
        <button onClick={onNew} className="icon-btn" style={{ background: "var(--venom)", color: "#0a0d10" }} title="New chat"><Icons.plus/></button>
        <div style={{ flex: 1 }}/>
        <button className="icon-btn" title="Settings"><Icons.settings/></button>
      </aside>
    );
  }

  return (
    <aside style={{ width: 296, background: "var(--bg1)", borderRight: "1px solid var(--steel)", display: "flex", flexDirection: "column", minHeight: 0 }}>
      <div style={{ padding: "16px 18px 14px", borderBottom: "1px solid var(--steel)", display: "flex", alignItems: "center", gap: 10 }}>
        <EnzoMark size={34}/>
        <div style={{ flex: 1, lineHeight: 1 }}>
          <div style={{ fontFamily: "Nunito, sans-serif", fontWeight: 900, fontSize: 18, color: "var(--bone)", letterSpacing: "-0.03em" }}>{appName}</div>
          <div style={{ fontSize: 10, color: "var(--venom)", fontWeight: 700, letterSpacing: "0.14em", textTransform: "uppercase", marginTop: 3 }}>{subtitle}</div>
        </div>
        <button onClick={onToggleCollapsed} className="icon-btn" title="Collapse"><Icons.menu/></button>
      </div>

      <div style={{ padding: "14px 14px 10px" }}>
        <button onClick={onNew} style={{
          width: "100%", height: 42,
          background: "var(--venom)", color: "#0a0d10", border: 0,
          borderRadius: 8, fontFamily: "Nunito, sans-serif", fontWeight: 900,
          fontSize: 13, letterSpacing: "0.1em", textTransform: "uppercase", cursor: "pointer",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          transition: "all var(--dur-sm) var(--ease)",
          boxShadow: "0 4px 12px rgba(122,242,1,0.2)"
        }}
        onMouseEnter={e => { e.currentTarget.style.background = "#8fff10"; e.currentTarget.style.transform = "translateY(-1px)"; }}
        onMouseLeave={e => { e.currentTarget.style.background = "var(--venom)"; e.currentTarget.style.transform = "none"; }}
        >
          <Icons.plus/> New Chat
        </button>
      </div>

      <div style={{ padding: "0 14px 10px" }}>
        <div style={{ position: "relative" }}>
          <div style={{ position: "absolute", left: 10, top: "50%", transform: "translateY(-50%)", color: "var(--fg3)", pointerEvents: "none" }}><Icons.search/></div>
          <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search threads" style={{
            width: "100%", boxSizing: "border-box",
            background: "#14181b", border: "1px solid var(--steel)", borderRadius: 8,
            padding: "9px 12px 9px 34px", color: "var(--bone)", fontSize: 13,
            fontFamily: "inherit", outline: "none"
          }}
          onFocus={e => { e.currentTarget.style.borderColor = "var(--venom)"; e.currentTarget.style.boxShadow = "0 0 0 3px rgba(122,242,1,0.2)"; }}
          onBlur={e => { e.currentTarget.style.borderColor = "var(--steel)"; e.currentTarget.style.boxShadow = "none"; }}
          />
        </div>
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "4px 8px 14px" }}>
        {pinned.length > 0 && (
          <>
            <SectionHeader label="Pinned" icon={<Icons.pin/>}/>
            {pinned.map(t => (
              <ThreadRow key={t.id}
                t={t} active={t.id === activeId} relTime={relTime}
                onSelect={() => onSelect(t.id)}
                onMenu={() => setMenuFor(menuFor === t.id ? null : t.id)}
                menuOpen={menuFor === t.id}
                onPin={() => { onPinThread(t.id); setMenuFor(null); }}
                onDelete={() => { onDeleteThread(t.id); setMenuFor(null); }}
                onRenameStart={() => startRename(t)}
                renaming={renamingId === t.id} renameText={renameText} setRenameText={setRenameText}
                commitRename={commitRename}
              />
            ))}
          </>
        )}
        {recent.length > 0 && (
          <>
            <SectionHeader label="Recent" icon={<Icons.sparkles/>}/>
            {recent.map(t => (
              <ThreadRow key={t.id}
                t={t} active={t.id === activeId} relTime={relTime}
                onSelect={() => onSelect(t.id)}
                onMenu={() => setMenuFor(menuFor === t.id ? null : t.id)}
                menuOpen={menuFor === t.id}
                onPin={() => { onPinThread(t.id); setMenuFor(null); }}
                onDelete={() => { onDeleteThread(t.id); setMenuFor(null); }}
                onRenameStart={() => startRename(t)}
                renaming={renamingId === t.id} renameText={renameText} setRenameText={setRenameText}
                commitRename={commitRename}
              />
            ))}
          </>
        )}
        {filtered.length === 0 && (
          <div style={{ padding: "40px 20px", textAlign: "center", color: "var(--fg3)", fontSize: 13 }}>
            {query ? `No threads match "${query}"` : "No conversations yet. Start a new chat!"}
          </div>
        )}
      </div>

      <div style={{ padding: "12px 14px", borderTop: "1px solid var(--steel)", display: "flex", alignItems: "center", gap: 10, background: "#14181b" }}>
        <UserAvatar name={userName} size={32}/>
        <div style={{ flex: 1, minWidth: 0, lineHeight: 1.2 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: "var(--bone)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{userName}</div>
          <div style={{ fontSize: 11, color: "var(--fg3)" }}>{userRole}</div>
        </div>
        <button className="icon-btn" title="Settings"><Icons.settings/></button>
      </div>
    </aside>
  );
}

function SectionHeader({ label, icon }) {
  return (
    <div style={{
      padding: "14px 8px 6px", display: "flex", alignItems: "center", gap: 6,
      color: "var(--fg3)", fontSize: 10, fontWeight: 700, letterSpacing: "0.14em", textTransform: "uppercase"
    }}>
      <span style={{ opacity: 0.6, display: "inline-flex" }}>{icon}</span>
      <span>{label}</span>
    </div>
  );
}

function ThreadRow({ t, active, relTime, onSelect, onMenu, menuOpen, onPin, onDelete, onRenameStart, renaming, renameText, setRenameText, commitRename }) {
  const [hover, setHover] = useStateSB(false);
  return (
    <div onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{ position: "relative" }}>
      <button onClick={onSelect} style={{
        display: "block", width: "100%", textAlign: "left",
        background: active ? "rgba(122,242,1,0.08)" : hover ? "rgba(255,255,255,0.03)" : "transparent",
        border: 0, borderLeft: active ? "2px solid var(--venom)" : "2px solid transparent",
        padding: "9px 10px 9px 12px", cursor: "pointer", color: "var(--bone)",
        transition: "background var(--dur-micro) var(--ease)", borderRadius: 6, marginBottom: 1
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 2 }}>
          {t.pinned && <span style={{ color: "var(--venom)", display: "inline-flex", opacity: 0.8 }}><Icons.pin/></span>}
          {renaming ? (
            <input autoFocus value={renameText} onChange={e => setRenameText(e.target.value)}
              onClick={e => e.stopPropagation()} onBlur={commitRename}
              onKeyDown={e => { if (e.key === "Enter" || e.key === "Escape") commitRename(); }}
              style={{ flex: 1, background: "#0a0d10", border: "1px solid var(--venom)", color: "var(--bone)", fontSize: 13, fontWeight: 700, padding: "2px 6px", borderRadius: 4, fontFamily: "inherit", outline: "none" }}
            />
          ) : (
            <div style={{ fontSize: 13, fontWeight: 700, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", flex: 1, color: active ? "var(--bone)" : "var(--fg1-light)" }}>{t.title}</div>
          )}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 11, color: "var(--fg3)" }}>
          <span style={{ marginLeft: "auto", fontFamily: "JetBrains Mono, monospace" }}>{relTime(t.lastMessage || t.updated)}</span>
        </div>
      </button>
      {(hover || menuOpen) && !renaming && (
        <button onClick={(e) => { e.stopPropagation(); onMenu(); }} style={{
          position: "absolute", right: 4, top: 8, width: 24, height: 24, border: 0, borderRadius: 4,
          background: menuOpen ? "var(--steel)" : "rgba(10,13,16,0.8)", color: "var(--fg2)", cursor: "pointer",
          display: "flex", alignItems: "center", justifyContent: "center"
        }}><Icons.more/></button>
      )}
      {menuOpen && (
        <div style={{
          position: "absolute", right: 4, top: 36, zIndex: 20,
          background: "#14181b", border: "1px solid var(--steel)", borderRadius: 8,
          boxShadow: "0 12px 32px rgba(0,0,0,0.6)", minWidth: 160, overflow: "hidden", padding: 4
        }}>
          <MenuItem icon={<Icons.pin/>} label={t.pinned ? "Unpin" : "Pin"} onClick={onPin}/>
          <MenuItem icon={<Icons.edit/>} label="Rename" onClick={onRenameStart}/>
          <div style={{ height: 1, background: "var(--steel)", margin: "4px 0" }}/>
          <MenuItem icon={<Icons.trash/>} label="Delete" danger onClick={onDelete}/>
        </div>
      )}
    </div>
  );
}

function MenuItem({ icon, label, onClick, danger }) {
  return (
    <button onClick={onClick} style={{
      display: "flex", alignItems: "center", gap: 10, width: "100%",
      background: "transparent", border: 0, padding: "8px 10px",
      color: danger ? "var(--race-red)" : "var(--bone)", cursor: "pointer",
      fontSize: 13, fontFamily: "inherit", textAlign: "left", borderRadius: 4,
      transition: "background var(--dur-micro)"
    }}
    onMouseEnter={e => e.currentTarget.style.background = danger ? "rgba(230,57,70,0.12)" : "rgba(255,255,255,0.05)"}
    onMouseLeave={e => e.currentTarget.style.background = "transparent"}
    >
      <span style={{ display: "inline-flex", opacity: 0.8 }}>{icon}</span>
      <span>{label}</span>
    </button>
  );
}

Object.assign(window, { Sidebar });
