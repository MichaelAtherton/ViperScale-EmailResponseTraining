/* global React, EnzoMark, UserAvatar, Icons, TypingDots, ProductRef, OrderRef, StatGrid, SUGGESTIONS_HOME, QUICK_ACTIONS, enzoReply, parseLinks, copyMessageForEmail, copyMessageAsText */
const { useState: useS_C, useEffect: useE_C, useRef: useR_C } = React;

function ChatPane({ thread, onSend, onNewFromHome, onTitleEdit, config, typing: externalTyping }) {
  const [input, setInput] = useS_C("");
  const [typing, setTyping] = useS_C(false);
  const isTyping = typing || externalTyping;
  const [titleEditing, setTitleEditing] = useS_C(false);
  const [titleText, setTitleText] = useS_C("");
  const bodyRef = useR_C();
  const taRef = useR_C();

  useE_C(() => {
    if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight;
  }, [thread?.messages, isTyping]);

  useE_C(() => { setTyping(false); }, [thread?.id]);

  function autogrow() {
    if (!taRef.current) return;
    taRef.current.style.height = "auto";
    taRef.current.style.height = Math.min(taRef.current.scrollHeight, 160) + "px";
  }

  function handleSend(text) {
    const t = (text ?? input).trim();
    if (!t) return;
    setInput(""); if (taRef.current) taRef.current.style.height = "auto";
    setTyping(true);
    onSend(t, (reply) => {
      setTimeout(() => {
        setTyping(false);
        onSend(null, null, reply);
      }, 900 + Math.random() * 500);
    });
  }

  const isHome = !thread || thread.messages.length === 0;

  return (
    <main style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0, background: "var(--bg0)", position: "relative" }}>
      {/* Top bar */}
      <div style={{
        padding: "14px 24px", borderBottom: "1px solid var(--steel)",
        display: "flex", alignItems: "center", gap: 12, background: "rgba(10,13,16,0.6)",
        backdropFilter: "blur(18px)", position: "sticky", top: 0, zIndex: 5
      }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          {thread && !isHome ? (
            titleEditing ? (
              <input
                autoFocus value={titleText}
                onChange={e => setTitleText(e.target.value)}
                onBlur={() => { if (titleText.trim()) onTitleEdit(thread.id, titleText.trim()); setTitleEditing(false); }}
                onKeyDown={e => { if (e.key === "Enter" || e.key === "Escape") e.currentTarget.blur(); }}
                style={{
                  background: "transparent", border: "1px solid var(--venom)",
                  color: "var(--bone)", fontSize: 16, fontWeight: 800, padding: "4px 8px",
                  borderRadius: 4, fontFamily: "Nunito, sans-serif", outline: "none",
                  letterSpacing: "-0.02em", width: "100%", maxWidth: 520
                }}
              />
            ) : (
              <button onClick={() => { setTitleEditing(true); setTitleText(thread.title); }} style={{
                background: "transparent", border: 0, padding: 0, cursor: "text",
                display: "flex", alignItems: "center", gap: 10, color: "var(--bone)"
              }}>
                <span style={{
                  fontFamily: "Nunito, sans-serif", fontWeight: 800, fontSize: 16,
                  letterSpacing: "-0.015em", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 520
                }}>{thread.title}</span>
              </button>
            )
          ) : (
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <EnzoMark size={28}/>
              <div>
                <div style={{ fontFamily: "Nunito, sans-serif", fontWeight: 800, fontSize: 15, color: "var(--bone)" }}>New Conversation</div>
                <div style={{ fontSize: 11, color: "var(--venom)", fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase" }}>
                  <span style={{ display: "inline-block", width: 6, height: 6, borderRadius: 999, background: "var(--venom)", marginRight: 6, verticalAlign: "middle" }}/>
                  Pit Crew Online
                </div>
              </div>
            </div>
          )}
        </div>
        <button className="icon-btn" title="Share"><Icons.copy/></button>
        <button className="icon-btn" title="More"><Icons.more/></button>
      </div>

      {/* Body */}
      <div ref={bodyRef} style={{ flex: 1, overflowY: "auto", padding: isHome ? "20px" : "28px 24px 40px" }}>
        {isHome ? <HomeScreen onSend={handleSend}/> : (
          <div style={{ maxWidth: 760, margin: "0 auto", display: "flex", flexDirection: "column", gap: 20 }}>
            {thread.messages.length === 0 && thread.title !== "New chat" && (
              <div className="fade-in" style={{
                background: "var(--bg2)", border: "1px solid var(--steel)",
                borderRadius: 8, padding: "16px 20px", marginBottom: 20,
                color: "var(--fg3)", fontSize: 14, lineHeight: 1.5, textAlign: "center"
              }}>
                Earlier messages in this conversation aren't displayed, but Enzo remembers the full context. Just keep chatting.
              </div>
            )}
            {thread.messages.map((m, i) => <MessageRow key={i} m={m} isLast={i === thread.messages.length - 1}/>)}
            {isTyping && (
              <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
                <EnzoMark size={32}/>
                <div style={{
                  background: "var(--bg2)", border: "1px solid var(--steel)",
                  borderRadius: 12, borderTopLeftRadius: 4, padding: "10px 14px"
                }}><TypingDots/></div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Composer */}
      <Composer
        taRef={taRef} input={input} setInput={setInput}
        onSend={handleSend} autogrow={autogrow}
      />
    </main>
  );
}

function InlineText({ m }) {
  const segs = parseLinks(m.text, m.refs);
  return (
    <div style={{ whiteSpace: "pre-wrap" }}>
      {segs.map((s, i) => s.type === "link"
        ? <a key={i} href={s.url} target="_blank" rel="noopener" style={{
            color: "var(--venom)", textDecoration: "underline",
            textDecorationColor: "rgba(122,242,1,0.4)", textUnderlineOffset: 2,
            fontWeight: 700
          }}>{s.text}</a>
        : <span key={i}>{s.text}</span>
      )}
    </div>
  );
}

function CopyButton({ m, isLast }) {
  const [state, setState] = useS_C("idle"); // idle | copied-email | copied-text
  const [menu, setMenu] = useS_C(false);

  async function doCopyEmail() {
    const ok = await copyMessageForEmail(m);
    setState(ok ? "copied-email" : "idle"); setMenu(false);
    setTimeout(() => setState("idle"), 1800);
  }
  async function doCopyText() {
    const ok = await copyMessageAsText(m);
    setState(ok ? "copied-text" : "idle"); setMenu(false);
    setTimeout(() => setState("idle"), 1800);
  }

  const label = state === "copied-email" ? "Copied — paste into Gmail"
              : state === "copied-text" ? "Copied as plain text"
              : "Copy for Email";

  return (
    <div style={{ position: "relative", display: "inline-flex" }}>
      <button
        onClick={doCopyEmail}
        style={{
          display: "inline-flex", alignItems: "center", gap: 7,
          height: 30, padding: "0 11px 0 10px",
          background: state !== "idle" ? "rgba(122,242,1,0.12)" : "transparent",
          border: `1px solid ${state !== "idle" ? "var(--venom)" : "var(--steel)"}`,
          borderRight: 0, borderRadius: "6px 0 0 6px",
          color: state !== "idle" ? "var(--venom)" : "var(--fg2)",
          cursor: "pointer", fontSize: 12, fontWeight: 700, fontFamily: "inherit",
          letterSpacing: "0.02em", transition: "all var(--dur-micro)"
        }}
        onMouseEnter={e => { if (state === "idle") { e.currentTarget.style.borderColor = "var(--venom)"; e.currentTarget.style.color = "var(--venom)"; } }}
        onMouseLeave={e => { if (state === "idle") { e.currentTarget.style.borderColor = "var(--steel)"; e.currentTarget.style.color = "var(--fg2)"; } }}
      >
        <span style={{ display: "inline-flex" }}>{state !== "idle" ? <Icons.check/> : <Icons.copy/>}</span>
        <span>{label}</span>
      </button>
      <button
        onClick={() => setMenu(v => !v)}
        aria-label="Copy options"
        style={{
          height: 30, width: 24, padding: 0,
          background: menu ? "var(--steel)" : "transparent",
          border: `1px solid ${state !== "idle" ? "var(--venom)" : "var(--steel)"}`,
          borderRadius: "0 6px 6px 0",
          color: state !== "idle" ? "var(--venom)" : "var(--fg2)",
          cursor: "pointer",
          display: "inline-flex", alignItems: "center", justifyContent: "center"
        }}
      >
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6"/></svg>
      </button>
      {menu && (
        <div style={{
          position: "absolute", top: 34, right: 0, zIndex: 30, minWidth: 220,
          background: "#14181b", border: "1px solid var(--steel)", borderRadius: 8,
          boxShadow: "0 12px 32px rgba(0,0,0,0.6)", padding: 4
        }}>
          <MenuItemC label="Copy for Email" sub="Rich text with live links" onClick={doCopyEmail} active/>
          <MenuItemC label="Copy as plain text" sub="Links appear as (url) inline" onClick={doCopyText}/>
        </div>
      )}
    </div>
  );
}

function MenuItemC({ label, sub, onClick, active }) {
  return (
    <button onClick={onClick} style={{
      display: "flex", flexDirection: "column", gap: 2, width: "100%",
      background: "transparent", border: 0, padding: "8px 10px",
      color: "var(--bone)", cursor: "pointer", fontSize: 13, fontFamily: "inherit",
      textAlign: "left", borderRadius: 4
    }}
    onMouseEnter={e => e.currentTarget.style.background = "rgba(255,255,255,0.05)"}
    onMouseLeave={e => e.currentTarget.style.background = "transparent"}
    >
      <span style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 700 }}>
        {active && <span style={{ color: "var(--venom)", display: "inline-flex" }}><Icons.sparkles/></span>}
        {label}
      </span>
      {sub && <span style={{ fontSize: 11, color: "var(--fg3)", paddingLeft: active ? 26 : 0 }}>{sub}</span>}
    </button>
  );
}

function MessageRow({ m, isLast }) {
  const [showActions, setShowActions] = useS_C(false);
  if (m.who === "me") {
    return (
      <div style={{ display: "flex", gap: 12, flexDirection: "row-reverse", alignItems: "flex-start" }}>
        <UserAvatar name="Ray Chen" size={32}/>
        <div style={{
          background: "var(--venom)", color: "#0a0d10",
          padding: "12px 16px", borderRadius: 12, borderBottomRightRadius: 4,
          maxWidth: 560, fontSize: 15, lineHeight: 1.5, fontWeight: 600,
          letterSpacing: "-0.005em"
        }}>{m.text}</div>
      </div>
    );
  }
  return (
    <div
      onMouseEnter={() => setShowActions(true)}
      onMouseLeave={() => setShowActions(false)}
      style={{ display: "flex", gap: 12, alignItems: "flex-start" }}
    >
      <EnzoMark size={32}/>
      <div style={{ flex: 1, minWidth: 0, maxWidth: 640 }}>
        <div style={{
          background: "var(--bg2)", border: "1px solid var(--steel)",
          color: "var(--bone)", padding: "12px 16px", borderRadius: 12, borderTopLeftRadius: 4,
          fontSize: 15, lineHeight: 1.55
        }}>
          <InlineText m={m}/>
          {m.refs && m.refs.filter(r => r.kind === "product").map((r, k) => <ProductRef key={"p"+k} p={r}/>)}
          {m.refs && m.refs.filter(r => r.kind === "order").map((r, k) => <OrderRef key={"o"+k} o={r}/>)}
          {m.stats && <StatGrid stats={m.stats}/>}
        </div>
        <div style={{
          display: "flex", gap: 6, marginTop: 8, paddingLeft: 4, alignItems: "center",
          opacity: (showActions || isLast) ? 1 : 0.4, transition: "opacity var(--dur-sm) var(--ease)"
        }}>
          <CopyButton m={m} isLast={isLast}/>
          <div style={{ width: 1, height: 18, background: "var(--steel)", margin: "0 4px" }}/>
          <MsgAction icon={<Icons.thumbsUp/>} label="Good reply"/>
          <MsgAction icon={<Icons.thumbsDown/>} label="Bad reply"/>
          <MsgAction icon={<Icons.refresh/>} label="Regenerate"/>
        </div>
      </div>
    </div>
  );
}

function MsgAction({ icon, label }) {
  return (
    <button className="icon-btn-sm" title={label}
      style={{
        width: 28, height: 28, border: 0, borderRadius: 6,
        background: "transparent", color: "var(--fg3)", cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center",
        transition: "all var(--dur-micro)"
      }}
      onMouseEnter={e => { e.currentTarget.style.background = "var(--steel)"; e.currentTarget.style.color = "var(--venom)"; }}
      onMouseLeave={e => { e.currentTarget.style.background = "transparent"; e.currentTarget.style.color = "var(--fg3)"; }}
    >{icon}</button>
  );
}

function HomeScreen({ onSend }) {
  return (
    <div style={{ maxWidth: 760, margin: "0 auto", padding: "40px 8px 0", display: "flex", flexDirection: "column", gap: 36 }}>
      {/* Hero */}
      <div style={{ textAlign: "center", display: "flex", flexDirection: "column", alignItems: "center", gap: 20 }}>
        <div style={{ position: "relative" }}>
          <EnzoMark size={72}/>
          <div style={{
            position: "absolute", inset: -6, borderRadius: 999,
            border: "1px solid rgba(122,242,1,0.2)", animation: "pulse 2.8s infinite"
          }}/>
        </div>
        <div>
          <h1 style={{
            fontFamily: "Nunito, sans-serif", fontWeight: 900, fontSize: 42,
            letterSpacing: "-0.03em", color: "var(--bone)", margin: 0, lineHeight: 1.05
          }}>
            Hey Ray — <span style={{ color: "var(--venom)" }}>what are we wrenching on?</span>
          </h1>
          <p style={{
            color: "var(--fg2)", fontSize: 16, marginTop: 14, maxWidth: 520,
            marginLeft: "auto", marginRight: "auto", lineHeight: 1.5
          }}>
            Customer questions, tuning advice, SCDRL logistics, or the Q1 numbers — ask away. I've got the whole catalog, order book, and race calendar cached.
          </p>
        </div>
      </div>

      {/* Quick actions */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10 }}>
        {QUICK_ACTIONS.map((a) => {
          const I = Icons[a.icon];
          return (
            <button key={a.label}
              onClick={() => onSend(a.prompt)}
              style={{
                background: "var(--bg2)", border: "1px solid var(--steel)",
                borderRadius: 10, padding: "14px 12px",
                display: "flex", flexDirection: "column", gap: 10, alignItems: "flex-start",
                cursor: "pointer", color: "var(--bone)", textAlign: "left",
                transition: "all var(--dur-sm) var(--ease)", minHeight: 92
              }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = "var(--venom)"; e.currentTarget.style.transform = "translateY(-2px)"; e.currentTarget.style.background = "rgba(122,242,1,0.04)"; }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = "var(--steel)"; e.currentTarget.style.transform = "none"; e.currentTarget.style.background = "var(--bg2)"; }}
            >
              <div style={{
                width: 32, height: 32, borderRadius: 8,
                background: "rgba(122,242,1,0.1)", border: "1px solid rgba(122,242,1,0.25)",
                display: "flex", alignItems: "center", justifyContent: "center", color: "var(--venom)"
              }}><I/></div>
              <div style={{ fontSize: 13, fontWeight: 700, lineHeight: 1.3 }}>{a.label}</div>
            </button>
          );
        })}
      </div>

      {/* Starter prompts */}
      <div>
        <div style={{
          fontSize: 10, color: "var(--fg3)", fontWeight: 700, letterSpacing: "0.14em",
          textTransform: "uppercase", marginBottom: 10, display: "flex", alignItems: "center", gap: 8
        }}>
          <Icons.sparkles/> Try asking
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
          {SUGGESTIONS_HOME.map(s => {
            const I = Icons[s.icon];
            return (
              <button key={s.label}
                onClick={() => onSend(s.label)}
                style={{
                  background: "transparent", border: "1px solid var(--steel)",
                  borderRadius: 8, padding: "11px 14px",
                  display: "flex", alignItems: "center", gap: 10,
                  cursor: "pointer", color: "var(--fg1-light)", textAlign: "left",
                  fontSize: 13, fontFamily: "inherit", fontWeight: 500,
                  transition: "all var(--dur-sm) var(--ease)"
                }}
                onMouseEnter={e => { e.currentTarget.style.borderColor = "var(--venom)"; e.currentTarget.style.color = "var(--bone)"; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = "var(--steel)"; e.currentTarget.style.color = "var(--fg1-light)"; }}
              >
                <span style={{ color: "var(--venom)", opacity: 0.75, display: "inline-flex", flexShrink: 0 }}><I/></span>
                <span style={{ flex: 1 }}>{s.label}</span>
                <span style={{ color: "var(--fg3)", fontSize: 11 }}>→</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function Composer({ taRef, input, setInput, onSend, autogrow }) {
  const [focus, setFocus] = useS_C(false);
  return (
    <div style={{ padding: "16px 24px 20px", background: "linear-gradient(180deg, rgba(10,13,16,0) 0%, var(--bg0) 30%)" }}>
      <form
        onSubmit={e => { e.preventDefault(); onSend(); }}
        style={{
          maxWidth: 760, margin: "0 auto",
          background: "var(--bg2)", border: `1px solid ${focus ? "var(--venom)" : "var(--steel)"}`,
          borderRadius: 12, padding: 6,
          boxShadow: focus ? "0 0 0 3px rgba(122,242,1,0.15), 0 4px 14px rgba(0,0,0,0.5)" : "0 4px 14px rgba(0,0,0,0.4)",
          transition: "all var(--dur-sm) var(--ease)"
        }}
      >
        <textarea
          ref={taRef}
          value={input}
          onChange={e => { setInput(e.target.value); autogrow(); }}
          onFocus={() => setFocus(true)}
          onBlur={() => setFocus(false)}
          onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); onSend(); } }}
          placeholder="Ask Enzo anything — a product, an order, a customer, the numbers…"
          rows={1}
          style={{
            width: "100%", boxSizing: "border-box", background: "transparent",
            border: 0, resize: "none", color: "var(--bone)", fontSize: 15,
            fontFamily: "inherit", lineHeight: 1.5, outline: "none",
            padding: "10px 12px 4px", maxHeight: 160
          }}
        />
        <div style={{ display: "flex", alignItems: "center", gap: 4, padding: "4px 6px 4px 8px" }}>
          <button type="button" className="icon-btn" title="Attach"><Icons.attach/></button>
          <button type="button" className="icon-btn" title="Voice"><Icons.mic/></button>
          <div style={{
            marginLeft: 8, fontSize: 11, color: "var(--fg3)", display: "flex", alignItems: "center", gap: 6
          }}>
            <span style={{ display: "inline-block", width: 6, height: 6, borderRadius: 999, background: "var(--venom)" }}/>
            Enzo · v2.4 · connected to shop data
          </div>
          <div style={{ flex: 1 }}/>
          <div style={{ fontSize: 11, color: "var(--fg3)", fontFamily: "JetBrains Mono, monospace" }}>
            <kbd style={{ background: "var(--bg0)", border: "1px solid var(--steel)", borderRadius: 3, padding: "2px 6px" }}>↵</kbd> send
          </div>
          <button type="submit" disabled={!input.trim()} style={{
            width: 36, height: 36, border: 0, borderRadius: 8,
            background: input.trim() ? "var(--venom)" : "var(--steel)",
            color: input.trim() ? "#0a0d10" : "var(--fg3)",
            cursor: input.trim() ? "pointer" : "not-allowed",
            display: "flex", alignItems: "center", justifyContent: "center",
            transition: "all var(--dur-sm) var(--ease)"
          }}><Icons.send/></button>
        </div>
      </form>
      <div style={{ textAlign: "center", marginTop: 8, fontSize: 11, color: "var(--fg3)" }}>
        Enzo can make mistakes on live orders — double-check dollar figures before replying to customers.
      </div>
    </div>
  );
}

Object.assign(window, { ChatPane });
