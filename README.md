# .github

Reusable Workflows für alle asawall Repos.

## Verfügbare Workflows

### docker-build-push.yml
Baut Docker-Image mit BuildKit-Cache und pusht nach GHCR.
**Cache-Hits sparen 60-80% Build-Zeit** bei wiederholten Builds.

```yaml
jobs:
  build:
    uses: asawall/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: kingdom-ai/backend
      context: ./backend
      runner-label: kingdom-ai
```

### ssh-deploy-central.yml *(empfohlen)*
SSH-Deploy mit zentralem Key auf gha-runner-01.
**Kein SSH-Key-Secret pro Repo nötig.** Nutzt /home/runner/.ssh/deploy_ed25519 (Bind-Mount).

```yaml
jobs:
  deploy:
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

### ssh-deploy.yml *(alternative)*
SSH-Deploy mit per-Repo Secret. Für Spezialfälle wo der Default-Key nicht passt.

### notify-telegram.yml
Status-Nachricht via Telegram-Bot.

```yaml
jobs:
  notify:
    uses: asawall/.github/.github/workflows/notify-telegram.yml@main
    with:
      title: "Deploy KingdomAI"
      status: success
      message: "Backend ${{ github.sha }} deployed."
    secrets:
      tg-token: ${{ secrets.TG_TOKEN }}
      tg-chat:  ${{ secrets.TG_CHAT_ID }}
```

## Repository Variables (zentral verfügbar)

In allen 10 Repos verfügbar als `${{ vars.NAME }}`:

| Variable |
|---|
| `KAI_HOST` / `KAI_USER` |
| `BOTMATIQ_HOST` / `BOTMATIQ_USER` |
| `CPANEL_HOST` / `CPANEL_USER` |
| `GHA_RUNNER_HOST` / `GHA_RUNNER_USER` |

Die Werte stehen zentral in den Repository Variables und in `asawall/ops-docs`
(privat). Sie gehören nicht in dieses öffentliche Repo.

## Beispiel: kompletter Deploy-Pipeline

```yaml
name: Deploy
on:
  push:
    branches: [main]

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
