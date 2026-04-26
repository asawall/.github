# .github — asawall organisation profile

Reusable GitHub Actions workflows and the master inventory of all `asawall` repositories.

## 1. Project Overview

This repository serves two purposes for the `asawall` GitHub account:

1. **Reusable workflows** — Docker build/push, central SSH deploy, per-repo SSH deploy, and Telegram notification workflows that other `asawall` repos `uses:` to avoid duplicating CI logic.
2. **Documentation hub** — under `docs/`, a master inventory of every repository in the account and standalone documentation pages for the seven repositories that are GitHub-archived (read-only) and therefore cannot host their own auto-generated documentation.

## 2. System Architecture

```
asawall org  ──────────────────────────────────────────────────────────────
   │
   ├── .github (this repo)
   │     ├── .github/workflows/*.yml  ──uses:──► consumed by other repos
   │     ├── README.md                          (this file)
   │     └── docs/
   │           ├── asawall-docs-overview.md     master inventory
   │           ├── README.de.md                 German overview
   │           ├── technical.md                 reusable-workflow deep dive (EN)
   │           ├── technical.de.md              reusable-workflow deep dive (DE)
   │           └── archived-repos/              docs for the 7 archived repos
   │
   └── 18 product / tooling repos  ──uses:──► reusable workflows above
```

## 3. Tech Stack

GitHub Actions only. No runtime dependencies, no application code.

| Component | Tool |
|---|---|
| Reusable workflows | YAML (GitHub Actions `workflow_call`) |
| Container registry | GHCR (`ghcr.io/asawall/*`) |
| Build cache | GitHub Actions Cache (Docker BuildKit `cache-from/cache-to`) |
| Deploy transport | SSH (ed25519, central key on `gha-runner-01`) |
| Notifications | Telegram Bot API |

## 4. Setup & Installation

Nothing to install. Other `asawall` repos consume these workflows via:

```yaml
jobs:
  build:
    uses: asawall/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: <product>/<service>
      context: ./<service>
      runner-label: <runner>
```

The runner labels and host variables are documented in §6 below.

## 5. Code Structure

```
.
├── README.md                              # this overview
├── .github/workflows/
│   ├── docker-build-push.yml              # build + push to GHCR with BuildKit cache
│   ├── ssh-deploy-central.yml             # recommended: shared deploy key on runner
│   ├── ssh-deploy.yml                     # fallback: per-repo deploy key
│   └── notify-telegram.yml                # success/failure notification
└── docs/
    ├── asawall-docs-overview.md           # ← master inventory of all 19 repos
    ├── README.de.md                       # German overview
    ├── technical.md                       # technical supplement (EN)
    ├── technical.de.md                    # technical supplement (DE)
    └── archived-repos/
        ├── ai-dashboard.md
        ├── claude-gpt.md
        ├── gpt-dashboard.md
        ├── kingdom-gpt-hosting.md
        ├── kingdom-saas.md
        ├── mygpt-dashboard.md
        └── nextjs-boilerplate.md
```

## 6. API Documentation

### Reusable workflow: `docker-build-push.yml`

```yaml
uses: asawall/.github/.github/workflows/docker-build-push.yml@main
with:
  image-name: kingdom-ai/backend
  context: ./backend
  runner-label: kingdom-ai
```

BuildKit cache hits typically save 60–80 % of build time on warm cache.

### Reusable workflow: `ssh-deploy-central.yml` (recommended)

```yaml
uses: asawall/.github/.github/workflows/ssh-deploy-central.yml@main
with:
  runner-label: kingdom-ai
  host: ${{ vars.KAI_HOST }}
  user: ${{ vars.KAI_USER }}
  script: |
    cd /opt/kingdom-ai
    docker compose pull
    docker compose up -d
```

Uses `/home/runner/.ssh/deploy_ed25519` (bind-mounted onto `gha-runner-01`). No per-repo SSH-key secret required.

### Reusable workflow: `ssh-deploy.yml`

