/* global React */
/* Seed data + canned response library for the Enzo prototype.
   Text uses {Name} tokens that resolve to refs[] entries — rendered as
   inline hyperlinks in the UI and in the Copy-for-Email HTML. */

const BASE = "https://viperscaleracing.com";
const purl = (slug) => `${BASE}/product/${slug}`;
const ourl = (id) => `${BASE}/admin/orders/${id}`;

const SEED_THREADS = [
  {
    id: "t1",
    title: "12V drag setup — which chassis?",
    folder: "Customer Support",
    pinned: true,
    updated: Date.now() - 1000 * 60 * 4,
    messages: [
      { who: "me", text: "Running a 12V routed track for SCDRL. What chassis holds up best?" },
      { who: "bot",
        text: "Good call. For 12V drag on a routed track, I'd start you on the {V1 Production Modified} — runs cool at that voltage and the 6-ohm red-wire armature holds up over long sessions. Pair it with {PST Tires M1 Firm} for Sintra surface. If you want more bite on a rubberized track, switch to M3.",
        refs: [
          { kind: "product", name: "V1 Production Modified", price: 134.95, sku: "VSR-V1-PM", stock: "In Stock", url: purl("v1-production-modified") },
          { kind: "product", name: "PST Tires M1 Firm", price: 7.50, sku: "PST-M1-275", stock: "In Stock", url: purl("pst-tires-m1-firm") }
        ]
      },
      { who: "me", text: "What's the difference between V1 and V3?" },
      { who: "bot", text: "Short version: {V1 Production Modified} is our bread-and-butter production chassis — lower, lighter, more durable than the old G-Jet. {V3 Race Platform} is race-only with a magnesium-reinforced pan, adjustable pinion mesh, and the Super G+ armature. V3 shaves about 0.08s off a 55-ft ET in our testing, but it's less forgiving and needs more tuning. If this is your first drag build, stay on V1.",
        refs: [
          { kind: "product", name: "V1 Production Modified", price: 134.95, sku: "VSR-V1-PM", stock: "In Stock", url: purl("v1-production-modified") },
          { kind: "product", name: "V3 Race Platform", price: 189.95, sku: "VSR-V3-RP", stock: "In Stock", url: purl("v3-race-platform") }
        ]
      }
    ]
  },
  {
    id: "t2",
    title: "Order #VSR-24718 — shipping status",
    folder: "Customer Support",
    pinned: false,
    updated: Date.now() - 1000 * 60 * 62,
    messages: [
      { who: "me", text: "Where's order VSR-24718?" },
      { who: "bot", text: "Got it — {Order #VSR-24718} left the shop Tuesday afternoon via USPS Priority. Should hit the customer's door Friday based on the tracking scan pattern. Tracking: {USPS 9400 1112 0287 3456 7890 12}.",
        refs: [
          { kind: "order", id: "VSR-24718", customer: "Marcus Lee", items: "3 items", total: 184.40, date: "Apr 15", status: "Shipped", url: ourl("VSR-24718") },
          { kind: "link", name: "USPS 9400 1112 0287 3456 7890 12", url: "https://tools.usps.com/go/TrackConfirmAction?tLabels=9400111202873456789012" }
        ]
      }
    ]
  },
  {
    id: "t3",
    title: "Mega-G+ hop-ups — what do we carry?",
    folder: "Product",
    pinned: false,
    updated: Date.now() - 1000 * 60 * 60 * 26,
    messages: [
      { who: "me", text: "Full list of Mega-G+ hop-ups we stock?" },
      { who: "bot", text: "Here's the current Mega-G+ hop-up kit lineup — all in stock except the silicones, which are running low. In order of ET impact: {Mega-G+ Neo Traction Magnets}, {Mega-G+ Super Armature}, {Mega-G+ Silicone Rear Tires}, and cheap wear item {Mega-G+ Pickup Shoes (pair)}.",
        refs: [
          { kind: "product", name: "Mega-G+ Neo Traction Magnets", price: 18.95, sku: "MG-NEO", stock: "In Stock", url: purl("mega-g-neo-magnets") },
          { kind: "product", name: "Mega-G+ Super Armature", price: 42.95, sku: "MG-ARM-6", stock: "In Stock", url: purl("mega-g-super-armature") },
          { kind: "product", name: "Mega-G+ Silicone Rear Tires", price: 8.50, sku: "MG-SIL-R", stock: "Low Stock", url: purl("mega-g-silicone-rear") },
          { kind: "product", name: "Mega-G+ Pickup Shoes (pair)", price: 6.95, sku: "MG-PU", stock: "In Stock", url: purl("mega-g-pickup-shoes") }
        ]
      }
    ]
  },
  {
    id: "t4",
    title: "Q1 sales — what's moving?",
    folder: "Business",
    pinned: true,
    updated: Date.now() - 1000 * 60 * 60 * 3,
    messages: [
      { who: "me", text: "Summarize Q1 sales. What's hot, what's not?" },
      { who: "bot", text: "Q1 closed strong — up 18% over Q1 last year, driven almost entirely by the {V1 Production Modified} launch in February. Chassis category is +34%. Hop-up parts are flat. Body-only SKUs are down 11% — worth a look. Full dashboard: {Q1 2026 Sales Report}.",
        refs: [
          { kind: "product", name: "V1 Production Modified", price: 134.95, sku: "VSR-V1-PM", stock: "In Stock", url: purl("v1-production-modified") },
          { kind: "link", name: "Q1 2026 Sales Report", url: `${BASE}/admin/reports/q1-2026` }
        ],
        stats: [
          { label: "Q1 Revenue", value: "$142.8K", sub: "+18% YoY", tone: "good" },
          { label: "Orders", value: "1,284", sub: "+12% YoY", tone: "good" },
          { label: "Avg Order", value: "$111.18", sub: "+5.4%", tone: "good" }
        ]
      }
    ]
  },
  {
    id: "t5",
    title: "SCDRL Spring Nationals registration",
    folder: "SCDRL",
    pinned: false,
    updated: Date.now() - 1000 * 60 * 60 * 24 * 2,
    messages: [
      { who: "me", text: "When's the registration deadline for Spring Nationals?" },
      { who: "bot", text: "Registration closes Friday, May 2 at midnight ET. Currently 47 racers signed up across the four classes. Track build starts May 10 — Production Mod class alone is at 19, which is almost the cap. Sign-up link: {Spring Nationals Registration}.",
        refs: [
          { kind: "link", name: "Spring Nationals Registration", url: `${BASE}/scdrl/spring-nationals-2026` }
        ]
      }
    ]
  },
  {
    id: "t6",
    title: "Return policy for opened armature",
    folder: "Customer Support",
    pinned: false,
    updated: Date.now() - 1000 * 60 * 60 * 24 * 4,
    messages: [
      { who: "me", text: "Customer opened a Super G+ armature and wants to return it. Policy?" },
      { who: "bot", text: "Opened motor parts are normally final sale — the epoxy can crack in installation and we can't resell it safely. That said, if they haven't soldered it to a chassis yet, use your judgment. For a repeat racer (3+ orders), I'd offer store credit at 80% and eat the restock. Full policy: {Returns & Warranty}.",
        refs: [
          { kind: "link", name: "Returns & Warranty", url: `${BASE}/returns` }
        ]
      }
    ]
  },
  {
    id: "t7",
    title: "Tire compound cheat sheet",
    folder: "Product",
    pinned: false,
    updated: Date.now() - 1000 * 60 * 60 * 24 * 7,
    messages: [
      { who: "me", text: "Quick reference for tire compounds?" },
      { who: "bot", text: "Here's the short version. M1 firm for Sintra / routed wood — low grip surface, you want the tire to slide predictably. M2 medium for rubberized tracks. M3 soft for polished track surfaces or when it's cold. Silicone rears for drag strips only — they heat up and grip like nothing else but wear fast." }
    ]
  }
];

