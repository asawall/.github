# worklog.md — last ~30 sessions in keywords

> Newest on top. One line per session: `YYYY-MM-DD — what changed`. Keep it terse.
> When it grows past ~30 lines, trim the oldest — this is a rolling window, not an
> archive. Deeper detail lives in the per-area files, not here.

- 2026-07-11 — Repo-level rollout started: added per-repo CLAUDE.md to `rissfest`
  (verified against the real repo, not memory). Reference implementation of
  CLAUDE_TEMPLATE.md. Remaining active repos: botmatiq, frag-einen-v2, easyarchitekt,
  then vertriebsarchitekt, kingdom-ai, linkedin-phase2, sape-control-plane.
- 2026-07-11 — Added bootstrap.sh: one-command memory load + secrets-free auth
  health check. CLAUDE.md load-block now calls it; file set declared in 2 places only
  (index layout table + bootstrap FILES).
- 2026-07-11 — Restructured durable memory in asawall/.github from monolithic CLAUDE.md
  into index + regeln.md / infra.md / gotchas.md / worklog.md / runbooks.md +
  CLAUDE_TEMPLATE.md. Killed the second (drifted) `.github/CLAUDE.md`. Boundary set:
  native memory = top-of-mind only, Git files = authoritative.
