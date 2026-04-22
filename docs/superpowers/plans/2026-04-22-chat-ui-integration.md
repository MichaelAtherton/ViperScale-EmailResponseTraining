# Enzo Chat UI Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the Enzo browser chat UI to Claude Code via the Agent SDK, using local OAuth — so Dan types in a browser and gets real answers from Enzo's skills + WooCommerce integration.

**Architecture:** A Node.js bridge server (Express + Agent SDK) at localhost:3456 serves the React chat UI as static files and proxies chat messages to the Agent SDK via POST /chat (SSE streaming). The SDK auto-detects Claude Code's local OAuth — no API key. Thread metadata persists server-side in .enzo/threads.json. A response-format skill instructs Claude to return structured JSON when the prompt starts with [ENZO-CHAT].

**Tech Stack:** Node.js 18+, Express 4, @anthropic-ai/claude-agent-sdk, React 18 (CDN, no build step), Babel standalone (JSX transform in browser)

**Branch:** `feat/chat-ui-integration` (already created)

**Architecture doc:** `output/viper-racing/installer/CHAT-UI-ARCHITECTURE.md` (v3)

---

## File Structure

### New files (6)
| File | Responsibility |
|---|---|
| `launcher/win/server.mjs` | Express HTTP server — serves static UI, proxies chat to Agent SDK, manages thread metadata |
| `launcher/win/package.json` | Node.js dependencies (agent-sdk + express) |
| `launcher/win/launch-ui.bat` | Starts server + opens browser (with health polling) |
| `.enzo/config.json` | Client-facing config (user name, quick actions, etc.) — template committed, real one generated at install |
| `.claude/skills/response-format/SKILL.md` | Instructs Claude to return JSON when prompt starts with [ENZO-CHAT] |
| `.gitignore` additions | Ignore .enzo/threads.json and node_modules |

### Modified files (5)
| File | Change |
|---|---|
| `launcher/win/app/index.html` | Remove folder state, add config fetch, replace handleSend with async streaming, add no-cache banner |
| `launcher/win/app/src/data.jsx` | Replace enzoReply() with real fetch(), remove folder fields from SEED_THREADS, add extractJSON() |
| `launcher/win/app/src/sidebar.jsx` | Remove folder grouping, add recency sort, fetch thread list from server |
| `launcher/win/app/src/chatpane.jsx` | Remove folder badge, wire SSE streaming, add no-cached-messages banner |
| `launcher/win/install.ps1` | Add Node.js prerequisite + npm install + config prompts |

---

### Task 1: Create the response-format skill

This skill already exists from our testing but needs to be committed on the feature branch.

**Files:**
- Create: `.claude/skills/response-format/SKILL.md` (already written during testing)

- [ ] **Step 1: Verify the skill file exists**

```bash
cd /Users/michaelatherton/viper-second-brain
cat .claude/skills/response-format/SKILL.md | head -5
```

Expected: shows the `---` frontmatter with `name: response-format`.

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/response-format/SKILL.md
git commit -m "feat(chat-ui): add response-format skill for [ENZO-CHAT] JSON responses"
```

---

### Task 2: Create package.json and install dependencies

**Files:**
- Create: `launcher/win/package.json`

- [ ] **Step 1: Create package.json**

Write to `launcher/win/package.json`:

```json
{
  "name": "enzo-server",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^0.1.0",
    "express": "^4.21.0"
  }
}
```

- [ ] **Step 2: Install dependencies**

```bash
cd /Users/michaelatherton/viper-second-brain/launcher/win
npm install
```

Expected: `node_modules/` created with express + agent-sdk.

- [ ] **Step 3: Add node_modules to .gitignore**

Append to `/Users/michaelatherton/viper-second-brain/.gitignore`:

```
# Node.js (chat UI server)
launcher/win/node_modules/

# Enzo runtime state
.enzo/threads.json
```

- [ ] **Step 4: Commit**

```bash
cd /Users/michaelatherton/viper-second-brain
git add launcher/win/package.json launcher/win/package-lock.json .gitignore
git commit -m "feat(chat-ui): add Node.js deps - Agent SDK + Express"
```

---

### Task 3: Create server.mjs — the bridge server

**Files:**
- Create: `launcher/win/server.mjs`

- [ ] **Step 1: Create server.mjs**

Write to `launcher/win/server.mjs`:

```javascript
import express from "express";
import { query } from "@anthropic-ai/claude-agent-sdk";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, "..", "..");
const ENZO_DIR = join(PROJECT_ROOT, ".enzo");
const THREADS_FILE = join(ENZO_DIR, "threads.json");
const CONFIG_FILE = join(ENZO_DIR, "config.json");
const PORT = 3456;

// ── Thread persistence ────────────────────────────────

function loadThreads() {
  try {
    if (existsSync(THREADS_FILE)) return JSON.parse(readFileSync(THREADS_FILE, "utf8"));
  } catch {}
  return {};
}

function saveThreads(threads) {
  if (!existsSync(ENZO_DIR)) mkdirSync(ENZO_DIR, { recursive: true });
  writeFileSync(THREADS_FILE, JSON.stringify(threads, null, 2));
}

