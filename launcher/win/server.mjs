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

function extractJSON(text) {
  const start = text.indexOf("{");
  if (start === -1) return null;
  for (let end = text.length; end > start; end--) {
    if (text[end - 1] !== "}") continue;
    try { return JSON.parse(text.slice(start, end)); } catch {}
  }
  return null;
}

const app = express();
app.use(express.json());
app.use("/", express.static(join(__dirname, "app")));

app.get("/health", (req, res) => {
  res.json({ ok: true, version: "1.0.0" });
});

app.get("/config", (req, res) => {
  res.json(loadConfig());
});

app.get("/threads", (req, res) => {
  res.json(loadThreads());
});

app.post("/threads/new", (req, res) => {
  const { threadId } = req.body;
  if (!threadId) return res.status(400).json({ error: "threadId required" });
  const threads = loadThreads();
  threads[threadId] = { sessionId: null, title: "New chat", pinned: false, lastMessage: new Date().toISOString(), messageCount: 0 };
  saveThreads(threads);
  res.json({ threadId, sessionId: null });
});

app.post("/threads/:id/title", (req, res) => {
  const { title } = req.body;
  const threads = loadThreads();
  if (!threads[req.params.id]) return res.status(404).json({ error: "thread not found" });
  threads[req.params.id].title = title;
  saveThreads(threads);
  res.json({ ok: true });
});

app.post("/threads/:id/pin", (req, res) => {
  const threads = loadThreads();
  if (!threads[req.params.id]) return res.status(404).json({ error: "thread not found" });
  threads[req.params.id].pinned = !threads[req.params.id].pinned;
  saveThreads(threads);
  res.json({ ok: true, pinned: threads[req.params.id].pinned });
});

app.delete("/threads/:id", (req, res) => {
  const threads = loadThreads();
  delete threads[req.params.id];
  saveThreads(threads);
  res.json({ ok: true });
});

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
