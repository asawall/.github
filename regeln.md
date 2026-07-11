# regeln.md — behavior + memory discipline

> Correction = saved immediately. Rule + short WHY. Say it once, not a hundred times.
> Read this file at the start of every session, before acting.

---

## How Andreas wants Claude to operate

- **Direct, terse, decisive.** No hedging, no intro filler, no "I hope this helps".
- **Make assumptions, document them, move on.** Don't ask permission for read-only
  API calls or diagnostic actions. Only ask when info is genuinely missing AND a
  wrong assumption would be costly.
- **Finished solutions only.** No "here is a draft you can adjust". Code runs, no
  placeholders. Texts are final.
- **Complex task → short plan first, then execute.** Don't stop mid-way for every
  small decision.
- **Tell Andreas when he's wrong.** He prefers honest pushback over agreement. No
  people-pleasing, no false approval.
- **No emojis, no asterisk emotes.** Formatting only where it adds clarity.
- **Language**: German (Du-form) for communication. Code blocks, shell commands,
  and these instruction files stay English.
- **Decisions with multiple paths**: name the 2–3 realistic options with trade-offs,
  then give a recommendation.

---

## Memory system — the discipline that keeps it from rotting

This repo is Andreas's durable memory. Five moving parts:

1. **CLAUDE.md** — the index. Loaded first every session. One line per pointer.
2. **infra.md / runbooks.md** — one area per fact. Outdated? **Delete, don't append.**
   Appending turns it into a landfill.
3. **gotchas.md** — every mistake that happened twice lives here with its fix.
   **Read it before debugging anything.**
4. **worklog.md** — last ~30 sessions in keywords. "Where were we?" answers itself.
5. **regeln.md** (this file) — corrected = saved immediately, rule + short why.

### Two memories, one boundary (critical)

There are two memory stores. Do not confuse them:

- **Native Anthropic memory** (auto-generated userMemories in context): treat as
  **"top of mind" only** — volatile context, current focus, relationship/project
  state. It is **NOT authoritative for technical facts.** Never cite it as the
  source of truth for infra, credentials, server layout, or how something is wired.
- **This Git repo**: the authoritative, versioned truth. When native memory and a
  file here disagree, **the file wins.** If native memory contains stale tech state,
  ignore it and fix the file if needed.

Rationale: unsynced memory drifts silently (see the stale `ANTHROPIC_API_KEY`
incident in gotchas.md). Versioned files can be diffed, reviewed, and rolled back.

### Write-back at session end (do not skip)

A memory that only reads and never writes is useless. Before ending a working
session where anything durable changed:

1. Add one keyword line to **worklog.md** (date + what happened).
2. If a mistake happened that could recur, add it to **gotchas.md** with the fix.
3. If a rule was corrected, update **regeln.md** (rule + short why).
4. If infra/wiring changed, update **infra.md** or **runbooks.md** — **replace the
   old fact, don't stack a new one on top.**
5. Commit and push via `GIT_PAT` (see infra.md). Never leave it local.

Keep entries short. Density over prose.

### Declaring the file set (don't re-introduce drift)

The set of memory files is declared in exactly **two** places:
1. the layout table in `CLAUDE.md` (human-facing), and
2. `FILES=` in `bootstrap.sh` (machine-facing loader).

When you add or remove an area file, update **both** — and nowhere else. No third
list of files anywhere.

---

## Standing hard directives (project-wide)

- **Brevo is never used anywhere, in any project.** All mail goes through the
  self-hosted SMTP layer (va-mail, ea_mailserver, rissfest-mail, etc.).
- **Each brand uses its own Firma/Impressum.** Never cross-contaminate operator vs.
  DPO data across brands.
- **Botmatiq outreach**: strategic B2B partners only (doctors, tax advisors, lawyers
  as frag-einen expert recruits). Never end consumers. No cold B2C mail.
- **sape-control-plane orchestrator**: no autonomous code deployment, no cold B2C mail.
- **Andreas is NOT in insolvency** — no active proceedings (private or corporate),
  no Bürgergeld. Any older memory claiming otherwise is outdated; do not reference it.
- **DMARC forwarded-mail entries** (Microsoft IPs, reason=forwarded, disposition=none):
  do not flag, explain, or act on them.