function loadConfig() {
  try {
    if (existsSync(CONFIG_FILE)) return JSON.parse(readFileSync(CONFIG_FILE, "utf8"));
  } catch {}
  return { userName: "Team", userRole: "User", appName: "Enzo", subtitle: "AI Assistant", greeting: "What can I help with?", heroSubtext: "", quickActions: [], suggestions: [], disclaimer: "", port: PORT };
}

// ── JSON extraction from Claude responses ────────────��

function extractJSON(text) {
  const start = text.indexOf("{");
  if (start === -1) return null;
  for (let end = text.length; end > start; end--) {
    if (text[end - 1] !== "}") continue;
    try {
      return JSON.parse(text.slice(start, end));
    } catch {}
  }
  return null;
}

// ── Express app ───────────────────────────────────────

const app = express();
app.use(express.json());
app.use("/", express.static(join(__dirname, "app")));

// Health check
app.get("/health", (req, res) => {
  res.json({ ok: true, version: "1.0.0" });
});

// Client config
app.get("/config", (req, res) => {
  res.json(loadConfig());
});

// Thread list
app.get("/threads", (req, res) => {
  res.json(loadThreads());
});

// New thread
app.post("/threads/new", (req, res) => {
  const { threadId } = req.body;
  if (!threadId) return res.status(400).json({ error: "threadId required" });
  const threads = loadThreads();
  threads[threadId] = { sessionId: null, title: "New chat", pinned: false, lastMessage: new Date().toISOString(), messageCount: 0 };
  saveThreads(threads);
  res.json({ threadId, sessionId: null });
});

// Rename thread
app.post("/threads/:id/title", (req, res) => {
  const { title } = req.body;
  const threads = loadThreads();
  if (!threads[req.params.id]) return res.status(404).json({ error: "thread not found" });
  threads[req.params.id].title = title;
  saveThreads(threads);
  res.json({ ok: true });
});

// Pin/unpin thread
app.post("/threads/:id/pin", (req, res) => {
  const threads = loadThreads();
  if (!threads[req.params.id]) return res.status(404).json({ error: "thread not found" });
  threads[req.params.id].pinned = !threads[req.params.id].pinned;
  saveThreads(threads);
  res.json({ ok: true, pinned: threads[req.params.id].pinned });
});

// Delete thread
app.delete("/threads/:id", (req, res) => {
  const threads = loadThreads();
  delete threads[req.params.id];
  saveThreads(threads);
  res.json({ ok: true });
});

// ── Chat endpoint (SSE streaming) ─────────────────────

app.post("/chat", async (req, res) => {
  const { threadId, message } = req.body;
  if (!threadId || !message) return res.status(400).json({ error: "threadId and message required" });

  const threads = loadThreads();
  let thread = threads[threadId];
  if (!thread) {
    thread = { sessionId: null, title: "New chat", pinned: false, lastMessage: new Date().toISOString(), messageCount: 0 };
    threads[threadId] = thread;
  }

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.write(`data: ${JSON.stringify({ type: "status", status: "thinking" })}\n\n`);

  try {
    const options = {
      cwd: PROJECT_ROOT,
      allowedTools: ["Bash", "Read", "Glob", "Grep"],
      maxTurns: 8,
    };
    if (thread.sessionId) options.resume = thread.sessionId;

    const result = query({ prompt: "[ENZO-CHAT] " + message, options });
    let fullText = "";
    let sessionId = thread.sessionId;

    for await (const event of result) {
      if (event.session_id && !sessionId) sessionId = event.session_id;

      if (event.type === "assistant") {
        const text = event.message.content
          .filter(b => b.type === "text")
          .map(b => b.text)
          .join("");
        fullText += text;
      }

      if (event.type === "result") {
        fullText = event.result || fullText;
      }
    }

    // Parse structured response
    const parsed = extractJSON(fullText);
    if (parsed && parsed.text) {
      res.write(`data: ${JSON.stringify({ type: "text", text: parsed.text })}\n\n`);
      if (parsed.refs && parsed.refs.length) {
        res.write(`data: ${JSON.stringify({ type: "refs", refs: parsed.refs })}\n\n`);
      }
      if (parsed.stats && parsed.stats.length) {
        res.write(`data: ${JSON.stringify({ type: "stats", stats: parsed.stats })}\n\n`);
      }
    } else {
      res.write(`data: ${JSON.stringify({ type: "text", text: fullText })}\n\n`);
    }

    // Update thread metadata
    thread.sessionId = sessionId;
    thread.lastMessage = new Date().toISOString();
    thread.messageCount = (thread.messageCount || 0) + 2;
    if (thread.title === "New chat" && message.length > 0) {
      thread.title = message.slice(0, 48) + (message.length > 48 ? "..." : "");
    }
    saveThreads(threads);

    res.write(`data: ${JSON.stringify({ type: "done", sessionId })}\n\n`);
  } catch (e) {
    res.write(`data: ${JSON.stringify({ type: "error", error: e.message || String(e) })}\n\n`);
  }
  res.end();
});

