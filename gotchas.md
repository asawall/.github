# gotchas.md — traps that bit us. Read this BEFORE debugging.

> Every mistake that happened (or would predictably happen) twice goes here with a
> fix. New trap after a fix = add it. Keep entries tight: symptom → cause → fix.

---

### `jq: command not found` in the Anthropic sandbox
- **Symptom**: shell one-liners parsing JSON fail with `jq: not found`.
- **Cause**: `jq` is not preinstalled in the Anthropic sandbox bash. (It IS on GitHub
  runners — do not assume parity.)
- **Fix**: parse with `python3 -c "import json,sys; print(json.load(sys.stdin)[...])"`.

### `git push` → `401 Bad credentials` / `Authentication failed`
- **Symptom**: push rejected mid-session.
- **Cause**: stale/absent PAT on the remote URL.
- **Fix**: pull fresh `GIT_PAT` from Vault, `git remote set-url origin
  https://x-access-token:${GIT_PAT}@github.com/asawall/<repo>.git`, push again.
  NEVER leave changes local and ask Andreas to push. (See infra.md.)

### Vault write returns 403
- **Symptom**: creating identities / writing secrets fails with 403.
- **Cause**: the session identity `gha-ci-service` is read-only viewer.
- **Fix**: this is expected. Ask Andreas for `sape-admin-service` creds, or he does
  the write in the Vault UI. Don't retry with the read-only identity.

### Hetzner DNS record update silently keeps the old value
- **Symptom**: A/CNAME record doesn't change, or ends up duplicated.
- **Cause**: the rrsets API needs a DELETE-then-POST pattern, not a single PUT.
- **Fix**: DELETE the existing rrset, then POST the new one, against
  `api.hetzner.cloud/v1/zones/{id}/rrsets` with `HETZNER_CLOUD_TOKEN` (Bearer).
  There is no separate `HETZNER_DNS_API_TOKEN`.

### Stale `ANTHROPIC_API_KEY` degraded prod silently
- **Symptom**: on-site agent (`/api/agent`) and cold-mail personalizer fell back to
  degraded behavior; no error surfaced.
- **Cause**: the key in `/opt/rissfest/.env` drifted from Vault — nothing synced it.
- **Fix**: `rissfest-secret-sync.timer` on KAI now reconciles it every 15 min. See
  runbooks.md. General lesson: any secret copied out of Vault into a `.env` needs a
  sync mechanism or it WILL go stale.

### GHCR stale login blocks container recreate
- **Symptom**: `docker compose up` / pull fails on an expired GHCR login even though
  the image is already local.
- **Cause**: registry auth expiry, unrelated to whether the image exists locally.
- **Fix**: re-tag the running image as `:latest` and recreate with `--pull never`
  (registry-independent). This is what the rissfest sync does.

### Lexware Office: no DELETE/void API for purchaseinvoice vouchers
- **Symptom**: trying to delete/void booked purchase-invoice vouchers via API fails.
- **Cause**: GoBD immutability — Lexware exposes no void/delete for these.
- **Fix**: manual UI cleanup only. ~1,886 duplicates in the unchecked list;
  `cleanup_ids.txt` on KAI. Lexware hotline 0800 8400 1111.

### Two CLAUDE.md files drifted apart
- **Symptom**: `.github/CLAUDE.md` was missing the rissfest runbook that `/CLAUDE.md`
  (root) had. Root is what the bootstrap curls.
- **Cause**: a second copy that nobody kept in sync — the landfill effect in person.
- **Fix (2026-07-11)**: root `/CLAUDE.md` is the only source; `.github/CLAUDE.md` is
  now a one-line pointer to it. Never keep a second authoritative copy.

### Empty-body transactional mail across routes
- **Symptom**: transactional emails sent with empty bodies.
- **Cause**: mailer helper reused without a body on several routes.
- **Fix**: assert non-empty body in the mailer; covered across all transactional
  routes in rissfest. Watch for the same pattern when adding new routes elsewhere.

### Self-hosted Runner senken den Actions-STORAGE nicht (Kategorienfehler)
- **Symptom**: "90% der Actions storage" trotz Migration auf gha-runner-01.
- **Cause**: Runner-Typ betrifft nur **Minuten**. Artifacts + Logs liegen immer auf
  GitHubs Storage — egal wer den Job ausgefuehrt hat. Getrennte Toepfe:
  Minuten (self-hosted = 0) vs. Storage (self-hosted = unveraendert).
  Actions-Cache ist nochmal separat (10 GB/Repo, zaehlt nicht mit).
  Release-Assets zaehlen NICHT gegen Actions-Storage.
- **Fix**: `retention-days` an jedem `upload-artifact` + Repo-Policy als Backstop
  (`PUT /repos/{o}/{r}/actions/permissions/artifact-and-log-retention {"days":14}`).
  Storage wird als GB-Hours abgerechnet: Loeschen stoppt nur die KUENFTIGE
  Akkumulation, bereits aufgelaufene GB-Hours bleiben auf der Rechnung.
  -> bei Storage-Alarm sofort loeschen, nicht "morgen".

### `if cmd | tail` verschluckt jeden Fehler
- **Symptom**: repo-backup meldete monatelang "alles gruen", auch bei Clone-Fehlern.
- **Cause**: Exit-Status einer Pipeline = Exit-Status des LETZTEN Glieds (`tail`),
  nie der von `git clone`. `set -e` hilft hier nicht, `set -o pipefail` waere noetig.
- **Fix**: Exit direkt pruefen, Output in Logdatei umleiten:
  `if git clone ... > /tmp/x.log 2>&1; then ... else tail -5 /tmp/x.log; fi`

### Ohne actions/checkout wird $GITHUB_WORKSPACE nie bereinigt
- **Symptom**: repo-backup-Artifact wuchs exakt linear +25,5 MB/Tag (229 -> 408 MB).
- **Cause**: Der Job hatte kein `actions/checkout` (das raeumt den Workdir sonst auf).
  Dateien der Vorlaeufe ueberlebten, und der Upload-Glob `backup-*.tar.gz` sammelte
  jeden alten Tarball wieder mit ein. "Ephemer" gilt fuer den Runner-Prozess,
  nicht automatisch fuer den Workspace.
- **Fix**: explizites `rm -rf` als erster Step + fester Artifact-Dateiname statt Glob.

