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

### Verschachteltes ssh/sftp frisst den restlichen Heredoc als stdin
- **Symptom**: `ssh host 'bash -s' << 'REMOTE'` — das Script bricht nach dem
  ersten inneren `ssh`/`sftp` kommentarlos ab, Rest der Ausgabe fehlt spurlos,
  exit=0. Sieht aus wie "hat funktioniert".
- **Cause**: Der innere Client liest stdin — und das ist der noch ungelesene
  Heredoc des aeusseren `bash -s`.
- **Fix**: jedes verschachtelte `ssh` mit `-n`, `sftp` mit `-b datei`,
  `rsync` mit `< /dev/null`. **Aber**: wenn ein Aufruf selbst einen Heredoc
  bekommen soll, darf er KEIN `-n` haben — dann kaeme nichts an.

### Content-Regel gilt nur in EINER Pipeline, die Schwester-Pipeline kennt sie nicht
- **Symptom**: Andreas' realer Ex-Arbeitgeber (Hilti) stand monatelang in jedem
  zweiten LinkedIn-Kommentar-Entwurf im Telegram-Digest — obwohl die Regel
  "reale Ex-Arbeitgeber = SOFORT FAIL" laengst existierte.
- **Cause**: Die Regel lebte nur in der POST-Pipeline (`linkedin-phase2`:
  `content_generator.py` + `fact_validator.py`). Die KOMMENTAR-Pipeline
  (`va-comment-copilot`: `backend/main.py`) ist ein eigenes Repo, hat einen
  eigenen Voice-Prompt — und nannte Hilti dort sogar aktiv als Persona-Fakt.
  Zwei Systeme, eine Marke, eine Stimme, aber nur ein Regelwerk gepflegt.
- **Fix**: Voice-/Content-Regeln gelten fuer die MARKE, nicht fuer ein Repo. Wird
  eine Regel in einer Pipeline geaendert, immer pruefen: wer erzeugt sonst noch
  Text unter demselben Namen? Aktuell: `linkedin-phase2` (Posts),
  `va-comment-copilot` (Kommentare), `sape-control-plane/pipeline/content_exec.py`
  (autonomer Content), `profiles/vertriebsarchitekt.json` (Outreach-Sequenzen).
- **Zusatz**: Prompt-Regel allein reicht nie, wenn der FREMDE Input den verbotenen
  Begriff enthaelt — das Modell spiegelt ihn dann. Deterministischer Output-Guard
  noetig (gleiche Lehre wie beim Umlaut-Guard). Seit 15.07.2026:
  `enforce_no_employers()` in `va-comment-copilot/backend/main.py`, Regex ->
  Haiku-Rewrite -> harter Drop, live gegen einen Hilti-nennenden Post verifiziert.

### `git push` auf va-comment-copilot deployt NICHT
- **Symptom**: Fix ist auf `main`, CI gruen — der Digest am naechsten Morgen zeigt
  trotzdem das alte Verhalten.
- **Cause**: Zwei Dinge gleichzeitig. (1) `deploy.yml` hat NUR
  `on: workflow_dispatch` — der Kommentar direkt darueber behauptet faelschlich
  "push auf main / dispatch". (2) Das Repo hat NULL registrierte Runner, aber
  `runs-on: [self-hosted, linux, va-comment-copilot]` — ein Dispatch haengt ewig.
  Zusaetzlich fehlen die Repo-Secrets `VAULT_CLIENT_ID/SECRET` (der PAT darf keine
  Secrets schreiben — bewusst). Das Backend auf KAI wurde nie ueber CI deployt.
- **Fix**: Bis Runner + Secrets existieren, Deploy per One-shot-Workflow aus
  `infra-monitoring` (hat Runner + Vault-Secrets): Source dort auschecken, als
  tar-Stream nach KAI, `docker compose -f docker-compose.prod.yml up -d --build`.
  `.env` (ANTHROPIC_API_KEY + COPILOT_SHARED_SECRET) und `discovery/seen.json`
  vom tar ausschliessen, sonst sind Key und Digest-Dedup-State weg.
  KEINEN Push-Trigger in `deploy.yml` ergaenzen, solange kein Runner existiert —
  das produziert nur ewig haengende Jobs.

### /mnt/storagebox-nc ist nicht der Storage-Box-Root
- **Symptom**: `sftp ls` auf der Box zeigt `nextcloud-data`, aber kein
  `db-backups` — obwohl Workflows erfolgreich `/mnt/storagebox-nc/db-backups`
  lesen. Sieht nach zwei verschiedenen Boxen aus. Ist es nicht.
- **Cause**: fstab mountet `u570556@...:nextcloud-data` nach `/mnt/storagebox-nc`.
  `db-backups` liegt also IN `nextcloud-data`.
- **Fix**: Pfade immer gegen `mount | grep sshfs` pruefen, nicht gegen ein
  sftp-Root-Listing.