app.listen(PORT, () => {
  console.log(`Enzo server running at http://localhost:${PORT}`);
});
```

- [ ] **Step 2: Test the server starts**

```bash
cd /Users/michaelatherton/viper-second-brain
node launcher/win/server.mjs &
sleep 2
curl -s http://localhost:3456/health
kill %1
```

Expected: `{"ok":true,"version":"1.0.0"}`

- [ ] **Step 3: Commit**

```bash
git add launcher/win/server.mjs
git commit -m "feat(chat-ui): add bridge server - Express + Agent SDK + SSE streaming"
```

---

### Task 4: Create .enzo/config.json template

**Files:**
- Create: `.enzo/config.json`

- [ ] **Step 1: Create config.json**

Write to `.enzo/config.json`:

```json
{
  "userName": "Dan",
  "userRole": "Shop Owner",
  "appName": "Enzo",
  "subtitle": "Viper Shop Assistant",
  "greeting": "Hey Dan - what are we wrenching on?",
  "heroSubtext": "Customer questions, tuning advice, or the numbers - ask away. I've got the whole catalog and order book cached.",
  "quickActions": [
    { "icon": "package", "label": "Order lookup", "prompt": "Look up order " },
    { "icon": "zap", "label": "Recommend a setup", "prompt": "Recommend a setup for " },
    { "icon": "chart", "label": "Sales report", "prompt": "Pull a sales report for " },
    { "icon": "book", "label": "Product specs", "prompt": "Give me the specs for " }
  ],
  "suggestions": [
    { "icon": "zap", "label": "Best chassis for 12V drag racing?" },
    { "icon": "package", "label": "Check order status by number" },
    { "icon": "chart", "label": "Q1 sales summary" },
    { "icon": "wrench", "label": "Mega-G+ tuning walkthrough" },
    { "icon": "flag", "label": "SCDRL Spring Nationals details" },
    { "icon": "users", "label": "Top customers by lifetime value" }
  ],
  "disclaimer": "Enzo can make mistakes on live orders - double-check dollar figures before replying to customers.",
  "port": 3456
}
```

- [ ] **Step 2: Commit**

```bash
git add .enzo/config.json
git commit -m "feat(chat-ui): add .enzo/config.json for client-facing configuration"
```

---

### Task 5: Create launch-ui.bat

**Files:**
- Create: `launcher/win/launch-ui.bat`

- [ ] **Step 1: Create launch-ui.bat**

Write to `launcher/win/launch-ui.bat`:

```cmd
@echo off
cd /d "%~dp0..\.."

:: Check if server already running
netstat -ano | findstr ":3456" >nul 2>&1
if %errorlevel%==0 (
  start "" "http://localhost:3456"
  exit /b
)

:: Start server in background (no visible window)
start /b node launcher\win\server.mjs

:: Poll until server is ready
:wait
timeout /t 1 >nul
curl -s http://localhost:3456/health >nul 2>&1
if %errorlevel% neq 0 goto wait

:: Open browser
start "" "http://localhost:3456"
```

- [ ] **Step 2: Commit**

```bash
git add launcher/win/launch-ui.bat
git commit -m "feat(chat-ui): add launch-ui.bat - starts server + opens browser with health polling"
```

---

### Task 6: Modify data.jsx — replace canned responses with real API calls

**Files:**
- Modify: `launcher/win/app/src/data.jsx`

- [ ] **Step 1: Read the current data.jsx**

```bash
cat /Users/michaelatherton/viper-second-brain/launcher/win/app/src/data.jsx | head -10
```

Verify the file starts with `/* global React */`.

- [ ] **Step 2: Rewrite data.jsx**

Replace the ENTIRE contents of `launcher/win/app/src/data.jsx` with:

```javascript
/* global React */
/* Data layer for Enzo Chat UI.
   Handles: API communication, JSON extraction, clipboard copy, link parsing.
   Seed data removed — threads come from the server. */

const ENZO_API = window.location.origin;

// ── JSON extraction from Claude responses ─────────────
// Claude sometimes prefixes JSON with reasoning text.
// Extract the first valid JSON object from the response.
function extractJSON(text) {
  const start = text.indexOf("{");
  if (start === -1) return null;
  for (let end = text.length; end > start; end--) {
    if (text[end - 1] !== "}") continue;
    try { return JSON.parse(text.slice(start, end)); } catch {}
  }
  return null;
}

// ── API functions ──────────────────────────────���──────

async function fetchConfig() {
  try {
    const res = await fetch(`${ENZO_API}/config`);
    return await res.json();
  } catch { return null; }
}

async function fetchThreads() {
  try {
    const res = await fetch(`${ENZO_API}/threads`);
    return await res.json();
  } catch { return {}; }
}

async function createThread(threadId) {
  try {
    const res = await fetch(`${ENZO_API}/threads/new`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ threadId })
    });
    return await res.json();
  } catch { return null; }
}

async function renameThread(threadId, title) {
  try {
    await fetch(`${ENZO_API}/threads/${threadId}/title`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title })
    });
  } catch {}
}

async function pinThread(threadId) {
  try {
    const res = await fetch(`${ENZO_API}/threads/${threadId}/pin`, { method: "POST" });
    return await res.json();
  } catch { return null; }
}

async function deleteThread(threadId) {
  try {
    await fetch(`${ENZO_API}/threads/${threadId}`, { method: "DELETE" });
  } catch {}
}

