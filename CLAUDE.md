# CLAUDE.md — memory index — SaPe Holding (Andreas Sawall)

This repo is Andreas's **durable, versioned memory**. This file is the **index**:
load it first every session, then load the rest. It stays short on purpose.

---

## Memory layout (what lives where)

| File | Purpose | When to read |
|------|---------|--------------|
| `CLAUDE.md` (this) | index + bootstrap | first, every session |
| `regeln.md` | behavior + memory discipline (incl. write-back rules) | before acting |
| `infra.md` | Vault, auth pattern, servers, GitHub workflows, secrets map | before any authed/infra work |
| `gotchas.md` | traps that bit us, with fixes | **before debugging anything** |
| `runbooks.md` | operational mechanisms (e.g. secret-sync timers) | when touching those systems |
| `worklog.md` | last ~30 sessions in keywords | to answer "where were we?" |
| `CLAUDE_TEMPLATE.md` | template for per-repo CLAUDE.md | when onboarding a repo |

**Boundary**: native Anthropic memory (auto userMemories in context) is
**top-of-mind only** — never authoritative for technical facts. These files win on
any conflict. Details in `regeln.md`.

---

## Load the rest now (one command)

```bash
curl -s https://raw.githubusercontent.com/asawall/.github/main/bootstrap.sh | bash
```

This prints every memory file (regeln, infra, gotchas, runbooks, worklog) and runs a
secrets-free auth health check. It is the single load mechanism: the file set is
declared once in `bootstrap.sh` (`FILES=`) and mirrored in the layout table above.
Fallback if bootstrap.sh is unreachable: curl each `<name>.md` from the same raw dir.

---

## Session bootstrap (only if Vault creds are missing)

A fresh sandbox has nothing in `/home/claude/`. The read-only Vault creds
(`gha-ci-service`) come from Andreas's Custom Instructions / Project Knowledge and
are written to:

```bash
mkdir -p /home/claude
echo "<VAULT_CLIENT_ID>"     > /home/claude/vault_client_id
echo "<VAULT_CLIENT_SECRET>" > /home/claude/vault_client_secret
chmod 600 /home/claude/vault_*
```

If those values are not in context, ASK Andreas once — do not guess. The full auth
pattern (Vault login → pull secret → GitHub push recovery) is in `infra.md`.

---

## TL;DR — the three things you must never do wrong

1. **`git push` fails (401)** → pull fresh `GIT_PAT` from Vault, `git remote set-url`,
   push. Never leave changes local and ask Andreas to push. (infra.md)
2. **Secrets** → never hardcode, never paste into chat. Everything in Vault at
   `https://vault.tecmatiq.de`. (infra.md)
3. **Read-only / diagnostic API calls** → do them autonomously, no permission asked.

---

## Servers (quick ref, full detail in infra.md)

| Server | IP | Role |
|--------|------|------|
| KAI | 46.224.164.200 | main workspace + apps + Vault |
| Botmatiq | 49.13.142.247 | DSGVO-isolated Botmatiq only |
| Hosting | 88.99.195.89 | cPanel + JetBackup |
| gha-runner-01 | 178.104.211.135 | 15 ephemeral GHA runners |

---

## Quick test — is my auth pipeline working?

Prints `asawall` if Vault → GIT_PAT → GitHub all work:

```bash
VAULT_TOKEN=$(curl -sS -X POST "https://vault.tecmatiq.de/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$(cat /home/claude/vault_client_id)\",\"clientSecret\":\"$(cat /home/claude/vault_client_secret)\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])") && \
GIT_PAT=$(curl -sS "https://vault.tecmatiq.de/api/v3/secrets/raw/GIT_PAT?workspaceSlug=tecmatiq&environment=prod&secretPath=%2Fproviders" \
  -H "Authorization: Bearer $VAULT_TOKEN" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['secret']['secretValue'])") && \
curl -sS -H "Authorization: Bearer $GIT_PAT" "https://api.github.com/user" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['login'])"
```

---

*Restructured 2026-07-11 from a single monolithic file into an index + area files.*
*Author: Claude (under direction of Andreas Sawall). History: `git log -p`.*