const SUGGESTIONS_HOME = [
  { icon: "zap", label: "Best chassis for 12V drag racing?" },
  { icon: "package", label: "Check order status by number" },
  { icon: "chart", label: "Q1 sales summary" },
  { icon: "wrench", label: "Mega-G+ tuning walkthrough" },
  { icon: "flag", label: "SCDRL Spring Nationals details" },
  { icon: "users", label: "Top customers by lifetime value" },
];

const QUICK_ACTIONS = [
  { icon: "package", label: "Order lookup", prompt: "Look up order " },
  { icon: "zap", label: "Recommend a setup", prompt: "Recommend a setup for " },
  { icon: "chart", label: "Sales report", prompt: "Pull a sales report for " },
  { icon: "book", label: "Product specs", prompt: "Give me the specs for " },
];

function enzoReply(userText) {
  const t = userText.toLowerCase();

  if (/order\s*#?\s*[a-z0-9-]+/.test(t) || t.includes("shipping") || t.includes("tracking")) {
    return {
      text: "Pulled that up — {Order #VSR-24819} is on the move. Tracking: {USPS 9400 1112 0287 3456 7891 23}. Want me to draft a tracking email to the customer?",
      refs: [
        { kind: "order", id: "VSR-24819", customer: "Dana Reyes", items: "2 items · V1 Chassis, PST M1 Tires", total: 142.45, date: "Apr 19", status: "Shipped", url: ourl("VSR-24819") },
        { kind: "link", name: "USPS 9400 1112 0287 3456 7891 23", url: "https://tools.usps.com/go/TrackConfirmAction?tLabels=9400111202873456789123" }
      ]
    };
  }
  if (t.includes("q1") || t.includes("sales") || t.includes("revenue") || t.includes("report")) {
    return {
      text: "Here's the top-line. Chassis is carrying the quarter — {V1 Production Modified} launch landed hard. Hop-ups are flat; bodies are down. Full breakdown in the {April Sales Dashboard}.",
      refs: [
        { kind: "product", name: "V1 Production Modified", price: 134.95, sku: "VSR-V1-PM", stock: "In Stock", url: purl("v1-production-modified") },
        { kind: "link", name: "April Sales Dashboard", url: `${BASE}/admin/reports/april-2026` }
      ],
      stats: [
        { label: "MTD Revenue", value: "$52.4K", sub: "+22% vs Apr '25", tone: "good" },
        { label: "Orders", value: "471", sub: "+14%", tone: "good" },
        { label: "Return Rate", value: "2.1%", sub: "-0.4pp", tone: "good" }
      ]
    };
  }
  if (t.includes("chassis") || t.includes("12v") || t.includes("setup") || t.includes("recommend")) {
    return {
      text: "For 12V on a routed track, start on the {V1 Production Modified} — tuned to run cool at that voltage, and the 6-ohm armature is bulletproof. Pair with {PST Tires M1 Firm} on Sintra, M3 soft on rubberized. Skip silicone unless you're drag-only.",
      refs: [
        { kind: "product", name: "V1 Production Modified", price: 134.95, sku: "VSR-V1-PM", stock: "In Stock", url: purl("v1-production-modified") },
        { kind: "product", name: "PST Tires M1 Firm", price: 7.50, sku: "PST-M1-275", stock: "In Stock", url: purl("pst-tires-m1-firm") }
      ]
    };
  }
  if (t.includes("hop") || t.includes("mega-g") || t.includes("upgrade") || t.includes("mega g")) {
    return {
      text: "Mega-G+ hop-up stack, in install order: {Mega-G+ Neo Traction Magnets} first (biggest ET gain per dollar), then {Mega-G+ Super Armature}, then {Mega-G+ Silicone Rear Tires}. Keep a set of {Mega-G+ Pickup Shoes (pair)} on the bench — they're a cheap wear item.",
      refs: [
        { kind: "product", name: "Mega-G+ Neo Traction Magnets", price: 18.95, sku: "MG-NEO", stock: "In Stock", url: purl("mega-g-neo-magnets") },
        { kind: "product", name: "Mega-G+ Super Armature", price: 42.95, sku: "MG-ARM-6", stock: "In Stock", url: purl("mega-g-super-armature") },
        { kind: "product", name: "Mega-G+ Silicone Rear Tires", price: 8.50, sku: "MG-SIL-R", stock: "Low Stock", url: purl("mega-g-silicone-rear") },
        { kind: "product", name: "Mega-G+ Pickup Shoes (pair)", price: 6.95, sku: "MG-PU", stock: "In Stock", url: purl("mega-g-pickup-shoes") }
      ]
    };
  }
  if (t.includes("scdrl") || t.includes("nationals") || t.includes("tournament") || t.includes("race")) {
    return {
      text: "Spring Nationals: registration closes May 2 at midnight ET. 47 racers registered across four classes. Production Mod is at 19/24 — probably capping this week. Sign-up: {Spring Nationals Registration}.",
      refs: [
        { kind: "link", name: "Spring Nationals Registration", url: `${BASE}/scdrl/spring-nationals-2026` }
      ]
    };
  }
  if (t.includes("return") || t.includes("refund") || t.includes("policy")) {
    return {
      text: "Default return window is 30 days, unopened and unused. Opened electronics (motors, armatures, controllers) are final sale — epoxy cracks during install. For repeat racers with 3+ orders, use your judgment and offer store credit at 80%. Full policy: {Returns & Warranty}.",
      refs: [
        { kind: "link", name: "Returns & Warranty", url: `${BASE}/returns` }
      ]
    };
  }
  if (t.includes("customer") || t.includes("ltv") || t.includes("top")) {
    return {
      text: "Top 3 by lifetime value over the last 24 months. Marcus is the big one — almost entirely chassis and armature. Dana is steady monthly orders. Jordan spikes around SCDRL events. Dig in: {Customer LTV Dashboard}.",
      refs: [
        { kind: "link", name: "Customer LTV Dashboard", url: `${BASE}/admin/customers/ltv` }
      ],
      stats: [
        { label: "#1 Customer", value: "$4,218", sub: "Marcus Lee", tone: "good" },
        { label: "#2 Customer", value: "$3,614", sub: "Dana Reyes", tone: "good" },
        { label: "#3 Customer", value: "$2,892", sub: "Jordan Park", tone: "good" }
      ]
    };
  }
  if (t.includes("tire") || t.includes("compound")) {
    return {
      text: "Tire cheat sheet. M1 firm for Sintra and routed wood. M2 medium for rubberized surfaces. M3 soft for polished or cold tracks. Silicone rears for drag only — they grip like crazy when warm, but they chunk up inside 50 runs."
    };
  }
  if (t.includes("spec") || t.includes("dimension") || t.includes("size")) {
    return {
      text: "Which product? Toss me a SKU or a name and I'll pull the full spec sheet — voltage range, armature ohms, gear ratio, pickup shoe part number, all of it."
    };
  }
  return {
    text: "Happy to dig in — give me a bit more to work with. Are you asking about a specific product, a customer's order, tuning advice, or internal numbers? Any of those I can pull up fast."
  };
}