async function sendMessage(threadId, message, onText, onRefs, onStats, onDone, onError) {
  try {
    const res = await fetch(`${ENZO_API}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ threadId, message })
    });

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        try {
          const data = JSON.parse(line.slice(6));
          if (data.type === "text" && onText) onText(data.text);
          if (data.type === "refs" && onRefs) onRefs(data.refs);
          if (data.type === "stats" && onStats) onStats(data.stats);
          if (data.type === "done" && onDone) onDone(data.sessionId);
          if (data.type === "error" && onError) onError(data.error);
        } catch {}
      }
    }
  } catch (e) {
    if (onError) onError(e.message || "Connection failed");
  }
}

// ── Link resolution + serializers (unchanged from prototype) ─────

function parseLinks(text, refs) {
  if (!text) return [];
  const map = {};
  (refs || []).forEach(r => {
    const label = r.kind === "order" ? `Order #${r.id}` : r.name;
    if (r.url) map[label] = r.url;
  });
  const out = [];
  const re = /\{([^}]+)\}/g;
  let last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push({ type: "text", text: text.slice(last, m.index) });
    const label = m[1];
    const url = map[label];
    if (url) out.push({ type: "link", text: label, url });
    else out.push({ type: "text", text: label });
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push({ type: "text", text: text.slice(last) });
  return out;
}

