# .github — asawall-Organisationsprofil

Wiederverwendbare GitHub-Actions-Workflows und das zentrale Inventar aller `asawall`-Repositories.

## 1. Projektüberblick

Dieses Repository erfüllt zwei Aufgaben für den GitHub-Account `asawall`:

1. **Reusable Workflows** — Docker Build/Push, zentrales SSH-Deploy, Per-Repo-SSH-Deploy und Telegram-Benachrichtigung als Workflows, die andere `asawall`-Repos per `uses:` einbinden, statt CI-Logik zu duplizieren.
2. **Documentation Hub** — unter `docs/` das Master-Inventar aller Repositories des Accounts und eigenständige Doku-Seiten für die sieben Repositories, die GitHub-archiviert (read-only) sind und daher keine eigene auto-generierte Doku hosten können.

## 2. Systemarchitektur

```
asawall org  ──────────────────────────────────────────────────────────────
   │
   ├── .github (dieses Repo)
   │     ├── .github/workflows/*.yml  ──uses:──► konsumiert von anderen Repos
   │     ├── README.md                          (diese Datei, EN)
   │     └── docs/
   │           ├── asawall-docs-overview.md     Master-Inventar
   │           ├── README.de.md                 Deutsche Übersicht
   │           ├── technical.md                 Reusable-Workflow-Deep-Dive (EN)
   │           ├── technical.de.md              Reusable-Workflow-Deep-Dive (DE)
   │           └── archived-repos/              Doku der 7 archivierten Repos
   │
   └── 18 Produkt-/Tooling-Repos  ──uses:──► obige Reusable Workflows
```

## 3. Tech-Stack

Ausschließlich GitHub Actions. Keine Laufzeitabhängigkeiten, kein Anwendungscode.

| Komponente | Werkzeug |
|---|---|
| Reusable Workflows | YAML (GitHub Actions `workflow_call`) |
| Container-Registry | GHCR (`ghcr.io/asawall/*`) |
| Build-Cache | GitHub Actions Cache (Docker BuildKit `cache-from/cache-to`) |
| Deploy-Transport | SSH (ed25519, zentraler Key auf `gha-runner-01`) |
| Benachrichtigungen | Telegram Bot API |

## 4. Setup & Installation

Nichts zu installieren. Andere `asawall`-Repos binden die Workflows so ein:

```yaml
jobs:
  build:
    uses: asawall/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: <produkt>/<service>
      context: ./<service>
      runner-label: <runner>
```

Runner-Labels und Host-Variablen sind in §6 dokumentiert.

## 5. Code-Struktur

```
.
├── README.md                              # Übersicht (EN)
├── .github/workflows/
│   ├── docker-build-push.yml              # Build + Push nach GHCR mit BuildKit-Cache
│   ├── ssh-deploy-central.yml             # empfohlen: Shared-Deploy-Key auf Runner
│   ├── ssh-deploy.yml                     # Fallback: Per-Repo-Deploy-Key
│   └── notify-telegram.yml                # Erfolgs-/Fehler-Benachrichtigung
└── docs/
    ├── asawall-docs-overview.md           # ← Master-Inventar aller 19 Repos
    ├── README.de.md                       # diese Datei
    ├── technical.md                       # Technisches Supplement (EN)
    ├── technical.de.md                    # Technisches Supplement (DE)
    └── archived-repos/
        ├── ai-dashboard.md
        ├── claude-gpt.md
        ├── gpt-dashboard.md
        ├── kingdom-gpt-hosting.md
        ├── kingdom-saas.md
        ├── mygpt-dashboard.md
        └── nextjs-boilerplate.md
```

## 6. API-Dokumentation

### Reusable Workflow: `docker-build-push.yml`

```yaml
uses: asawall/.github/.github/workflows/docker-build-push.yml@main
with:
  image-name: kingdom-ai/backend
  context: ./backend
  runner-label: kingdom-ai
```