/* ----- Link resolution + serializers ----- */

// Parse a template string with {Name} tokens against refs[], returning
// an array of segments: {type:'text',text} or {type:'link',text,url}.
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

// Serialize an Enzo message to email-ready HTML (links preserved, tables for cards).
function messageToEmailHTML(m) {
  const segs = parseLinks(m.text, m.refs);
  const bodyHTML = segs.map(s => s.type === "link"
    ? `<a href="${escHTML(s.url)}" style="color:#0a6b00;text-decoration:underline;">${escHTML(s.text)}</a>`
    : escHTML(s.text).replace(/\n/g, "<br>")
  ).join("");

  let productsHTML = "";
  const products = (m.refs || []).filter(r => r.kind === "product");
  if (products.length) {
    productsHTML = `
      <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;">
        <tr style="background:#f2f4f2;">
          <th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Product</th>
          <th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">SKU</th>
          <th style="text-align:right;padding:8px 12px;border-bottom:1px solid #ccc;">Price</th>
          <th style="text-align:left;padding:8px 12px;border-bottom:1px solid #ccc;">Stock</th>
        </tr>
        ${products.map(p => `
          <tr>
            <td style="padding:8px 12px;border-bottom:1px solid #eee;">
              <a href="${escHTML(p.url || "#")}" style="color:#0a6b00;text-decoration:underline;font-weight:600;">${escHTML(p.name)}</a>
            </td>
            <td style="padding:8px 12px;border-bottom:1px solid #eee;font-family:monospace;color:#555;">${escHTML(p.sku || "")}</td>
            <td style="padding:8px 12px;border-bottom:1px solid #eee;text-align:right;font-weight:600;">$${p.price.toFixed(2)}</td>
            <td style="padding:8px 12px;border-bottom:1px solid #eee;color:${p.stock === "In Stock" ? "#0a6b00" : "#a86b00"};">${escHTML(p.stock || "")}</td>
          </tr>
        `).join("")}
      </table>
    `;
  }

  const orders = (m.refs || []).filter(r => r.kind === "order");
  const ordersHTML = orders.map(o => `
    <div style="margin-top:12px;padding:10px 12px;border:1px solid #ddd;border-radius:6px;font-family:Arial,sans-serif;font-size:14px;">
      <div style="font-weight:600;"><a href="${escHTML(o.url || "#")}" style="color:#0a6b00;text-decoration:underline;">Order #${escHTML(o.id)}</a> — <span style="color:${o.status === "Shipped" ? "#0a6b00" : "#a86b00"};">${escHTML(o.status)}</span></div>
      <div style="color:#555;margin-top:2px;">${escHTML(o.customer)} · ${escHTML(o.items)} · $${o.total.toFixed(2)} · ${escHTML(o.date)}</div>
    </div>
  `).join("");

  let statsHTML = "";
  if (m.stats) {
    statsHTML = `
      <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin-top:12px;font-family:Arial,sans-serif;font-size:14px;">
        <tr>${m.stats.map(s => `
          <td style="padding:8px 16px 8px 0;border-right:1px solid #eee;">
            <div style="font-size:11px;color:#888;text-transform:uppercase;letter-spacing:0.08em;font-weight:600;">${escHTML(s.label)}</div>
            <div style="font-size:20px;font-weight:700;color:#111;margin-top:2px;">${escHTML(s.value)}</div>
            ${s.sub ? `<div style="font-size:12px;color:#0a6b00;">${escHTML(s.sub)}</div>` : ""}
          </td>
        `).join("")}</tr>
      </table>
    `;
  }

  return `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.55;color:#111;">${bodyHTML}${productsHTML}${ordersHTML}${statsHTML}</div>`;
}

