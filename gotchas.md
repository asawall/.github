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

## docker-mailserver (ea_mailserver): Bind-Mount-Quellen weg = Zeitbombe
Am 12.07. wurden /opt/easyarchitekt/infra/mail/{state,config} geleert (vermutl.
Checkout/Clean); der laufende Container ueberlebte das mit offenen FDs. Erst der
Docker-Daemon-Restart 17.07. 04:06 machte es manifest: Postfix-Symlinks nach
/var/mail-state tot, postfix-accounts.cf weg -> "no accounts, Dovecot shutdown"-
Loop. **Fix-Muster**: force-recreate (Init migriert state neu) + Account/Aliase
via `setup email add` / `setup alias add` restaurieren (Passwort steht in
ea-outreach-Env IMAP_PASS). data/ (Maildirs) lag separat und ueberlebte.

## ea_mailserver Netz-Membership war nur manuell
Der alte Container hing per manuellem `docker network connect` im rissfest-net —
ein Recreate verliert das, rissfest-mail kann "ea_mailserver" dann nicht mehr
aufloesen. Seit 18.07. in docker-compose.mail.yml persistiert (networks:
rissfestnet external, name rissfest-net). Host-Port 25 gehoert rissfest-mail
(Inbound-Gateway, relayt intern an ea_mailserver); ea_mailserver darf
25/465/587 NICHT publishen.

## postqueue -f NIE bei unaufloesbarem Zielhost
Solange der Relay-/Zielhost per DNS nicht aufloesbar ist, wird aus deferred
(4.4.1, wird retried) beim Flush ein permanenter Bounce (5.4.4 Host not found).
Am 18.07. so 15 gestaute Inbound-Mails verloren. Reihenfolge immer: Zielhost
erreichbar machen -> Banner-Test (`nc host 25`) -> DANN `postqueue -f`.

## Compose-Drift /opt/easyarchitekt/infra/compose
docker-compose.mail.yml wurde am 12.07. geaendert (Image 14.0, Host-Ports) aber
nie angewendet; der Container lief noch auf der alten Definition (15.1.0, keine
Host-Ports, manuelles Netz). Ein spaeteres `up --force-recreate` wendet die
Datei ERSTMALS an und bricht dann an GHCR-denied (14.0 nicht lokal) und
Port-25-Konflikt. Vor jedem Recreate: `docker inspect` (Image, Ports, Netze)
gegen Compose-Datei diffen.

### kingdom-ai.service failt bei JEDEM Boot (Race mit restart-policies)
- **Symptom**: nach Reboot 1 failed unit auf KAI (`kingdom-ai.service`), Stack laeuft
  scheinbar trotzdem. Real: 6 Fehlboots in Folge, und `kingdom-redis` fehlte dadurch
  KOMPLETT — die Unit stirbt am Namenskonflikt, BEVOR sie redis erzeugt, und redis
  hatte keinen Alt-Container mit restart-policy, der ihn zurueckbringt.
- **Cause**: doppelte Lifecycle-Verwaltung. Alle Container laufen mit
  `restart=unless-stopped` UND ein oneshot-Unit macht beim Boot
  `docker compose up -d`. dockerd restauriert die Alt-Container parallel ->
  compose kollidiert am Namen `kingdom-postgres` -> Exit 1.
- **Fix (2026-07-19)**: `docker compose up -d --no-deps redis` (neu, unless-stopped,
  healthy), danach `systemctl reset-failed kingdom-ai.service`. Struktur offen:
  Empfehlung = Unit disablen (restart-policies decken den Boot ab; das
  `ExecStop=compose down` hat nie gegriffen, weil die Unit nie aktiv wurde).
  Alternative = Stack einmalig unter das Compose-Projekt recreaten und
  restart-policies entfernen. Postgres-Daten liegen im Named Volume
  `kingdom-postgres-data` — ein Recreate waere datensicher.