function escHTML(s) {
  return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function messageToEmailHTML(m) {
  const segs = parseLinks(m.text, m.refs);
  const bodyHTML = segs.map(s => s.type === "link"
    ? `<a href="${escHTML(s.url)}" style="color:#0a6b00;text-decoration:underline;">${escHTML(s.text)}</a>`
    : escHTML(s.text).replace(/\n/g, "<br>")
  ).join("");

  let productsHTML = "";
  const products = (m.refs || []).filter(r => r.kind === "product");
  if (products.length) {
    productsHTML = `<table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;"><tr style="background:#f2f4f2;"><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Product</th><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">SKU</th><th style="text-align:right;padding:8px 12px;border-bottom:1px solid #ccc;">Price</th><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Stock</th></tr>${products.map(p => `<tr><td style="padding:8px 12px;border-bottom:1px solid #eee;"><a href="${escHTML(p.url || "#")}" style="color:#0a6b00;text-decoration:underline;font-weight:600;">${escHTML(p.name)}</a></td><td style="padding:8px 12px;border-bottom:1px solid #eee;font-family:monospace;color:#555;">${escHTML(p.sku || "")}</td><td style="padding:8px 12px;border-bottom:1px solid #eee;text-align:right;font-weight:600;">$${p.price.toFixed(2)}</td><td style="padding:8px 12px;border-bottom:1px solid #eee;color:${p.stock === "In Stock" ? "#0a6b00" : "#a86b00"};">${escHTML(p.stock || "")}</td></tr>`).join("")}</table>`;
  }

  const orders = (m.refs || []).filter(r => r.kind === "order");
  const ordersHTML = orders.map(o => `<div style="margin-top:12px;padding:10px 12px;border:1px solid #ddd;border-radius:6px;font-family:Arial,sans-serif;font-size:14px;"><div style="font-weight:600;"><a href="${escHTML(o.url || "#")}" style="color:#0a6b00;text-decoration:underline;">Order #${escHTML(o.id)}</a> - <span style="color:${o.status === "Shipped" ? "#0a6b00" : "#a86b00"};">${escHTML(o.status)}</span></div><div style="color:#555;margin-top:2px;">${escHTML(o.customer)} - ${escHTML(o.items)} - $${o.total.toFixed(2)} - ${escHTML(o.date)}</div></div>`).join("");

  let statsHTML = "";
  if (m.stats) {
    statsHTML = `<table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;"><tr>${m.stats.map(s => `<td style="padding:8px 16px 8px 0;border-right:1px solid #eee;"><div style="font-size:11px;color:#888;text-transform:uppercase;letter-spacing:0.08em;font-weight:600;">${escHTML(s.label)}</div><div style="font-size:20px;font-weight:700;color:#111;margin-top:2px;">${escHTML(s.value)}</div>${s.sub ? `<div style="font-size:12px;color:#0a6b00;">${escHTML(s.sub)}</div>` : ""}</td>`).join("")}</tr></table>`;
  }

  return `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.55;color:#111;">${bodyHTML}${productsHTML}${ordersHTML}${statsHTML}</div>`;
}

function messageToPlainText(m) {
  const segs = parseLinks(m.text, m.refs);
  let out = segs.map(s => s.type === "link" ? `${s.text} (${s.url})` : s.text).join("");
  const products = (m.refs || []).filter(r => r.kind === "product");
  if (products.length) {
    out += "\n\n" + products.map(p => `- ${p.name} - $${p.price.toFixed(2)} (${p.sku || "-"}, ${p.stock || ""})\n  ${p.url || ""}`).join("\n");
  }
  const orders = (m.refs || []).filter(r => r.kind === "order");
  orders.forEach(o => {
    out += `\n\nOrder #${o.id} - ${o.status}\n${o.customer} - ${o.items} - $${o.total.toFixed(2)} - ${o.date}\n${o.url || ""}`;
  });
  if (m.stats) {
    out += "\n\n" + m.stats.map(s => `${s.label}: ${s.value}${s.sub ? ` (${s.sub})` : ""}`).join(" | ");
  }
  return out;
}

async function copyMessageForEmail(m) {
  const html = messageToEmailHTML(m);
  const text = messageToPlainText(m);
  try {
    if (navigator.clipboard && window.ClipboardItem) {
      await navigator.clipboard.write([new ClipboardItem({
        "text/html": new Blob([html], { type: "text/html" }),
        "text/plain": new Blob([text], { type: "text/plain" })
      })]);
      return true;
    }
  } catch {}
  try { await navigator.clipboard.writeText(text); return true; } catch {}
  return false;
}

async function copyMessageAsText(m) {
  try { await navigator.clipboard.writeText(messageToPlainText(m)); return true; } catch { return false; }
}

Object.assign(window, {
  fetchConfig, fetchThreads, createThread, renameThread, pinThread, deleteThread,
  sendMessage, parseLinks, messageToEmailHTML, messageToPlainText,
  copyMessageForEmail, copyMessageAsText, extractJSON
});
```

- [ ] **Step 3: Commit**

```bash
git add launcher/win/app/src/data.jsx
git commit -m "feat(chat-ui): replace canned enzoReply with real API calls + SSE streaming"
```

---

### Task 7: Modify sidebar.jsx — remove folders, add server-driven threads

**Files:**
- Modify: `launcher/win/app/src/sidebar.jsx`

- [ ] **Step 1: Rewrite sidebar.jsx**

Replace the ENTIRE contents of `launcher/win/app/src/sidebar.jsx`. The key changes:
- Remove folder grouping (`byFolder`, `folderOrder`, `sortedFolders`, folder `SectionHeader`)
- Remove folder badge from `ThreadRow`
- Remove folder from search filter
- Threads are now: Pinned section, then all unpinned sorted by `lastMessage` descending
- User name/role comes from config prop (passed from App)

Write the full replacement to `launcher/win/app/src/sidebar.jsx`:

```javascript
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
```

- [ ] **Step 2: Commit**

```bash
git add launcher/win/app/src/sidebar.jsx
git commit -m "feat(chat-ui): remove folder grouping, add recency sort, server-driven thread metadata"
```

---

### Task 8: Modify chatpane.jsx — remove folder badge, add no-cache banner

**Files:**
- Modify: `launcher/win/app/src/chatpane.jsx`

- [ ] **Step 1: Read current chatpane.jsx to locate the folder badge**

```bash
grep -n "folder" /Users/michaelatherton/viper-second-brain/launcher/win/app/src/chatpane.jsx
```

- [ ] **Step 2: Remove the folder badge from the top bar**

In `chatpane.jsx`, find the block that renders the folder badge next to the thread title (around line 72-75):

```jsx
                <span style={{
                  fontSize: 10, color: "var(--venom)", fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase",
                  padding: "3px 7px", background: "rgba(122,242,1,0.08)", border: "1px solid rgba(122,242,1,0.25)", borderRadius: 3
                }}>{thread.folder || "General"}</span>
```

Delete that entire `<span>` element.

- [ ] **Step 3: Add the no-cached-messages banner**

In the `ChatPane` function, inside the body div (before the message map), add a check for when the thread exists but has no cached messages. Find the line that maps messages (around line 98):

```jsx
{thread.messages.map((m, i) => <MessageRow key={i} m={m} isLast={i === thread.messages.length - 1}/>)}
```

Add BEFORE it:

```jsx
{thread.messages.length === 0 && thread.title !== "New chat" && (
  <div className="fade-in" style={{
    background: "var(--bg2)", border: "1px solid var(--steel)",
    borderRadius: 8, padding: "16px 20px", marginBottom: 20,
    color: "var(--fg3)", fontSize: 14, lineHeight: 1.5, textAlign: "center"
  }}>
    Earlier messages in this conversation aren't displayed, but Enzo remembers the full context. Just keep chatting.
  </div>
)}
```

- [ ] **Step 4: Update the HomeScreen to use config**

The `HomeScreen` component has hardcoded text. Add a `config` prop and use it. Find the hero greeting (around line 305):

```jsx
Hey Ray — <span style={{ color: "var(--venom)" }}>what are we wrenching on?</span>
```

The HomeScreen receives config from the parent. Replace the hardcoded values. This will be wired in Task 9 (index.html).

- [ ] **Step 5: Commit**

```bash
git add launcher/win/app/src/chatpane.jsx
git commit -m "feat(chat-ui): remove folder badge, add no-cache banner, prep config props"
```

---

### Task 9: Modify index.html — async state management with server sync

**Files:**
- Modify: `launcher/win/app/index.html`

- [ ] **Step 1: Rewrite the App component in index.html**

The App component in the inline `<script type="text/babel">` block needs these changes:
- Remove `SEED_THREADS` and `enzoReply` dependencies
- Remove `folder` from thread creation
- Add config fetch on mount
- Add server sync for thread operations (create, rename, pin, delete)
- Replace `handleSend` with async version that calls `sendMessage()` from data.jsx
- Fetch thread list from server on mount
- Pass `config` to Sidebar and ChatPane/HomeScreen

The full replacement for the inline script block (between `<script type="text/babel">` and `</script>` just before `</body>`):

```jsx
/* global Sidebar, ChatPane, fetchConfig, fetchThreads, createThread, renameThread as apiRenameThread, pinThread as apiPinThread, deleteThread as apiDeleteThread, sendMessage */
const { useState, useEffect, useRef, useCallback } = React;

const TWEAK_DEFAULTS = { accent: "venom", density: "cozy", showTweaks: false };
const STORAGE_KEY = "enzo.vsr.state.v2";

function loadLocal() {
  try { const raw = localStorage.getItem(STORAGE_KEY); if (raw) return JSON.parse(raw); } catch {}
  return { threads: [], activeId: null, collapsed: false, messages: {} };
}
function saveLocal(s) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(s)); } catch {}
}