// Plain-text fallback: "Label (url)" inline.
function messageToPlainText(m) {
  const segs = parseLinks(m.text, m.refs);
  let out = segs.map(s => s.type === "link" ? `${s.text} (${s.url})` : s.text).join("");
  const products = (m.refs || []).filter(r => r.kind === "product");
  if (products.length) {
    out += "\n\n" + products.map(p => `• ${p.name} — $${p.price.toFixed(2)} (${p.sku || "—"}, ${p.stock || ""})\n  ${p.url || ""}`).join("\n");
  }
  const orders = (m.refs || []).filter(r => r.kind === "order");
  orders.forEach(o => {
    out += `\n\nOrder #${o.id} — ${o.status}\n${o.customer} · ${o.items} · $${o.total.toFixed(2)} · ${o.date}\n${o.url || ""}`;
  });
  if (m.stats) {
    out += "\n\n" + m.stats.map(s => `${s.label}: ${s.value}${s.sub ? ` (${s.sub})` : ""}`).join(" · ");
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
  } catch (e) { /* fallback */ }
  try { await navigator.clipboard.writeText(text); return true; } catch (e) {}
  return false;
}

async function copyMessageAsText(m) {
  try { await navigator.clipboard.writeText(messageToPlainText(m)); return true; } catch (e) { return false; }
}

Object.assign(window, { SEED_THREADS, SUGGESTIONS_HOME, QUICK_ACTIONS, enzoReply, parseLinks, messageToEmailHTML, messageToPlainText, copyMessageForEmail, copyMessageAsText });