BuildKit-Cache-Hits sparen typischerweise 60–80 % der Build-Zeit bei warmem Cache.

### Reusable Workflow: `ssh-deploy-central.yml` (empfohlen)

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

Nutzt `/home/runner/.ssh/deploy_ed25519` (Bind-Mount auf `gha-runner-01`). Kein Per-Repo-SSH-Key-Secret nötig.

### Reusable Workflow: `ssh-deploy.yml`

Fallback-Variante mit Per-Repo-SSH-Key-Secret. Nur einsetzen, wenn der zentrale Key auf dem Ziel-Host nicht autorisiert ist.

### Reusable Workflow: `notify-telegram.yml`

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

### Organisationsweite Variablen

In allen konsumierenden Repos als `${{ vars.NAME }}` verfügbar:

| Variable | Wert |
|---|---|
| `KAI_HOST` / `KAI_USER` | `46.224.164.200` / `root` |
| `BOTMATIQ_HOST` / `BOTMATIQ_USER` | `5.9.112.153` / `botadmin` |
| `CPANEL_HOST` / `CPANEL_USER` | `88.99.195.89` / `root` |
| `GHA_RUNNER_HOST` / `GHA_RUNNER_USER` | `178.104.211.135` / `gha` |

## 7. Datenmodell

Keine persistierten Zustände. Workflow-Inputs und -Outputs sind die einzigen Datenschnittstellen.

## 8. Workflows & Logik

Eine typische End-to-End-Deploy-Pipeline aus den obigen Reusable Workflows:

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

Dieses Repo wird nie selbst deployed — es wird per `@main` aus konsumierenden Workflows referenziert. Pinning auf einen SHA ist für Produktions-Workflows empfehlenswert, sobald ein Workflow stabilisiert ist (`uses: asawall/.github/.github/workflows/docker-build-push.yml@<sha>`).

## 10. Tests

Reusable Workflows werden durch ihre Konsumenten getestet — jeder erfolgreiche CI-Lauf in einem Downstream-Repo beweist den Upstream-Workflow. Breaking Changes werden so koordiniert:

1. Änderung in `.github` branchen (z. B. `wip/buildx-v3`).
2. Ein konsumierendes Repo auf den Branch-SHA pinnen, dort die CI verifizieren.
3. Erst nach grünem Pilot-Konsumenten auf `main` mergen.

## 11. Fehleranalyse & Debugging

| Symptom | Wahrscheinliche Ursache | Untersuchung |
|---|---|---|
| Konsumierender Workflow scheitert an `uses:`-Auflösung | Branch/SHA-Pin ungültig | `uses: asawall/.github/...@<ref>` in der GitHub-UI auflösen |
| Docker-Build langsam / kein Cache-Hit | Erster Build oder Cache evictiert | GHCR + Actions-Cache; bei kaltem Cache erwartbar |
| `ssh-deploy-central.yml` scheitert an Auth | Zentraler Key nicht auf den Runner gemountet | `/home/runner/.ssh/deploy_ed25519` auf dem Runner-Host prüfen |
| Telegram-Notify löst doppelt aus | `if: always()` plus Re-Run mit Retained Jobs | Erwartet; downstream deduplizieren falls nötig |

## 12. Offene Punkte / Risiken

- Der `@main`-Pin in Konsumenten-Repos koppelt sie an den jeweils neuesten Commit hier. Eine Versions-Tag-Strategie (`v1`, `v2`) vor jeder Breaking Change am Workflow-Input dokumentieren.
- Der gemeinsame Deploy-Key auf `gha-runner-01` ist Single Point of Failure — Backup-Zugang sicherstellen und quartalsweise rotieren.
- Das Verzeichnis `archived-repos/` ist ein Doku-Friedhof; periodisch prüfen, ob eines der dort dokumentierten Repos unarchiviert statt nur archiviert werden sollte.
