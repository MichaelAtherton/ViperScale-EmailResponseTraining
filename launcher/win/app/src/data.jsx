/* global React */
/* Data layer for Enzo Chat UI.
   Handles: API communication, JSON extraction, clipboard copy, link parsing.
   Seed data removed - threads come from the server. */

const ENZO_API = window.location.origin;

function extractJSON(text) {
  const start = text.indexOf("{");
  if (start === -1) return null;
  for (let end = text.length; end > start; end--) {
    if (text[end - 1] !== "}") continue;
    try { return JSON.parse(text.slice(start, end)); } catch {}
  }
  return null;
}

async function fetchConfig() {
  try {
    const res = await fetch(ENZO_API + "/config");
    return await res.json();
  } catch { return null; }
}

async function fetchThreads() {
  try {
    const res = await fetch(ENZO_API + "/threads");
    return await res.json();
  } catch { return {}; }
}

async function createThread(threadId) {
  try {
    const res = await fetch(ENZO_API + "/threads/new", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ threadId })
    });
    return await res.json();
  } catch { return null; }
}

async function apiRenameThread(threadId, title) {
  try {
    await fetch(ENZO_API + "/threads/" + threadId + "/title", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title })
    });
  } catch {}
}

async function apiPinThread(threadId) {
  try {
    const res = await fetch(ENZO_API + "/threads/" + threadId + "/pin", { method: "POST" });
    return await res.json();
  } catch { return null; }
}

async function apiDeleteThread(threadId) {
  try {
    await fetch(ENZO_API + "/threads/" + threadId, { method: "DELETE" });
  } catch {}
}

async function sendMessage(threadId, message, onText, onRefs, onStats, onDone, onError) {
  try {
    const res = await fetch(ENZO_API + "/chat", {
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

function parseLinks(text, refs) {
  if (!text) return [];
  var map = {};
  (refs || []).forEach(function(r) {
    var label = r.kind === "order" ? "Order #" + r.id : r.name;
    if (r.url) map[label] = r.url;
  });
  var out = [];
  var re = /\{([^}]+)\}/g;
  var last = 0, m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push({ type: "text", text: text.slice(last, m.index) });
    var label = m[1];
    var url = map[label];
    if (url) out.push({ type: "link", text: label, url: url });
    else out.push({ type: "text", text: label });
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push({ type: "text", text: text.slice(last) });
  return out;
}

function escHTML(s) {
  return String(s).replace(/[&<>"']/g, function(c) { return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]; });
}

function messageToEmailHTML(m) {
  var segs = parseLinks(m.text, m.refs);
  var bodyHTML = segs.map(function(s) {
    return s.type === "link"
      ? '<a href="' + escHTML(s.url) + '" style="color:#0a6b00;text-decoration:underline;">' + escHTML(s.text) + '</a>'
      : escHTML(s.text).replace(/\n/g, "<br>");
  }).join("");

  var productsHTML = "";
  var products = (m.refs || []).filter(function(r) { return r.kind === "product"; });
  if (products.length) {
    productsHTML = '<table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;"><tr style="background:#f2f4f2;"><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Product</th><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">SKU</th><th style="text-align:right;padding:8px 12px;border-bottom:1px solid #ccc;">Price</th><th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Stock</th></tr>' + products.map(function(p) { return '<tr><td style="padding:8px 12px;border-bottom:1px solid #eee;"><a href="' + escHTML(p.url || "#") + '" style="color:#0a6b00;text-decoration:underline;font-weight:600;">' + escHTML(p.name) + '</a></td><td style="padding:8px 12px;border-bottom:1px solid #eee;font-family:monospace;color:#555;">' + escHTML(p.sku || "") + '</td><td style="padding:8px 12px;border-bottom:1px solid #eee;text-align:right;font-weight:600;">$' + p.price.toFixed(2) + '</td><td style="padding:8px 12px;border-bottom:1px solid #eee;color:' + (p.stock === "In Stock" ? "#0a6b00" : "#a86b00") + ';">' + escHTML(p.stock || "") + '</td></tr>'; }).join("") + '</table>';
  }

  var orders = (m.refs || []).filter(function(r) { return r.kind === "order"; });
  var ordersHTML = orders.map(function(o) { return '<div style="margin-top:12px;padding:10px 12px;border:1px solid #ddd;border-radius:6px;font-family:Arial,sans-serif;font-size:14px;"><div style="font-weight:600;"><a href="' + escHTML(o.url || "#") + '" style="color:#0a6b00;text-decoration:underline;">Order #' + escHTML(o.id) + '</a> - <span style="color:' + (o.status === "Shipped" ? "#0a6b00" : "#a86b00") + ';">' + escHTML(o.status) + '</span></div><div style="color:#555;margin-top:2px;">' + escHTML(o.customer) + ' - ' + escHTML(o.items) + ' - $' + o.total.toFixed(2) + ' - ' + escHTML(o.date) + '</div></div>'; }).join("");

  var statsHTML = "";
  if (m.stats) {
    statsHTML = '<table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;"><tr>' + m.stats.map(function(s) { return '<td style="padding:8px 16px 8px 0;border-right:1px solid #eee;"><div style="font-size:11px;color:#888;text-transform:uppercase;letter-spacing:0.08em;font-weight:600;">' + escHTML(s.label) + '</div><div style="font-size:20px;font-weight:700;color:#111;margin-top:2px;">' + escHTML(s.value) + '</div>' + (s.sub ? '<div style="font-size:12px;color:#0a6b00;">' + escHTML(s.sub) + '</div>' : "") + '</td>'; }).join("") + '</tr></table>';
  }

  return '<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.55;color:#111;">' + bodyHTML + productsHTML + ordersHTML + statsHTML + '</div>';
}

function messageToPlainText(m) {
  var segs = parseLinks(m.text, m.refs);
  var out = segs.map(function(s) { return s.type === "link" ? s.text + " (" + s.url + ")" : s.text; }).join("");
  var products = (m.refs || []).filter(function(r) { return r.kind === "product"; });
  if (products.length) {
    out += "\n\n" + products.map(function(p) { return "- " + p.name + " - $" + p.price.toFixed(2) + " (" + (p.sku || "-") + ", " + (p.stock || "") + ")\n  " + (p.url || ""); }).join("\n");
  }
  var orders = (m.refs || []).filter(function(r) { return r.kind === "order"; });
  orders.forEach(function(o) {
    out += "\n\nOrder #" + o.id + " - " + o.status + "\n" + o.customer + " - " + o.items + " - $" + o.total.toFixed(2) + " - " + o.date + "\n" + (o.url || "");
  });
  if (m.stats) {
    out += "\n\n" + m.stats.map(function(s) { return s.label + ": " + s.value + (s.sub ? " (" + s.sub + ")" : ""); }).join(" | ");
  }
  return out;
}

async function copyMessageForEmail(m) {
  var html = messageToEmailHTML(m);
  var text = messageToPlainText(m);
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
  fetchConfig, fetchThreads, createThread, apiRenameThread, apiPinThread, apiDeleteThread,
  sendMessage, parseLinks, messageToEmailHTML, messageToPlainText,
  copyMessageForEmail, copyMessageAsText, extractJSON
});
