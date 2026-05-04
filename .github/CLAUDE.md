# Claude Operating Instructions — SaPe Holding (Andreas Sawall)

This file is the **single source of truth** for how every Claude instance should
operate when working in any of Andreas's repositories or environments. If you
are a Claude assistant reading this: load it once at the start of a session and
follow it.

---

## Session bootstrap (do this FIRST in every new session)

A fresh Anthropic sandbox has nothing in `/home/claude/`. Before you can do
anything authenticated, you need read-only Vault credentials. They are
provided via Andreas's project Custom Instructions or as Project Knowledge.

The bootstrap looks like this:

```bash
mkdir -p /home/claude
echo "<VAULT_CLIENT_ID from Custom Instructions>" > /home/claude/vault_client_id
echo "<VAULT_CLIENT_SECRET from Custom Instructions>" > /home/claude/vault_client_secret
chmod 600 /home/claude/vault_*
```

If those values are not in your context (Custom Instructions / Project
Knowledge / chat history), ASK Andreas once. Do not guess.

The identity used here is **`gha-ci-service`** — a strict read-only viewer in
all three tenants. It can **read** any secret, but cannot write or delete.
That makes it safe to expose to a Claude session.

For destructive operations (creating identities, rotating credentials,
managing memberships), Andreas needs to provide `sape-admin-service`
credentials separately, OR do the action himself in the Vault UI.

---

## TL;DR — the three things you must never do wrong

1. **Authenticated GitHub operations**: when `git push` fails with `401 Bad credentials`,
   *do not* leave changes uncommitted locally and ask Andreas to push. Pull a fresh
   PAT from Vault and continue. See *Vault Auth Pattern* below.
2. **Secrets**: never hardcode, never paste into chat. Everything lives in the
   Vault at `https://vault.tecmatiq.de`.
3. **Diagnostic / read-only API calls**: do them autonomously. Do not ask permission.

---

## Vault — central secrets store

**URL**: `https://vault.tecmatiq.de` (Infisical self-hosted on KAI)

**Tenants** (workspace slugs):
- `tecmatiq` — TECMATIQ GmbH (Botmatiq, KingdomAI, infrastructure)
- `frageinen` — frag-einen UG (separate Stripe account)
- `planningx` — PlanningX GmbH (easyArchitekt, separate Stripe account)

**Environments**: `prod`, `staging`, `dev`

**Folder layout** (all tenants):
- `/providers/` — third-party API keys (Stripe, Telegram, GitHub-PAT, Anthropic, OpenAI, Hetzner Cloud)
- `/<app-name>/` — app-specific secrets (e.g. `tecmatiq/prod/botmatiq/{DB_PASSWORD,JWT_SECRET}`)
- `/github/` — legacy GitHub helpers
- `/claude/` — mirror values for Claude tooling

### Identities (Universal Auth)

| Identity | Role | Use |
|----------|------|-----|
| `gha-ci-service` | viewer (all 3 tenants) | **default for Claude sessions, read-only** |
| `sape-admin-service` | admin (all 3 tenants) | CRUD; only when Andreas explicitly provides credentials |
| `bootstrap-temp` | superadmin | only for org-level setup, do not use |

---

## Vault Auth Pattern (MANDATORY for every operation that needs a token)

```bash
# Step 1: log in to Vault, get a short-lived access token
VAULT_TOKEN=$(curl -sS -X POST "https://vault.tecmatiq.de/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$(cat /home/claude/vault_client_id)\",\"clientSecret\":\"$(cat /home/claude/vault_client_secret)\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])")

# Step 2: pull the secret you need
GIT_PAT=$(curl -sS "https://vault.tecmatiq.de/api/v3/secrets/raw/GIT_PAT?workspaceSlug=tecmatiq&environment=prod&secretPath=%2Fproviders" \
  -H "Authorization: Bearer $VAULT_TOKEN" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['secret']['secretValue'])")
```

`jq` is **not** preinstalled in the Anthropic sandbox bash — use `python3 -c`.

### Common keys

