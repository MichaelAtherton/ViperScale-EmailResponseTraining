# Design Doc: Marsh Remembers — Relationship Awareness System

**Date:** 2026-04-08
**Author:** Michael Atherton / AI Revolution Labs
**Vault:** Viper Scale Racing — Client Second Brain
**Status:** Draft — pending review before implementation

---

## The Problem We're Solving

Dan opens the vault and says "hello." Marsh responds with "Hey Dan — what do you need?" — a cold, stateless greeting that treats Dan like a stranger, even though the vault already knows his business inside and out.

This happened in our first live test. Marsh skipped the introduction entirely and delivered a returning-user greeting on the very first interaction. When Dan pushed back with "What do you mean what do you need? How do I start?", Marsh had to backtrack, apologize, and read the files he should have read before responding.

This isn't just a bug — it undermines the core promise. Marsh is supposed to be a teammate who knows Dan. A teammate who forgets whether they've met you isn't a teammate. It's a tool that reboots.

---

## What Dan Should Experience

### First time ever
Dan opens the vault. Before he even types, Marsh already knows it's a first meeting. Marsh introduces himself, demonstrates knowledge of Dan's business using specific details, and invites Dan to start working together. This happens reliably, every time, with no possibility of the cold "what do you need?" greeting.

### Coming back the next day
Marsh recognizes Dan. No re-introduction. But the greeting has warmth and context: what they worked on last time, what's changed, maybe a reference to something notable from the previous session. Like walking into the shop where the mechanic remembers your car.

### Coming back after a week
Marsh notices it's been a while. The greeting reflects that — "Hey Dan, been a few days" — and might mention that knowledge has grown or suggest picking up where they left off.

### Three months in
Marsh and Dan have history. Dozens of sessions, hundreds of Q&A pairs, product rules refined through corrections. The greeting is casual shorthand between people who know each other well. The relationship is evident in how Marsh talks, what he references, and the confidence he brings to drafts.

---

## Why This Matters (Not Engineering — Value)

### For Dan
The difference between a tool and a teammate is whether it remembers you. Dan trained Abby over months. He's about to train Marsh. If Marsh forgets the relationship every session, it feels like training a new employee every day. That's exhausting and it kills trust.

When Marsh remembers — what they've worked on, how the knowledge base has grown, the corrections Dan made — it reinforces that Dan's investment is accumulating. Every session builds on the last. That's the feeling that keeps Dan coming back.

