# infra.md — technical reference (the source of truth for how things are wired)

> Load this at session start. Everything here is authoritative and versioned.
> Native (Anthropic) memory is NOT authoritative for anything in this file.

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

Read-only creds (`gha-ci-service`) are provided per-session via Andreas's Custom
Instructions and land in `/home/claude/vault_client_id` + `vault_client_secret`.

---

## Vault Auth Pattern (MANDATORY for every operation that needs a token)

```bash
# Step 1: log in to Vault, get a short-lived access token
VAULT_TOKEN=$(curl -sS -X POST "https://vault.tecmatiq.de/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$(cat /home/claude/vault_client_id)\",\"clientSecret\":\"$(cat /home/claude/vault_client_secret)\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])")

# Step 2: pull the secret you need (example: GIT_PAT)
GIT_PAT=$(curl -sS "https://vault.tecmatiq.de/api/v3/secrets/raw/GIT_PAT?workspaceSlug=tecmatiq&environment=prod&secretPath=%2Fproviders" \
  -H "Authorization: Bearer $VAULT_TOKEN" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['secret']['secretValue'])")
```

`jq` is **not** preinstalled in the Anthropic sandbox bash — use `python3 -c`.
(`jq` IS available on GitHub runners — different environment.) See gotchas.md.

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

**Symptom**: `fatal: Authentication failed` or `401 Bad credentials` or `Invalid username or token`.

**Wrong response** (never do this): leave changes uncommitted locally and ask Andreas
to push manually after refreshing a token.

**Correct response** (always):

```bash
# 1. Pull the fresh PAT from Vault (see Auth Pattern above) -> $GIT_PAT
# 2. Set the remote URL with the live token
git remote set-url origin "https://x-access-token:${GIT_PAT}@github.com/asawall/<repo>.git"
# 3. Push
git push origin main
```

The PAT in Vault is always the current valid one. If Andreas rotates it, the new
value lands in Vault and the next pull picks it up automatically.

**Permission profile of the current Fine-Grained PAT** (verified 2026-07-14):
- Contents read/write, Workflows write
- Actions read/write — incl. `DELETE /repos/{o}/{r}/actions/artifacts/{id}`
- Administration write — incl.
  `PUT /repos/{o}/{r}/actions/permissions/artifact-and-log-retention`
- Metadata read
- NO billing — `/users/asawall/settings/billing/*` returns 403. Storage/minute
  usage must be derived from the artifacts + runs API, or read in the UI.
- NO Secrets list/write — Andreas sets repo-secrets manually
- NO Packages — GHCR push uses `secrets.GITHUB_TOKEN` (per-run) inside workflows

---

## GitHub Workflows — `load-vault-secrets` composite action

For workflows that need Vault secrets at runtime:

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
# Now ${{ env.GIT_PAT }} etc. are available
```

Repo secrets `VAULT_CLIENT_ID` / `VAULT_CLIENT_SECRET` are already set in:
botmatiq, frag-einen-v2, kingdom-ai, linkedin-phase2, rissfest, vertriebsarchitekt,
sape-control-plane (uses `sape-admin-service` for CRUD), easyarchitekt.

Other reusable workflows in this repo (see README.md): `docker-build-push.yml`,
`ssh-deploy-central.yml` (recommended), `ssh-deploy.yml`, `notify-telegram.yml`.

---

## Server architecture

| Server | IP | Role |
|--------|------|------|
| KAI (KingdomAI) | 46.224.164.200 | Main workspace + apps + Vault + ai-stack |
| Botmatiq | 5.9.112.153 | DSGVO-isolated Botmatiq only |
| Hosting | 88.99.195.89 | cPanel + JetBackup + Wissenscloud |
| gha-runner-01 | 178.104.211.135 | 15 ephemeral GHA runners |

**SSH access from Claude**: via `gha-runner-01` deploy-key
(`/home/gha/.ssh/deploy_ed25519`) by triggering a one-shot `workflow_dispatch` on a
diagnostic workflow. Do not ask Andreas to run shell commands. Delete one-shot
diagnostic workflows after success.

### Repository Variables (central, available as `${{ vars.NAME }}` in all repos)

| Variable | Value |
|---|---|
| `KAI_HOST` / `KAI_USER` | 46.224.164.200 / root |
| `BOTMATIQ_HOST` / `BOTMATIQ_USER` | 5.9.112.153 / botadmin |
| `CPANEL_HOST` / `CPANEL_USER` | 88.99.195.89 / root |
| `GHA_RUNNER_HOST` / `GHA_RUNNER_USER` | 178.104.211.135 / gha |

---

## For CRUD in Vault (create identities, write/rotate secrets)

`gha-ci-service` is read-only. For destructive ops, ask Andreas for
`sape-admin-service` credentials, or he does it in the Vault UI. Do not attempt
writes with the read-only identity — it will 403.