| Key | Tenant | Folder | Notes |
|-----|--------|--------|-------|
| `GIT_PAT` | tecmatiq | /providers | Fine-grained PAT, owns asawall/* repos |
| `ANTHROPIC_API_KEY` | tecmatiq | /providers | |
| `OPENAI_API_KEY` | tecmatiq | /providers | |
| `HETZNER_CLOUD_TOKEN` | tecmatiq | /providers | DNS via /v1/zones/{id}/rrsets |
| `STRIPE_SECRET_KEY_TECMATIQ` | tecmatiq | /providers | Tecmatiq Stripe |
| `STRIPE_SECRET_KEY` | frageinen | /providers | frag-einen Stripe |
| `STRIPE_SECRET_KEY` | planningx | /providers | easyArchitekt Stripe |
| `TELEGRAM_BOT_TOKEN_AUTOSAPE` | tecmatiq | /providers | system alerts |
| `TELEGRAM_BOT_TOKEN_VA_LINKEDIN` | tecmatiq | /providers | LinkedIn delivery |
| `TELEGRAM_CHAT_ID` | tecmatiq | /providers | Andreas private chat |

---

## GitHub Auth — what to do when `git push` fails

**Symptom**: `fatal: Authentication failed` or `Invalid username or token`.

**Wrong response** (do not do this):
> "Token expired — please push manually after refreshing your token, here are the
> changes I made locally..."

**Correct response** (always do this):

```bash
# 1. Pull the fresh PAT from Vault (see pattern above) -> $GIT_PAT
# 2. Set the remote URL with the live token
git remote set-url origin "https://x-access-token:${GIT_PAT}@github.com/asawall/<repo>.git"
# 3. Push
git push origin main
```

The PAT in Vault is always the current valid one. If Andreas rotates, the new
value lands in Vault and the next pull picks it up automatically.

**Permission profile of the current Fine-Grained PAT**:
- ✅ Contents read/write, Workflows write, Actions read/trigger
- ✅ Metadata read
- ❌ Secrets list/write — Andreas sets repo-secrets manually
- ❌ Packages — GHCR push uses `secrets.GITHUB_TOKEN` (per-run) inside workflows

---

## GitHub Workflows — `load-vault-secrets` composite action

For workflows that need Vault secrets at runtime, use the composite action:

```yaml
- name: Load Vault secrets
  uses: asawall/.github/.github/actions/load-vault-secrets@main
  env:
    VAULT_CLIENT_ID: ${{ secrets.VAULT_CLIENT_ID }}
    VAULT_CLIENT_SECRET: ${{ secrets.VAULT_CLIENT_SECRET }}
  with:
    project-slug: tecmatiq         # or frageinen / planningx
    env-slug: prod
    path: /providers
    keys: GIT_PAT,STRIPE_SECRET_KEY_TECMATIQ
# Now ${{ env.GIT_PAT }} and ${{ env.STRIPE_SECRET_KEY_TECMATIQ }} are available
```

The action uses `jq` (which IS preinstalled on GitHub runners — different from
the Anthropic sandbox).

Repo secrets `VAULT_CLIENT_ID` / `VAULT_CLIENT_SECRET` are already set in:
botmatiq, frag-einen-v2, kingdom-ai, linkedin-phase2, rissfest, vertriebsarchitekt,
sape-control-plane (uses `sape-admin-service` for CRUD), easyarchitekt.

---

## Server architecture (no surprises)

| Server | IP | Role |
|--------|------|------|
| KAI (KingdomAI) | 46.224.164.200 | Main workspace + apps + Vault + ai-stack |
| Botmatiq | 5.9.112.153 | DSGVO-isolated Botmatiq only |
| Hosting | 88.99.195.89 | cPanel + JetBackup + Wissenscloud |
| gha-runner-01 | 178.104.211.135 | 15 ephemeral GHA runners |

**SSH access from Claude**: via `gha-runner-01` deploy-key
(`/home/gha/.ssh/deploy_ed25519`) by triggering a one-shot workflow_dispatch on a
diagnostic workflow. Do not ask Andreas to run shell commands.

---

## Behavior rules

- **Direct, terse, decisive**. No hedging, no "I hope this helps".
- **Make assumptions**, document them, move on. Don't ask for permission on
  read-only API calls or diagnostic actions.
- **Finished solutions only**. No "here is a draft you can adjust". Code must run.
- **Tell Andreas when he's wrong**. He prefers honest pushback over agreement.
- **No emojis, no asterisk emotes**. Formatting only when it adds clarity.
- **Language**: German (Du-form). Code blocks and shell commands stay English.

---

## Quick test — am I set up correctly?

After bootstrap, run this one-liner. If it prints `asawall`, your auth pipeline works:

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

*Last updated: 2026-05-04. Author: Claude (under direction of Andreas Sawall).*
*Edit history: see `git log -p CLAUDE.md` in this repo.*