function App() {
  const [state, setState] = useState(loadLocal);
  const [config, setConfig] = useState(null);
  const [tweaksOpen, setTweaksOpen] = useState(false);
  const [tweaks, setTweaks] = useState(TWEAK_DEFAULTS);
  const [typing, setTyping] = useState(false);

  useEffect(() => { saveLocal(state); }, [state]);

  // Load config + threads from server on mount
  useEffect(() => {
    fetchConfig().then(c => { if (c) setConfig(c); });
    fetchThreads().then(serverThreads => {
      if (!serverThreads || Object.keys(serverThreads).length === 0) return;
      setState(prev => {
        const merged = Object.entries(serverThreads).map(([id, meta]) => ({
          id, title: meta.title, pinned: meta.pinned, lastMessage: meta.lastMessage,
          messages: prev.messages?.[id] || []
        }));
        const activeId = prev.activeId && merged.find(t => t.id === prev.activeId) ? prev.activeId : (merged[0]?.id || null);
        return { ...prev, threads: merged, activeId, messages: prev.messages || {} };
      });
    });
  }, []);

  useEffect(() => {
    const map = { venom: "#7af201", red: "#e63946", yellow: "#f2c14e", chrome: "#e6e7e8" };
    document.documentElement.style.setProperty("--venom", map[tweaks.accent] || map.venom);
  }, [tweaks.accent]);

  // Tweaks protocol (for Claude Design edit mode)
  useEffect(() => {
    function onMsg(e) {
      const d = e.data || {};
      if (d.type === "__activate_edit_mode") setTweaksOpen(true);
      if (d.type === "__deactivate_edit_mode") setTweaksOpen(false);
    }
    window.addEventListener("message", onMsg);
    window.parent.postMessage({ type: "__edit_mode_available" }, "*");
    return () => window.removeEventListener("message", onMsg);
  }, []);

  function setTweak(k, v) {
    const next = { ...tweaks, [k]: v };
    setTweaks(next);
    window.parent.postMessage({ type: "__edit_mode_set_keys", edits: { [k]: v } }, "*");
  }

  const active = state.threads.find(t => t.id === state.activeId) || null;
  const activeMessages = state.messages?.[state.activeId] || [];
  const activeThread = active ? { ...active, messages: activeMessages } : null;

  function selectThread(id) { setState(s => ({ ...s, activeId: id })); }
  function toggleCollapsed() { setState(s => ({ ...s, collapsed: !s.collapsed })); }

  async function newThread() {
    const id = "t" + Date.now();
    const t = { id, title: "New chat", pinned: false, lastMessage: new Date().toISOString(), messages: [] };
    setState(s => ({
      ...s,
      threads: [t, ...s.threads],
      activeId: id,
      messages: { ...s.messages, [id]: [] }
    }));
    await createThread(id);
  }

  async function handleDeleteThread(id) {
    await apiDeleteThread(id);
    setState(s => {
      const remaining = s.threads.filter(t => t.id !== id);
      const newMessages = { ...s.messages };
      delete newMessages[id];
      if (remaining.length === 0) {
        return { ...s, threads: [], activeId: null, messages: newMessages };
      }
      return { ...s, threads: remaining, activeId: s.activeId === id ? remaining[0].id : s.activeId, messages: newMessages };
    });
  }

  async function handlePinThread(id) {
    await apiPinThread(id);
    setState(s => ({ ...s, threads: s.threads.map(t => t.id === id ? { ...t, pinned: !t.pinned } : t) }));
  }

  async function handleRenameThread(id, title) {
    await apiRenameThread(id, title);
    setState(s => ({ ...s, threads: s.threads.map(t => t.id === id ? { ...t, title } : t) }));
  }

  async function handleSend(text) {
    const t = (text || "").trim();
    if (!t || !state.activeId) return;

    // Add user message
    const userMsg = { who: "me", text: t };
    setState(s => {
      const msgs = [...(s.messages[s.activeId] || []), userMsg];
      let threads = s.threads;
      const thread = threads.find(th => th.id === s.activeId);
      if (thread && (thread.title === "New chat" || thread.messages?.length === 0)) {
        const newTitle = t.slice(0, 48) + (t.length > 48 ? "..." : "");
        threads = threads.map(th => th.id === s.activeId ? { ...th, title: newTitle } : th);
      }
      return { ...s, threads, messages: { ...s.messages, [s.activeId]: msgs } };
    });

    setTyping(true);

    // Call the real API
    const threadId = state.activeId;
    let botText = "";
    let botRefs = null;
    let botStats = null;

    await sendMessage(
      threadId,
      t,
      (text) => { botText = text; },
      (refs) => { botRefs = refs; },
      (stats) => { botStats = stats; },
      (sessionId) => {
        // Done — add bot message
        setTyping(false);
        const botMsg = { who: "bot", text: botText };
        if (botRefs && botRefs.length) botMsg.refs = botRefs;
        if (botStats && botStats.length) botMsg.stats = botStats;
        setState(s => {
          const msgs = [...(s.messages[s.activeId] || []), botMsg];
          const threads = s.threads.map(th => th.id === s.activeId ? { ...th, lastMessage: new Date().toISOString() } : th);
          return { ...s, threads, messages: { ...s.messages, [s.activeId]: msgs } };
        });
      },
      (error) => {
        setTyping(false);
        const errMsg = { who: "bot", text: `Sorry, something went wrong: ${error}` };
        setState(s => {
          const msgs = [...(s.messages[s.activeId] || []), errMsg];
          return { ...s, messages: { ...s.messages, [s.activeId]: msgs } };
        });
      }
    );
  }

  const densityStyle = tweaks.density === "compact"
    ? { "--msg-gap": "14px" } : tweaks.density === "spacious"
    ? { "--msg-gap": "28px" } : { "--msg-gap": "20px" };

  return (
    <div style={{ display: "flex", height: "100vh", width: "100vw", overflow: "hidden", ...densityStyle }}>
      <Sidebar
        threads={state.threads}
        activeId={state.activeId}
        onSelect={selectThread}
        onNew={newThread}
        onDeleteThread={handleDeleteThread}
        onPinThread={handlePinThread}
        onRenameThread={handleRenameThread}
        collapsed={state.collapsed}
        onToggleCollapsed={toggleCollapsed}
        config={config}
      />
      <ChatPane
        thread={activeThread}
        onSend={handleSend}
        onTitleEdit={handleRenameThread}
        config={config}
        typing={typing}
      />
      {tweaksOpen && (
        <div className="tweaks">
          <div style={{ display: "flex", alignItems: "center", marginBottom: 12 }}>
            <div style={{ fontFamily: "Nunito", fontWeight: 900, fontSize: 14, color: "var(--bone)", letterSpacing: "-0.02em" }}>Tweaks</div>
            <div style={{ marginLeft: "auto", fontSize: 10, color: "var(--fg3)", letterSpacing: "0.12em", textTransform: "uppercase", fontWeight: 700 }}>Enzo v2.4</div>
          </div>
          <h4>Accent</h4>
          <div className="row">
            {["venom", "red", "yellow", "chrome"].map(a => (
              <button key={a} className={"seg" + (tweaks.accent === a ? " on" : "")} onClick={() => setTweak("accent", a)}>
                {a === "venom" ? "Green" : a}
              </button>
            ))}
          </div>
          <h4>Density</h4>
          <div className="row">
            {["compact", "cozy", "spacious"].map(d => (
              <button key={d} className={"seg" + (tweaks.density === d ? " on" : "")} onClick={() => setTweak("density", d)}>{d}</button>
            ))}
          </div>
          <div style={{ fontSize: 11, color: "var(--fg3)", lineHeight: 1.5, marginTop: 4, borderTop: "1px solid var(--steel)", paddingTop: 12 }}>
            Threads persist on the server. Pins and renames sync automatically.
          </div>
        </div>
      )}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
```

- [ ] **Step 2: Commit**

```bash
git add launcher/win/app/index.html
git commit -m "feat(chat-ui): async server-synced state, real Agent SDK chat, config-driven UI"
```

---

### Task 10: Update install.ps1 — add Node.js prerequisite + npm install + config prompt

**Files:**
- Modify: `launcher/win/install.ps1`

- [ ] **Step 1: Add Node.js detection + install after the Python scene**

In `launcher/win/install.ps1`, after the WooCommerce integration verification (`Log "VERIFY woocommerce imports OK"`), add:

```powershell
# -- Scene 4.5: Node.js -------------------------------------------
Write-Host ""
Write-Host "  [3.5/5] Checking Node.js..." -ForegroundColor Yellow

if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVer = (node --version 2>&1)
    Write-Host "  OK  Node.js found ($nodeVer)" -ForegroundColor Green
    Log "CHECK node: found $nodeVer"
} else {
    Write-Host "  --  Node.js not found. Installing..." -ForegroundColor Yellow
    $nodeInstalled = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "ACTION install node via winget"
        winget install OpenJS.NodeJS.LTS --scope user --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) { $nodeInstalled = $true }
        else { Log "WARN winget node install failed exit code $LASTEXITCODE" }
    }
    if ($nodeInstalled) {
        RefreshPath
        Start-Sleep -Seconds 2
        RefreshPath
        Write-Host "  OK  Node.js installed" -ForegroundColor Green
        Log "VERIFY node: installed"
    } else {
        Write-Host "  Please install Node.js manually:" -ForegroundColor Yellow
        Write-Host "    Download from https://nodejs.org/" -ForegroundColor Cyan
        Write-Host "    Run the installer, then run START-HERE again" -ForegroundColor Cyan
        Start-Process "https://nodejs.org/"
        FailExit "Install Node.js LTS, then run START-HERE again."
    }
}

