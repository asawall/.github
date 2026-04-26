# .github — Technisches Supplement

> Begleitdokument zu [README.md](../README.md). Bitte zuerst README.md lesen.

## Warum ein `.github`-Profile-Repo

GitHub behandelt das Repository mit dem exakten Namen `.github` in jedem Account oder jeder Organisation als Sonderfall. Drei Dinge fallen ihm zu:

1. Die `README.md` wird zur öffentlichen Profilseite auf `https://github.com/asawall`.
2. `.github/workflows/*.yml`-Dateien in diesem Repo werden zu Reusable Workflows, die jedes andere Repo desselben Accounts per `uses:` einbinden kann.
3. Per Konvention gehört organisationsweite Dokumentation hierher — weshalb das Master-Inventar und die Doku der archivierten Repos unter `docs/` liegen.

## BuildKit-Cache-Layout

`docker-build-push.yml` konfiguriert den Cache so:

```yaml
cache-from: type=gha,scope=${{ inputs.image-name }}
cache-to:   type=gha,scope=${{ inputs.image-name }},mode=max
```

Per-Image-Scope bedeutet, ein Build von `kingdom-ai/backend` vergiftet nicht den Cache für `botmatiq/agent`. `mode=max` exportiert Cache für jeden Layer (nicht nur das finale Image), was die Hit-Rate dramatisch verbessert — mit Cache-Größe als Trade-off. GitHubs 10-GB-Cache-Quota ist per-Repository — Scope-Strategie anpassen, falls Quota zum Engpass wird.

## Zentraler Deploy-Key vs. Per-Repo-Key

`ssh-deploy-central.yml` liest `/home/runner/.ssh/deploy_ed25519` vom Runner-Host (per Bind-Mount durch den Runner-Installer). Das bedeutet:

- Ein Key, ein Rotations-Event, zehn konsumierende Repos automatisch aktualisiert.
- Verlust von `gha-runner-01` blockiert alle Deploys; Mitigation ist ein zweiter Runner mit demselben Bind-Mount.

`ssh-deploy.yml` akzeptiert einen Per-Repo-`secrets.SSH_KEY`-Input. Nur einsetzen, wenn der zentrale Key auf einem Ziel-Host bewusst nicht autorisiert ist (selten — typisch nur bei Beteiligung externer Systeme).

## Telegram-Notify-Deduplizierung

`notify-telegram.yml` läuft mit `if: always()`-Patterns bei Callern unbedingt. Um downstream zu deduplizieren (z. B. Doppelauslöser bei `workflow_dispatch`-Retries vermeiden), eine eindeutige ID im `message:`-Input mitgeben: `SHA: ${{ github.sha }} run: ${{ github.run_id }}`.

## Versionierungs-Strategie (geplant)

Konsumenten pinnen aktuell auf `@main`. Eine Versions-Tag-Strategie ist geplant:

- `v1` — aktuelle API-Oberfläche
- `v2` — erste Breaking Change

Bei jeder Breaking Change wird ein Release getaggt; Konsumenten opten ein, indem sie `@v1` auf `@v2` ändern, nachdem sie ihre `with:`-Blöcke angepasst haben.