Fallback variant taking a per-repo SSH key secret. Use only when the central key is not authorised on the target host.

### Reusable workflow: `notify-telegram.yml`

```yaml
uses: asawall/.github/.github/workflows/notify-telegram.yml@main
with:
  title: "Deploy KingdomAI"
  status: success
  message: "Backend ${{ github.sha }} deployed."
secrets:
  tg-token: ${{ secrets.TG_TOKEN }}
  tg-chat:  ${{ secrets.TG_CHAT_ID }}
```

### Organisation-wide variables

Available as `${{ vars.NAME }}` in all consuming repos:

| Variable | Value |
|---|---|
| `KAI_HOST` / `KAI_USER` | `46.224.164.200` / `root` |
| `BOTMATIQ_HOST` / `BOTMATIQ_USER` | `5.9.112.153` / `botadmin` |
| `CPANEL_HOST` / `CPANEL_USER` | `88.99.195.89` / `root` |
| `GHA_RUNNER_HOST` / `GHA_RUNNER_USER` | `178.104.211.135` / `gha` |

## 7. Data Model

No persisted state. Workflow inputs and outputs are the only data interfaces.

## 8. Workflows & Logic

A typical end-to-end deploy pipeline composed from the reusable workflows above:

```yaml
name: Deploy
on: { push: { branches: [main] } }

jobs:
  build:
    uses: asawall/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: kingdom-ai/backend
      context: ./backend
      runner-label: kingdom-ai

  deploy:
    needs: build
    uses: asawall/.github/.github/workflows/ssh-deploy-central.yml@main
    with:
      runner-label: kingdom-ai
      host: ${{ vars.KAI_HOST }}
      user: ${{ vars.KAI_USER }}
      script: |
        cd /opt/kingdom-ai
        docker compose pull backend
        docker compose up -d backend

  notify:
    needs: [build, deploy]
    if: always()
    uses: asawall/.github/.github/workflows/notify-telegram.yml@main
    with:
      title: "KingdomAI Deploy"
      status: ${{ contains(needs.*.result, 'failure') && 'failure' || 'success' }}
      message: "SHA: ${{ github.sha }}"
    secrets:
      tg-token: ${{ secrets.TG_TOKEN }}
      tg-chat:  ${{ secrets.TG_CHAT_ID }}
```

## 9. Deployment

This repo is itself never deployed — it is referenced by `@main` from consuming workflows. Pinning to a SHA is recommended for production workflows once a workflow stabilises (`uses: asawall/.github/.github/workflows/docker-build-push.yml@<sha>`).

## 10. Testing

Reusable workflows are tested by their consumers — every successful CI run on a downstream repo proves the upstream workflow. Breaking changes are coordinated by:

1. Branch the change in `.github` (e.g. `wip/buildx-v3`).
2. Pin one consuming repo to the branch SHA, verify on its CI.
3. Merge to `main` only after the pilot consumer is green.

## 11. Error Analysis & Debugging

| Symptom | Likely cause | Investigation |
|---|---|---|
| Consuming workflow fails on `uses:` resolution | Branch/SHA pin invalid | Check `uses: asawall/.github/...@<ref>` resolves on the GitHub UI |
| Docker build slow / no cache hit | First build, or cache evicted | GHCR + Actions cache; expected on cold cache |
| `ssh-deploy-central.yml` fails authentication | Central key not yet bind-mounted on the runner | Verify `/home/runner/.ssh/deploy_ed25519` on the runner host |
| Telegram notify fires twice | `if: always()` plus a re-run with retained jobs | Expected; deduplicate downstream if needed |

## 12. Open Items / Risks

- The `@main` pin in consumer repos couples them to the latest commit here. Document a versioned-tag strategy (`v1`, `v2`) before any breaking change to the workflow inputs.
- The shared deploy key on `gha-runner-01` is a single point of failure — ensure backup access and rotate quarterly.
- The `archived-repos/` directory is a documentation graveyard; periodically review whether any of those repositories should be unarchived rather than left preserved.