# Install chat UI server dependencies
Write-Host "  --  Installing chat UI dependencies..." -ForegroundColor Yellow
$launcherWin = Join-Path $ProjectRoot "launcher\win"
Push-Location $launcherWin
npm install --production 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { FailExit "npm install failed in launcher\win" }
Pop-Location
Write-Host "  OK  Chat UI ready" -ForegroundColor Green
Log "VERIFY npm install OK"
```

- [ ] **Step 2: Add user config prompt after WC credentials**

After the WooCommerce credentials scene and before the desktop shortcut, add:

```powershell
# -- Scene 5.5: User config ----------------------------------------
Write-Host ""
Write-Host "  [4.5/5] Personalizing Enzo" -ForegroundColor Yellow

$enzoDir = Join-Path $ProjectRoot ".enzo"
$configPath = Join-Path $enzoDir "config.json"

if (-not (Test-Path $configPath)) {
    if (-not (Test-Path $enzoDir)) { New-Item -ItemType Directory -Path $enzoDir | Out-Null }
    $name = Read-Host "  Your name (how Enzo will greet you)"
    if (-not $name) { $name = "Team" }
    $role = Read-Host "  Your role (e.g. Shop Owner)"
    if (-not $role) { $role = "User" }

    $configContent = @"
{
  "userName": "$name",
  "userRole": "$role",
  "appName": "Enzo",
  "subtitle": "Viper Shop Assistant",
  "greeting": "Hey $name - what are we wrenching on?",
  "heroSubtext": "Customer questions, tuning advice, or the numbers - ask away.",
  "quickActions": [
    { "icon": "package", "label": "Order lookup", "prompt": "Look up order " },
    { "icon": "zap", "label": "Recommend a setup", "prompt": "Recommend a setup for " },
    { "icon": "chart", "label": "Sales report", "prompt": "Pull a sales report for " },
    { "icon": "book", "label": "Product specs", "prompt": "Give me the specs for " }
  ],
  "suggestions": [
    { "icon": "zap", "label": "Best chassis for 12V drag racing?" },
    { "icon": "package", "label": "Check order status by number" },
    { "icon": "chart", "label": "Q1 sales summary" },
    { "icon": "wrench", "label": "Mega-G+ tuning walkthrough" },
    { "icon": "flag", "label": "SCDRL Spring Nationals details" },
    { "icon": "users", "label": "Top customers by lifetime value" }
  ],
  "disclaimer": "Enzo can make mistakes on live orders - double-check dollar figures before replying to customers.",
  "port": 3456
}
"@
    Set-Content -Path $configPath -Value $configContent -Encoding UTF8
    Write-Host "  OK  Enzo configured for $name" -ForegroundColor Green
    Log "WRITE .enzo/config.json for $name"
} else {
    Write-Host "  OK  Config already exists" -ForegroundColor Green
    Log "CHECK .enzo/config.json: exists"
}
```

- [ ] **Step 3: Update the desktop shortcut to point to launch-ui.bat**

Change the shortcut target from `launch.bat` to `launch-ui.bat`:

```powershell
$shortcut.TargetPath = Join-Path $launcherDir "launch-ui.bat"
```

- [ ] **Step 4: Commit**

```bash
git add launcher/win/install.ps1
git commit -m "feat(chat-ui): add Node.js prereq, npm install, user config prompt, shortcut to launch-ui.bat"
```

---

### Task 11: End-to-end smoke test (local Mac)

**Files:** None — this is testing.

- [ ] **Step 1: Start the server**

```bash
cd /Users/michaelatherton/viper-second-brain
node launcher/win/server.mjs &
```

- [ ] **Step 2: Verify health**

```bash
curl -s http://localhost:3456/health
```

Expected: `{"ok":true,"version":"1.0.0"}`

- [ ] **Step 3: Verify config**

```bash
curl -s http://localhost:3456/config | python3 -m json.tool | head -5
```

Expected: shows userName, appName, etc.

- [ ] **Step 4: Open the UI in browser**

```bash
open http://localhost:3456
```

Verify: Enzo chat UI loads with Dan's name in the hero greeting and sidebar footer.

- [ ] **Step 5: Create a new thread and send a message**

In the browser:
1. Click "New Chat"
2. Type "What's our return policy for opened armatures?"
3. Press Enter
4. Wait for response (typing indicator shows for ~5-20 seconds)
5. Verify: response appears with Enzo's voice, mentions Dan's policies

- [ ] **Step 6: Verify thread persistence**

```bash
cat /Users/michaelatherton/viper-second-brain/.enzo/threads.json | python3 -m json.tool
```

Expected: shows the thread with a sessionId and title auto-set from the first message.

- [ ] **Step 7: Test multi-turn**

Send a follow-up message in the same thread: "What if the customer is a repeat buyer?"

Verify: Enzo responds with context from the prior message (knows we were talking about return policy).

- [ ] **Step 8: Test product question with refs**

Create a new thread, send: "Do we have V3 magnet clips in stock?"

Verify: response includes a ProductRef card with price, SKU, and stock status. (If JSON fallback triggers, the answer appears as plain text — still acceptable.)

- [ ] **Step 9: Kill the server**

```bash
kill %1
```

- [ ] **Step 10: Commit all remaining changes**

```bash
git add -A
git commit -m "feat(chat-ui): end-to-end integration complete - server, UI, config, launch"
```
