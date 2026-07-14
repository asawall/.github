# runbooks.md — operational runbooks

> One runbook per recurring operational mechanism. Keep the "why" so future-you
> doesn't rip it out. Outdated runbook? Replace it, don't stack.

---

## rissfest secret-sync (KAI)

`rissfest-secret-sync.timer` on KAI (every 15 min) keeps `ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN` (Vault `TELEGRAM_BOT_TOKEN_AUTOSAPE`) and
`TELEGRAM_ALERT_CHAT_ID` (Vault `TELEGRAM_CHAT_ID`) in `/opt/rissfest/.env` aligned
with Vault (`tecmatiq/prod/providers`) via a .env-key -> Vault-key mapping, and
recreates `rissfest-web` only on a real diff.

Fail-safe (never writes empty/short values, no-ops if Vault is down) and
registry-independent (re-tags the running image as `:latest`, recreates with
`--pull never` — so a stale GHCR login never blocks it).

- Source (versioned): `asawall/rissfest` → `ops/rissfest-secret-sync.py`
- Installed at `/usr/local/bin/rissfest-secret-sync.py`, run as root by the timer
- Read-only Vault creds (`gha-ci-service`) at `/etc/rissfest/vault-creds.env`
- Check: `systemctl list-timers rissfest-secret-sync.timer`;
  logs `journalctl -u rissfest-secret-sync.service`
- Rotating the key in Vault propagates to prod within 15 min automatically.

Context: the Anthropic key had drifted stale in `.env` (nothing synced it),
silently degrading the on-site agent (`/api/agent`) and the cold-mail personalizer
(`personalize.ts`) to fallbacks. This timer prevents recurrence. See gotchas.md.

## repo-backup offsite (infra-monitoring)

`infra-monitoring/.github/workflows/repo-backup.yml`, taeglich 02:00 UTC auf
gha-runner-01. Klont 11 aktive Repos als bare Mirrors, tart sie (~28 MB) und legt
sie auf der Storage Box ab:

- **durabel**: `/mnt/storagebox-nc/repo-backups/YYYYMMDD/repo-backup.tar.gz`,
  30 Generationen (~840 MB bei 4,1 TB frei). Weg: Runner -> Hosting per
  `deploy_ed25519` -> Box per fstab-SSHFS. Keine eigenen Credentials.
- **Griffbereitschaft**: Actions-Artifact `repo-backup-<run_id>`, 7 Tage.

Gegen stille Fehler abgesichert (alle drei haben real zugeschlagen):
1. `tar -tzf` lokal VOR dem Versand — kein korruptes Archiv geht raus.
2. `mountpoint -q /mnt/storagebox-nc` — ohne den Check schriebe der Job bei
   weggehangenem SSHFS auf die lokale Platte des Hosting-Servers und das
   Offsite-Backup existierte schlicht nicht.
3. Remote Groessenvergleich UND `tar -tzf`. Groesse allein reicht nicht: SSHFS
   kann bei Abbruch eine voll grosse, aber korrupte Datei hinterlassen.

Rotation sortiert nach Namen (YYYYMMDD lexikografisch = chronologisch), nicht nach
mtime — SSHFS-mtimes sind nicht verlaesslich.

Context: lief bis 14.07.2026 in den Actions-Storage mit 90 Tagen Retention und
einem Glob-Bug, der jeden Vorlauf-Tarball wieder einsammelte. Steady State waere
>100 GB gewesen (~25 USD/Monat). Ausserdem lag die einzige Kopie an genau dem
System, dessen Ausfall sie abfedern soll.