### Hetzner Storage Box: SSH ist eine Restricted Shell
- **Symptom**: `ssh u570556@... "ls -la"` -> `Command not found. Use 'help'`,
  exit=8. Wirkt wie ein Auth- oder Netzwerkfehler.
- **Cause**: Ist keiner — die Auth war erfolgreich. Die Box erlaubt nur einen
  kleinen Befehlssatz (`df` allein geht, `echo`/Verkettungen nicht).
- **Fix**: fuer alles Echte `rsync`/`sftp -b`/`scp` benutzen oder den
  vorhandenen SSHFS-Mount auf dem Hosting-Server.

### JetBackup: mtime auf der Storage Box ist KEIN Gesundheitssignal
- **Symptom**: `backup/jetbackup/jetbackup_1_1_<job>/` und die Account-Ordner
  darunter zeigen mtimes von vor Monaten. Sieht nach totem Backup aus.
- **Cause**: Ist es nicht. `Backup Structure: Incremental (1)` legt die
  Rotations-Slots `snap.1..snap.N` EINMAL an und schreibt danach nur noch in
  `files00000000NN/` und `jetbackup.index` hinein. Ein Verzeichnis-mtime aendert
  sich nur, wenn ein Eintrag darin angelegt/geloescht wird — bei reinem
  Hineinschreiben nie. Die Account-mtimes stehen deshalb auf dem Tag, an dem der
  letzte snap-Slot entstand.
- **Fix**: Gesundheit NUR an diesen drei Dingen pruefen, nie am mtime:
  1. `jetbackup.index` mtime im Account-Ordner (wird jede Nacht angefasst)
  2. `files00000000NN/` mtime (der eigentliche Dedup-Store)
  3. das Job-Log `1_*.log` in `/usr/local/jetapps/var/log/jetbackup5/queue/`
     — "Backup Completed" pro Account. NICHT `128_*.log`, das ist Snapshot-Cleanup.
- Stand 14.07.2026 verifiziert gesund: 8 Accounts, ~95 s/Nacht (incremental +
  dedup, 900 Mbit/s Upload), Box 937 GB / 5 TB.
- **Waisen**: `jetbackup_1_1_69ce2054...` (25.04.) und `jetbackup_3_4_69ce1dbf...`
  (05.04.) gehoeren zu keinem aktiven Job mehr — JetBackup raeumt Destination-Daten
  beim Loeschen eines Jobs nicht auf. Nur Platz, kein Fehler.

### Fremd-IDs aus dem Request-Body landen ungeprueft in Relationen
- **Symptom**: keins. Faellt nie auf, bis jemand es ausnutzt — ein POST mit einer
  contactId/companyId aus einer anderen Org haengt die Relation klaglos an.
- **Cause**: der Endpunkt prueft die Ressource selbst (`assert(orgId, id)`), aber
  nicht die IDs, die im Body mitkommen. In easyArchitekt betraf das
  BegehungPerson.contactId/companyId an drei Schreibpfaden (create, addPerson,
  aiApply) — die Firmen-IDs von Gewerk/Mangel/Abstimmung waren geprueft, die der
  Teilnehmer nicht. Klassische Luecke: die Prueflogik wurde pro Feature
  geschrieben statt pro Schreibpfad.
- **Fix**: eine `assertPersonRefs`-artige Methode pro Entitaet, durch die JEDER
  Schreibpfad geht — nicht die Pruefung im gerade angefassten Endpunkt
  nachziehen. `deletedAt: null` mitpruefen. Beim Review neuer Endpunkte: jede ID
  im Body ist ungeprueft, bis das Gegenteil im Code steht.

### KI-Review verwirft Eintraege still, wenn die Stammdaten fehlen
- **Symptom**: Diktat nennt eine Firma, das Review zeigt sie an ("Erkannt: …"),
  nach "Uebernehmen" ist der Eintrag weg. Keine Fehlermeldung.
- **Cause**: das Frontend filtert Items ohne aufgeloeste `companyId` vor dem
  Absenden raus. Der Resolver kann aber nur matchen, was schon in den Stammdaten
  steht — und aus dem Review fuehrte kein Weg dorthin.
- **Fix**: jeder Review-Screen, der gegen Stammdaten aufloest, braucht einen
  Anlege-Weg im selben Screen. Generell: wenn eine Pipeline Items still
  verwirft, ist das ein Bug, kein Filter — entweder Weg anbieten oder sichtbar
  machen, dass etwas faellt.


### Anthropic cost_report `amount` ist in CENT, nicht USD — trotz `"currency":"USD"`
- **Symptom**: `/v1/organizations/cost_report` meldet 1442.48 fuer einen Tag. Sieht aus
  wie eine Kostenexplosion auf 1.442 USD/Tag. Ich war eine Minute davon entfernt,
  Andreas einen 460-EUR/Tag-Notfall zu melden, den es nicht gibt.