## PS 5.1: eingebettete doppelte Quotes an native EXEs gehen verloren (psql -c)
- **Symptom**: psql meldet `Spalte »pzn« existiert nicht` — das SQL kam ohne die
  `"PZN"`-Anfuehrungszeichen an, PG faltete den Namen zu lowercase.
- **Cause**: PowerShell 5.1 Native-Argument-Quoting reicht eingebettete `"` nicht
  zuverlaessig an C-Runtime-Programme durch (weder aus '...'-Strings noch via \").
- **Fix**: SQL in Datei schreiben (`Set-Content`, single-quoted, `''` fuer `'`)
  und `psql -f datei.sql` nutzen. Gilt generell fuer native EXEs mit
  Quote-haltigen Argumenten.

## Scheduled Task rot: 0x800710E0 und 0xFFFD0000 (Botmatiq DB-Backup, IPC)
- **Symptom**: Task 'Bereit', aber Letztes Ergebnis -2147020576 (0x800710E0)
  bzw. nach Settings-Fix 4294770688 (0xFFFD0000); kein 02:30-Logeintrag.
- **Cause**: (1) schtasks-Default-Conditions (AC-Power/Idle) verweigern den
  Start. (2) Das /TR-Escaping beim Install legte literale `\"...\"` in die
  Action — `powershell -File` fand die Datei nicht. Merseburg-IPC hat
  LocalMachine=AllSigned: Task-Actions brauchen zwingend
  `-ExecutionPolicy Bypass`.
- **Fix**: `New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
  -DontStopIfGoingOnBatteries -StartWhenAvailable` setzen UND die Action per
  `New-ScheduledTaskAction` mit sauberem Argument-String neu schreiben;
  danach Teststart + Log pruefen, nicht nur den Task-Status.

### Ein einzelnes certbot-Cert laeuft ab, obwohl der Timer gruen ist
- **Symptom**: genau EIN Cert expired/kurz vor Ablauf, `certbot.timer` laeuft, alle
  anderen Certs renewen normal. (admin.tecmatiq.de, 07/2026)
- **Cause**: die renewal conf DIESES Certs steht auf `authenticator = standalone`
  (z.B. weil es mal manuell mit `--standalone` ausgestellt wurde — certbot merkt sich
  die Methode pro Cert). Renewal will Port 80 binden, nginx belegt ihn -> stiller Fail.
- **Fix**: `certbot certonly --cert-name X -d X --webroot -w /var/www/certbot` — schreibt
  die renewal conf dauerhaft auf webroot um. Audit: `grep -L webroot /etc/letsencrypt/renewal/*.conf`.

### HTTP-01-Challenge failt mit 404 trotz korrektem DNS + webroot
- **Symptom**: `Invalid response from https://DOM/.well-known/acme-challenge/...: 404`,
  DNS zeigt auf den richtigen Server. (8x *.kingdom-hosting.de, 07/2026)
- **Cause**: der Port-80-Block macht `return 301 https://...` OHNE acme-Ausnahme.
  LE folgt dem Redirect auf HTTPS; der HTTPS-Vhost proxied auf die App -> 404.
- **Fix**: im :80-Block VOR dem Redirect:
  `location /.well-known/acme-challenge/ { root /var/www/certbot; }` und den Redirect in
  `location / { return 301 ...; }` wrappen.

### nginx sites-enabled: Backup-Dateien werden mitgeladen
- **Symptom**: `conflicting server name ... ignored`-Warnungen nach Config-Backups.
- **Cause**: Ubuntu-Default `include /etc/nginx/sites-enabled/*;` laedt ALLE Dateien,
  egal welche Endung (.bak, .acmebak, ...). In conf.d gilt `*.conf` — dort sind
  Nicht-.conf-Backups harmlos.
- **Fix**: Backups von sites-enabled-Dateien NIE im selben Verzeichnis ablegen ->
  /root/nginx-acmebak/ o.ae.

### Monitoring, das sich selbst nicht ueberwacht (3 Blindstellen auf einmal)
- **Symptom**: Cert lief ab, kein Alarm. (07/2026)
- **Cause**: (a) daily-health.yml stand auf `disabled_manually` (GitHub disabled
  scheduled Workflows auch automatisch nach 60d Repo-Inaktivitaet); (b) SSL-Check mit
  verifizierendem Context wirft bei expired -> `ssl_days=None` -> kein Alarmpfad;
  (c) TG_TOKEN-Repo-Secret war rotiert -> sendMessage 401, nur stiller print.
- **Fix**: Workflow-State pruefen (`GET /actions/workflows` -> `state`); Cert-Ablauf mit
  `ssl._create_unverified_context()` + `openssl x509 -enddate` lesen und expired explizit
  melden; Alert-Creds zur Laufzeit aus Vault ziehen statt Repo-Secret (daily-health.yml
  macht das jetzt, Fallback Repo-Secret bleibt).

### Traceback-Zeilennummern passen nicht zum Repo-Code
- **Symptom**: Fehler-Traceback nennt Zeile 377, die Repo-Datei hat nur 269 Zeilen.
  (linkedin-phase2 fact_validator, 07/2026)
- **Cause**: /opt-Deployment wurde direkt auf dem Server gepatcht (Retry-Wrapper), nie
  committed. Repo und Live-Stand drifteten wochenlang.
- **Fix**: Bei Debugging IMMER erst den Live-Stand vom Server ziehen (base64 via One-shot),
  gegen den patchen, und den gefixten Stand zurueck ins Repo committen. Danach ist das
  Repo wieder Source of Truth. Server-Hotfixes ohne Commit sind verboten (regeln.md).

### Anthropic 529 kann modell-spezifisch sein — Retry allein reicht nicht
- **Symptom**: fact_validator (Opus) faellt 6x hintereinander mit 529, waehrend
  content_generator (Sonnet) im selben Run problemlos durchlief. (07/2026)
- **Cause**: Overload-Phasen treffen oft nur EIN Modell und dauern laenger als ein
  kurzes Retry-Fenster (~3min). Backoff auf demselben Modell laeuft dann ins Leere.
- **Fix**: Kreuz-Modell-Fallback im Wrapper (Opus<->Sonnet) mit frischem Retry-Budget
  pro Modell; systemd TimeoutStartSec gross genug fuer das Gesamtbudget (1800s).
  Muster: messages_create_resilient(..., _fallback_model=FALLBACK_MODEL).

### Kaputte Tests blockieren die Dependabot-Kaskade
- **Symptom**: Woechentliche Dependabot-PRs seit Wochen rot, Security-Updates liegen brach.
  (botmatiq-mcp, 06-07/2026)
- **Cause**: Ein Refactor (DbContext sealed) brach die Test-Kompilierung auf main; jede PR
  testet gegen main-Merge und erbt den Fehler. rerun-failed-jobs hilft NICHT (laeuft gegen
  alten Merge-Commit) — nach dem main-Fix pro PR `@dependabot rebase` kommentieren.
- **Fix**: main-Tests fixen, dann rebase-Kommentare; CI-gruene Actions-PRs mergen,
  Runtime-Majors bewusst entscheiden.

### SARIF-Upload braucht GitHub Advanced Security
- **Symptom**: `Code scanning is not enabled for this repository` / vorher maskiert als
  `Resource not accessible by integration`. (botmatiq-mcp, privates Repo)
- **Cause**: code-scanning-API ist ohne GHAS-Lizenz fuer private Repos hart 403 —
  keine Permission der Welt aendert das.
- **Fix**: upload-sarif-Step entfernen; trivy mit format table + exit-code 1 als Gate reicht.

### GitHub-API: NIEMALS gekuerzte SHAs vervollstaendigen
- **Symptom**: `does not match` bei Contents-PUT bzw. `Unable to resolve action` bei
  Action-Pins. (2x in einer Session, 07/2026)
- **Cause**: Anzeige-Skripte kuerzen SHAs auf 10-12 Zeichen; der Rest wurde "aus dem
  Gedaechtnis" ergaenzt — halluziniert.
- **Fix**: Vor jedem PUT/Pin die volle 40-Zeichen-SHA frisch aus der API ziehen.
  Tag-Pins via git/ref/tags aufloesen (annotated Tags dereferenzieren!).

### Dependabot-npm-PRs mit unvollstaendiger package-lock.json
- **Symptom**: `npm ci` bricht mit `Missing: <pkg> from lock file` ab, auch nach
  `@dependabot recreate`. (frag-einen-v2 PR#41)
- **Cause**: Dependabot laesst bei Gruppen-Bumps gelegentlich transitive Lock-Eintraege aus.
- **Fix**: PR-Branch klonen, in der App `npx -y npm@<CI-Version> install --package-lock-only
  --ignore-scripts`, nur die Lock committen und auf die Dependabot-Branch pushen.

### sealed DbContext in Tests
- **Symptom**: CS0509/CS0115 — Test-Subclass kann sealed Context nicht erben/ueberschreiben.
- **Fix**: `options.ReplaceService<IModelCustomizer, EigenerCustomizer>()`; im Customizer
  base.Customize() aufrufen, danach Modell anpassen. Shadow-Property MUSS vor HasKey
  deklariert werden (`Property<Guid>(..)` dann `HasKey(..)`) — umgekehrt wirft EF
  InvalidOperationException im Customizer-Pfad.

## UniFi WireGuard-Conf-Import (UCG, Network 10.x)
- **Symptom**: "Missing Address in [Interface]" trotz vorhandener Zeile; nach
  dem Fix folgt "Invalid DNS in [Interface]".
- **Cause**: Der Import-Parser trimmt `\r` nicht — CRLF-Dateien erzeugen die
  Sektion `[Interface]\r`, die nie matcht. DNS ist bei UniFi Pflichtfeld,
  obwohl wg-quick es optional laesst.
- **Fix**: Conf LF-only+ASCII erzeugen (`[IO.File]::WriteAllText` mit
  Backtick-n, NICHT Set-Content) und `DNS = 10.99.0.1` ergaenzen (ohne
  Traffic-Routing wirkungslos, reine Parser-Beruhigung).

## UCG-Ultra: WireGuard taugt nicht als Site-Gateway (Network 10.4.57)
- **Symptom**: WG-"VPN Client" zeigt Connected (Handshake + rx/tx), aber
  eingehender Tunnel-Traffic Richtung Gateway UND LAN wird verworfen —
  Mac→50.x und Server→10.99.0.20 beide 100% loss trotz korrektem Routing.
  Legacy-API kennt keine VPN_*-Rulesets (api.err.InvalidValue),
  Site-to-Site bietet nur IPsec/OpenVPN.
- **Cause**: Der VPN-Client ist ein Egress-Feature (LAN-Traffic durch einen
  Provider-Tunnel rausrouten), kein Site-Terminator; WG-Site-to-Site
  existiert in dieser Firmware nicht.
- **Fix/Entscheid 20.07.2026**: 50er-Netz remote laeuft ueber den IPC-Peer
  (10.99.0.10); UCG-Verwaltung IPC-unabhaengig via UniFi Remote Management
  (outbound HTTPS, keine Portfreigabe). IPsec-S2S nur falls je noetig,
  fruehestens nach IBN.

### Workflow-Environment-URL bedeutet nicht, dass der Dienst je lief
- **Symptom**: Deploy-Job mit environment-URL https://mcp.botmatiq.com/healthz, Domain
  antwortet 503 (Envoy "upstream connect error") — sah aus wie ein Ausfall. (07/2026)
- **Cause**: Die Strecke war nie live: Deploy-Secrets leer, Key-Pfad /home/gha existiert
  auf keinem Runner, DNS zeigt auf die Website-Plattform statt auf einen Server mit dem
  Container, /opt/botmatiq auf dem vermuteten Host nicht vorhanden.
- **Fix/Lehre**: Vor Incident-Reaktion oder Monitoring-Aufnahme pruefen, ob der Dienst
  jemals deployt war (Deploy-Job-Historie, DNS-Ziel, Host-Bestand). Ein nie gelaufener
  Deploy-Job ist ein Befund, kein Ausfall.

### .NET-10-Upgrade-Fallen
- Debian-Basisimages existieren fuer .NET 10 nicht mehr (kein bookworm/trixie) —
  noble (Ubuntu 24.04), alpine oder azurelinux; Tag-Existenz via
  mcr.microsoft.com/v2/dotnet/<img>/manifests/<tag> pruefen (tags/list ist unvollstaendig).
- System.Threading.RateLimiting ist ab net10 im Shared Framework: explizite
  PackageReference erzeugt NU1510, mit TreatWarningsAsErrors ein Build-Error.
- aspnet-Images enthalten kein wget — HEALTHCHECK mit wget braucht apt-get install.

## GitHub Contents-API: leerer base64-String ueberschreibt Datei mit 0 Bytes (20.07.2026)
`B64=$(base64 -w0 datei)` bei fehlender Datei ergibt leeren String; der PUT mit
`"content":""` wird von GitHub akzeptiert und LEERT die Zieldatei (passiert bei
build-mcp.yml, sofort restauriert). Regel: vor jedem Contents-PUT `[ -s file ] || exit 1`.

## GitHub-Actions-YAML: Heredocs in run-Bloecken (20.07.2026)
Heredoc-Inhalte in Spalte 1 innerhalb `run: |` verlassen den YAML-Literal-Block
-> Parse-Fehler ("could not find expected ':'"). Remote-Scripts IMMER als base64
einbetten: `echo "$B64" | base64 -d > /tmp/x.sh; ssh host 'bash -s' < /tmp/x.sh`.

## Compose-Multi-Netz: Service muss in ALLE benoetigten Netze (20.07.2026)
botmatiq-prod hat botmatiq-net UND botmatiq-internal; db haengt nur in internal.
Ein Override-Service nur in botmatiq-net erreicht caddy, aber NICHT die db
(NpgsqlException "Resource temporarily unavailable"). Netze dynamisch aus den
top-level networks der prod-Compose uebernehmen.

## Self-hosted Runner sind bei User-Accounts strikt PRO REPO (20.07.2026)
Kein Org-Level. Neues Repo -> Job haengt ewig "queued". Loesung: Runner-Container
auf gha-runner-01 als Sibling starten (Runner-Container haben docker.sock):
bestehenden Container inspecten (Image/Env/Mounts generisch uebernehmen),
REPO_URL/RUNNER_NAME/LABELS/RUNNER_TOKEN ersetzen, `docker run -d --restart always`.
Registration-Token via API (PAT kann das). Muster: gha-botmatiq-mcp-1.

## sed -i auf file-bind-mounted Datei: Container haelt alte inode (20.07.2026)
`sed -i deploy/Caddyfile` + `caddy reload` laedt die ALTE Config (Bind-Mount einer
Datei bindet die inode). Nach in-place-Edits gemounteter Dateien: Container
recreaten (`compose up -d --force-recreate <svc>`), nicht nur reload.

## workflow_dispatch ist nur ausloesbar, wenn der Workflow REGISTRIERT ist (2026-07-22)
- Symptom: `POST /actions/workflows/<datei>.yml/dispatches` -> 404 "Not Found" fuer
  einen frisch auf einen NICHT-Default-Branch (z.B. staging) gepushten
  workflow_dispatch-Workflow; `GET /actions/workflows/<datei>.yml` ebenso 404.
- Cause: Ein Workflow ist erst per REST/UI dispatchbar, wenn er "registriert" ist —
  das passiert, wenn er auf dem Default-Branch (main) liegt ODER schon mindestens
  einmal lief (z.B. per push-Trigger). Ein reiner dispatch-Workflow, der nur auf
  staging liegt und nie lief, ist NICHT registriert. Verifiziert an easyarchitekt:
  clone-prod-to-staging.yml (nur staging, nie gelaufen) -> 404; deploy-staging.yml
  ist registriert, weil es per push laeuft.
- Fix-Optionen: (a) Logik als Step in einen bereits per push laufenden Workflow
  legen (z.B. deploy-staging.yml) -> gar kein Dispatch noetig; sauberste Loesung
  fuer staging-Tooling, zudem selbstheilend. (b) Einen bereits registrierten
  dispatch-Workflow (z.B. diag-once.yml, liegt auf main+staging) mit `ref=staging`
  dispatchen -> laeuft die staging-Version der Datei. (c) NICHT einfach auf main
  pushen, nur um zu registrieren: deploy.yml (push:main, kein Pfad-Filter) wuerde
  sofort einen PROD-Deploy ausloesen.

## easyArchitekt: Demo-Seed haengt Super-Admins in KEINE Org (2026-07-22)
- Symptom: Als Super-Admin (a.sawall@/a.graf@) in Staging etwas org-scoped anlegen
  (Kontakt/Person, etc.) -> Fehler "verknuepfter Datensatz existiert nicht"
  (Prisma/FK Contact_organizationId_fkey, organizationId='').
- Cause: prisma/seed.ts legt die Demo-Org musterbau-gmbh-demo an und gibt NUR den
  Rollen-Demo-Usern (usersByRole) eine OrganizationMembership. Die Super-Admins
  werden oben separat als User angelegt und in KEINE Org gehaengt. Login
  (auth.service.ts) setzt JWT orgId aus user.memberships[0] -> ohne Membership leer.
  OrgId-Decorator: header x-org-id || token orgId || '' -> '' -> Contact.create({organizationId:''}) -> FK-Fehler.
- User hat KEINE direkte orgId-Spalte; Org-Zugehoerigkeit laeuft ausschliesslich ueber
  OrganizationMembership (unique [organizationId,userId]).
- Fix (im Staging-Sync, deploy-staging): Owner-Org planningx-gmbh sicherstellen
  (Slug -> getPlanConfig gibt Enterprise) und beide Super-Admins dort + in der
  Demo-Org als ORG_ADMIN upserten. Idempotent.
- Merke: Nach dem Fix muss eine bereits offene Session neu einloggen, sonst traegt
  der alte Token weiterhin kein orgId.

## easyArchitekt: Gewerke (OrgTrade) fehlen bei jeder neu entstandenen Org (2026-07-23)
- Symptom: Beim Anlegen einer Firma ist die Gewerke-Auswahl leer (0 Gewerke).
- Cause: OrgTrades wurden ausschliesslich per Migration angelegt
  (20260421102450_org_trades_many_to_many, 20260504100000_add_putz_trades), jeweils
  `FROM "Organization" o CROSS JOIN (VALUES ...)` — also nur fuer die zum
  Migrationszeitpunkt existierenden Orgs. `register()` in auth.service.ts legte die
  Org OHNE OrgTrade-Zeilen an. Es gibt sonst KEINEN automatischen Pfad (nur manuelles
  Anlegen ueber org-trades.service.create). Folge: jede nach dem Migrationsdatum
  registrierte Org (auch echte Prod-Kunden!) hat 0 Gewerke.
- Fix: DEFAULT_TRADES in apps/api/src/config/default-trades.ts (32 Gewerke) wird in
  register() per createMany angelegt; Nachtrag fuer bestehende Orgs via
  infra/scripts/seed-default-trades.sql (rein additiv, idempotent, WHERE NOT EXISTS
  je Gewerkename -> manuell angelegte Gewerke bleiben unangetastet).
  Wrapper: infra/scripts/ensure-default-trades.sh (TARGET=staging|prod).
- Merke: Migrationen mit CROSS JOIN ueber Organization sind IMMER ein Einmal-Effekt.
  Wer Referenzdaten so seedet, MUSS denselben Seed auch im Anlage-Pfad haben.

## easyArchitekt: Staging ist Demo-Seed, kein Prod-Clone — Schema aber identisch (2026-07-23)
- Geprueft mit infra/scripts/diff-prod-staging.sh (read-only: Rowcounts, Orgs,
  Gewerke, Migrationen, Spalten-, Enum-Diff), dispatchbar ueber diag-once.yml (ref=staging).
- Schema-Paritaet ist perfekt: 647 Spalten identisch, keine Enum-Differenz.
  Daten weichen massiv ab (Staging = Demo-Seed). Das ist by design (docs/staging.md);
  echter 1:1-Datenstand nur ueber clone-prod-to-staging.sh (anonymisiert, wipet Staging).
- _prisma_migrations: Prod hat 41, Repo/Staging 40. Der Extra-Eintrag
  20260618170000_mailsendlog_mangelprotokoll existiert in KEINEM Branch — handgeschriebene
  Migration wurde in Prod eingespielt und nie committet. Ohne Schema-Wirkung (Spalten-Diff leer),
  aber Repo beschreibt den Prod-Ledger nicht vollstaendig.

## easyArchitekt: main und staging haben KEINE gemeinsame Historie (2026-07-23)
- Symptom: `git diff staging...origin/main` -> "fatal: no merge base".
  Ein `git merge staging` in main wuerde --allow-unrelated-histories verlangen und
  praktisch jede Datei in Konflikt bringen.
- Folge: Der Weg "staging nach main mergen" aus der Doku funktioniert NICHT als Merge.
- Vorgehen stattdessen: Branch aus origin/main erstellen und gezielt nur die noetigen
  Dateien uebernehmen: `git checkout -B fix origin/main` +
  `git checkout staging -- <pfade>` + commit + `git push origin HEAD:main`.
  Vorher pruefen, ob die Datei auf beiden Branches identisch ist (dann uebertraegt
  sich der Patch sauber): `git show origin/main:<pfad>` gegen `git show staging:<pfad>`.
- ACHTUNG Fallstrick: Beim Branch-Wechsel gehen so gestagte Dateien verloren, wenn sie
  auf dem Zielbranch identisch existieren (Index wird "clean"). Also: staggen UND sofort
  committen, nicht zwischendurch den Branch wechseln.

## easyArchitekt: push auf staging loeste keinen Deploy aus (2026-07-23)
- Beobachtet bei Commit 53eed95: Push auf staging ohne [skip ci], trotzdem 0 Runs
  (`GET /actions/runs?head_sha=...` -> total_count 0). Ursache nicht abschliessend geklaert.
- Workaround: deploy-staging.yml hat `workflow_dispatch` und ist registriert ->
  `POST /actions/workflows/deploy-staging.yml/dispatches -d '{"ref":"staging"}'`.
- Merke: nach jedem Push verifizieren, dass wirklich ein Run existiert, statt anzunehmen.

## Next 15: useSearchParams braucht eine Suspense-Boundary (2026-07-23)
- Ein Hook, der intern useSearchParams nutzt (hier useProjectFilter), laesst den
  Next-Build der Seite scheitern, wenn die Page nicht in <Suspense> gewrappt ist.
- Typecheck (tsc --noEmit) faengt das NICHT — nur `pnpm --filter @easyarchitekt/web build`.
- Muster im Repo: innere Komponente XPageInner + default export mit <Suspense fallback=...>.
  Vor jedem Push von Web-Aenderungen einmal den echten Next-Build laufen lassen.
