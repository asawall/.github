# .github

Reusable Workflows für alle asawall Repos.

## Verfügbare Workflows

### docker-build-push.yml
Baut ein Docker-Image mit BuildKit-Cache und pusht es nach GHCR.

```yaml
jobs:
  build:
    uses: asawall/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: kingdom-ai/backend
      context: ./backend
      runner-label: kingdom-ai
```

### ssh-deploy.yml
Verbindet sich per SSH zum Zielserver und führt ein Skript aus.

```yaml
jobs:
  deploy:
    uses: asawall/.github/.github/workflows/ssh-deploy.yml@main
    with:
      runner-label: kingdom-ai
      host: 46.224.164.200
      user: root
      script: |
        cd /opt/kingdom-ai
        docker compose pull && docker compose up -d
    secrets:
      ssh-key: ${{ secrets.SERVER_SSH_KEY }}
```

### notify-telegram.yml
Sendet Status-Nachricht via Telegram.

```yaml
jobs:
  notify:
    uses: asawall/.github/.github/workflows/notify-telegram.yml@main
    with:
      title: "Deploy KingdomAI"
      status: success
      message: "Backend image abc123 deployed."
    secrets:
      tg-token: ${{ secrets.TG_TOKEN }}
      tg-chat:  ${{ secrets.TG_CHAT_ID }}
```