- **Cause**: Das Feld `amount` kommt in Minor Units (Cent). Das `currency`-Feld sagt
  trotzdem "USD". Real waren es 14,42 USD.
- **Fix**: `amount / 100` rechnen. **Immer gegenrechnen**, bevor eine Kostenzahl
  eskaliert wird: `usage_report/messages` (Tokens) x Listenpreis muss zum
  `cost_report` passen. Verifiziert 15.07.2026 an drei Tagen unabhaengig, Verhaeltnis
  exakt 100.0. Generelle Lehre: eine Zahl, die 100x groesser ist als die Erwartung,
  ist meistens eine Einheit, kein Ereignis.

### OpenAI Legacy `/v1/usage?date=` ist tot — antwortet 200 mit leerem `data`
- **Symptom**: `/v1/usage?date=YYYY-MM-DD` liefert HTTP 200 und `"data": []` fuer
  jeden Tag. Sieht aus wie der Beweis, dass ein Projekt nichts verbraucht hat.
- **Cause**: Der Endpoint wird nicht mehr befuellt. Er ist deprecated, gibt aber
  keinen Fehler zurueck — nur Leere. Ein stiller Nullwert ist kein Messwert.
- **Fix**: Gegentest, bevor man einem Nullwert glaubt: einen echten Call absetzen
  (`max_tokens:1`, ~0,00001 USD) und pruefen, ob er in der Statistik auftaucht.
  Tat er nicht -> Instrument unbrauchbar. Kosten nur ueber
  `/v1/organization/costs` (braucht **Admin-Key** `sk-admin-...`, Scope
  `api.usage.read`) messen. Ein `sk-proj-...`-Key bekommt dort 403.

### Ein OpenAI-Key ueber alle Apps = keine Kostenzuordnung moeglich
- **Symptom**: "Die OpenAI-Rechnung steigt, welche App ist es?" ist mit dem
  Dashboard nicht beantwortbar.
- **Cause**: `tecmatiq/prod/providers/OPENAI_API_KEY` wird bewusst geteilt
  (Kommentar in easyarchitekt `deploy.yml`). Stand 15.07.2026 haengen daran:
  ea_api, ea_api_staging, rissfest-web, va-n8n, vertriebsarchitekt. Zusaetzlich
  laufen zwei eigene Keys auf KAI (kingdom-backend, ai-litellm). Alle Kosten
  landen in einem einzigen OpenAI-Projekt (`proj_rUF6r9c2FssD0g85rLv42PvC`,
  Org `tecmatiq-gmbh`).
- **Fix**: Pro App ein eigenes OpenAI-Projekt + eigener Key. Dann schluesselt das
  Dashboard von selbst auf, ohne Traffic-Messung. Kostet nichts, dauert Minuten.

### `grep -r` folgt keinen Symlinks — Vhost galt faelschlich als inaktiv
- **Symptom**: `grep -rlE 'litellm|:4000' /etc/nginx/sites-enabled/` findet nichts.
  Schluss: "kein Vhost zeigt auf den Dienst, also nicht von aussen erreichbar."
  Falsch — `private.kingdom-hosting.de` proxyt sehr wohl auf 127.0.0.1:4000.
- **Cause**: `sites-enabled/` enthaelt ausschliesslich **Symlinks** nach
  `sites-available/`. `grep -r` steigt in Symlinks NICHT ab (`-R` schon). Der
  Nullwert war ein Artefakt des Werkzeugs, kein Befund. Zusammen mit dem
  Loopback-Binding (`127.0.0.1:4000`) ergab das ein falsches Gesamturteil
  "nicht erreichbar" — dabei ist genau das die normale Reverse-Proxy-Topologie:
  Dienst auf Loopback + nginx auf 443 davor.
- **Fix**: Erreichbarkeit NIE aus Port-Bindings + Config-Greps schliessen.
  Immer `nginx -T` gegen die *laufende* Config:
  `nginx -T | awk '/server_name/{sn=$0} /127.0.0.1:PORT/{print sn" => "$0}'`.
  Und fuer Configs unter sites-enabled `grep -R` statt `grep -r`.

## str_replace: Anhaengen ans Klassen-/Dateiende
Beim Einfuegen neuer Methoden/Tests am Ende einer Klasse darf old_str NICHT
das schliessende Methoden-Ende des Vorgaengers enthalten — sonst wird es
mitgeloescht und die Klammerstruktur zerfaellt (16.07.2026 zweimal dieselbe
Testklasse zerlegt: CS0106/CS1513). Muster: als Anker den letzten
INHALTS-Block des Vorgaengers + dessen komplettes Ende in old_str UND new_str
identisch mitfuehren, oder per Python-Insert mit assert count==1 arbeiten.