### For AIRL's product
A Client Second Brain that develops a relationship with the user is not replaceable. A ChatGPT prompt is. If a competitor offers Dan a cheaper AI email tool, he'd have to start the relationship from scratch. The switching cost isn't the data (that's exportable) — it's the relationship. The AI that knows how Dan likes to work, what he's already taught, how long they've been building together. That's the moat.

### For the onboarding moment
The first interaction is when Dan decides whether this was worth the money. If Marsh fumbles the greeting — which he did in our test — that moment is lost. A reliable, impressive first meeting sets the tone for everything that follows.

---

## How It Works

### The core insight
We don't need to rely on Claude remembering to read files before responding. We can INJECT context into the conversation before Claude generates its first word, using a SessionStart hook. This is mechanical — it runs every time, guaranteed, no LLM judgment required.

### What the SessionStart hook does

When Dan starts a new session, a shell script runs automatically and produces a context briefing. This briefing is injected into Claude's context before Claude generates any response. The briefing contains:

**Has Marsh met Dan before?**
Checked by looking for a "First met" date in the relationship file. If no date exists, this is the first meeting — Marsh must do the full introduction.

**How long since the last session?**
Derived from the git log. The most recent commit timestamp tells us whether it's been minutes, hours, or days. This drives the "back already?" vs "been a while" calibration.

**What happened recently?**
The last few git commits show what knowledge was added or updated. Marsh can reference this naturally: "I see we added some tire rules last time."

**How big is the knowledge base?**
A count of email examples, product rules, and Facebook examples. This is the "look how far we've come" data. After 50 sessions, Marsh can say "We've got 200 Q&A pairs now — I'm getting pretty good at this."

**Any relationship notes?**
Specific things worth remembering — Dan's working preferences, notable moments, inside references that accumulated over time.

### What the relationship file captures

A lightweight file at `.claude/src/relationship.md` that Marsh writes to during sessions when something notable happens. Not a session log — just the moments that matter to the relationship:

- When they first met
- Working preferences Dan has expressed ("Dan likes to paste emails without preamble")
- Notable milestones ("First email Dan sent without editing Marsh's draft")
- Corrections that revealed something about how Dan thinks
- Inside references or patterns ("Dan calls the Magnet Traction tires 'the pain in the ass ones'")

This file stays small — maybe 20-30 lines after months of use. The git log handles the factual history (what was worked on, when). The relationship file handles the human layer.

### How Marsh writes to the relationship file

Marsh is instructed in his persona file to update the relationship when something notable happens. This is LLM-dependent — sometimes he'll remember, sometimes he won't. But that's OK for two reasons:

1. The SessionStart briefing already provides the factual context (time since last session, recent activity, knowledge base size) from git data. That's mechanical and reliable.

2. The relationship file is the ENRICHMENT layer, not the foundation. If Marsh forgets to note that Dan prefers terse greetings, the worst case is Marsh's greeting is slightly less personalized — not that he forgets who Dan is entirely.

Over time, the relationship file accumulates enough notes to meaningfully shape the interaction. But it doesn't need to be perfect from day one.

---

## What Changes in the Vault

### New file: `.claude/src/relationship.md`
Starting state for Dan's vault:

```markdown
# Marsh & Dan

## First Meeting
[not yet — Marsh will fill this in after the first session]

## How Dan Likes to Work
[learning — will be updated as patterns emerge]

## Notable Moments
[none yet]
```

### New script: `.claude/hooks/session-briefing.sh`
Runs on SessionStart. Reads git log and relationship.md. Outputs a JSON object with `additionalContext` that gets injected into Claude's context before any response.

### Updated: `.claude/settings.json`
Add the session-briefing hook to the SessionStart event alongside the existing session-sync hook.

### Updated: `.claude/src/assistant-persona.md`
Add instructions for Marsh to write to relationship.md at natural moments, and to update "First Meeting" after the first introduction.

### Updated: `CLAUDE.md`
Simplify the startup sequence — the hook now handles context injection, so CLAUDE.md doesn't need to carry the burden of "read these files before responding." The startup sequence becomes: "The session briefing has been injected by the SessionStart hook. Use it to calibrate your greeting."

---

## What This Does NOT Do

- **No AI-powered session summarization.** The SessionStart hook is a shell script, not a language model. It reads git data and a file. Phase 2 could add transcript summarization via SessionEnd, but that's future work.

- **No mandatory journaling.** Marsh is encouraged to update relationship.md, not required. The system works without it — just better with it.

- **No complex state machine.** There's no "relationship stage" enum or phase transitions. Claude is good at reading a relationship file with 3 notes and calibrating a casual greeting, vs reading one with 30 notes and calibrating like an old friend. We let the LLM do what it's good at.

- **No cross-session conversation memory.** Marsh doesn't remember what was SAID in previous conversations — he remembers what was BUILT (via git) and what was NOTED (via relationship.md). The conversation itself is ephemeral. The knowledge base and relationship file are permanent.

---

## Validation

After implementation, test these scenarios:

1. **First ever session:** Marsh introduces himself, demonstrates specific business knowledge, invites Dan to work. No cold greeting. No commands listed.

2. **Second session (minutes later):** Marsh recognizes Dan, references what they just worked on, doesn't re-introduce. Greeting is warm but brief.

3. **Session after a few days:** Marsh notes the gap, references recent activity if any, ready to work.

4. **Session with an empty relationship file but populated vault:** Still works — git data provides the activity history. Greeting is contextual even without relationship notes.

5. **Marsh updates relationship file during a session:** After Dan teaches something notable or expresses a preference, Marsh writes a line to relationship.md without being asked.

---

## Implementation Order

1. Create `.claude/src/relationship.md` with starting structure
2. Create `.claude/hooks/session-briefing.sh`
3. Update `.claude/settings.json` to add the SessionStart hook
4. Update `.claude/src/assistant-persona.md` with relationship writing guidance
5. Update `CLAUDE.md` startup sequence to reference the injected briefing
6. Update `.claude/scripts/smoke-test.sh` with new checks
7. Test all five scenarios above
