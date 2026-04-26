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

| Variable | Wert |
|---|---|
| `KAI_HOST` / `KAI_USER` | 46.224.164.200 / root |
| `BOTMATIQ_HOST` / `BOTMATIQ_USER` | 5.9.112.153 / botadmin |
| `CPANEL_HOST` / `CPANEL_USER` | 88.99.195.89 / root |
| `GHA_RUNNER_HOST` / `GHA_RUNNER_USER` | 178.104.211.135 / gha |

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
