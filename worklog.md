# worklog.md — last ~30 sessions in keywords

> Newest on top. One line per session: `YYYY-MM-DD — what changed`. Keep it terse.
> When it grows past ~30 lines, trim the oldest — this is a rolling window, not an
> archive. Deeper detail lives in the per-area files, not here.

- 2026-07-23 — easyArchitekt Prod/Staging-Paritaetspruefung (diff-prod-staging.sh, read-only). Ergebnis: SCHEMA ist 1:1 identisch (647 Spalten, alle Enums gleich, 0 Diffs) — Unterschied liegt ausschliesslich in DATEN (Staging = Demo-Seed, kein Prod-Clone: Company 32/13, Contact 27/6, MediaAsset 664/12, Project 18/4, ScheduleTask 39/0, OrgTrade 67/0). ROOT CAUSE Gewerke: OrgTrades wurden NUR per Migration via CROSS JOIN ueber damals existierende Orgs angelegt; register() legt keine an -> jede spaeter entstandene Org hat 0 Gewerke. Fix: DEFAULT_TRADES (32, config/default-trades.ts) in register() + infra/scripts/seed-default-trades.sql (additiv, idempotent) als Deploy-Step fuer Staging. Verifiziert: Neuregistrierung auf Staging liefert 32 Gewerke. OFFEN/PROD: echte Kunden-Orgs in Prod haben 0 Gewerke (hallo-a0378e, landscap-ing-isabell-piela, test-ad***) — Backfill via TARGET=prod ensure-default-trades.sh + Code-Merge nach main, wartet auf Andreas' Freigabe. Zudem: _prisma_migrations hat in Prod 1 Eintrag (20260618170000_mailsendlog_mangelprotokoll), der in keinem Branch existiert — ohne Schema-Wirkung.
- 2026-07-22 — easyArchitekt Staging Folgefix: Person/Kontakt anlegen scheiterte mit 'verknuepfter Datensatz existiert nicht'. Ursache: Demo-Seed haengt die Super-Admins in KEINE Org (nur die Rollen-Demo-User bekommen Membership), a.sawall@ war zudem neu per Sync angelegt -> User.memberships[0] leer -> JWT orgId leer -> Contact.create mit organizationId='' -> FK Contact_organizationId_fkey. Fix: Sync (deploy-staging) stellt jetzt zusaetzlich Owner-Org planningx-gmbh (Slug->Enterprise) sicher und macht a.graf@/a.sawall@ ORG_ADMIN dort + in musterbau-gmbh-demo. Gegen PG16 lokal verifiziert (Contact-Insert ok, leere Org=FK-Fehler) und auf echter Staging-DB (Run 29943693276): je 2 aktive Memberships. Achtung: bestehende Session braucht Re-Login (alter Token hat kein orgId).
- 2026-07-22 — easyArchitekt Staging: Super-Admin-Logins = Prod. Demo-Seed legte a.graf@ mit Seed-PW an, a.sawall@ gar nicht -> Staging hatte andere Zugaenge als Prod. Fix: infra/scripts/sync-superadmins-prod-to-staging.sh (Prod read-only, upsertet NUR die 2 Superadmin-Zeilen per E-Mail, argon2-Hash sicher via SQL format(%L) statt Shell, Hash-md5-Verifikation Prod==Staging) als Step in deploy-staging.yml -> selbstheilend bei JEDEM Staging-Deploy (auch nach DB-Reset). Run 29906067572 gruen, beide Hashes identisch, Seed uebersprungen (10 User, Testdaten intakt), api-staging extern 200. Standalone-Dispatch-Workflow verworfen -> nicht registrierbar (s. gotchas workflow_dispatch).
- 2026-07-20 — botmatiq-mcp auf .NET 10 LTS gehoben (PR #25, ersetzt 7 Dependabot-Major-PRs):
  net10.0 in beiden csproj, EF/Design/InMemory 10.0.10, Npgsql-EF 10.0.3, Serilog.AspNetCore 10.0.0,
  Sinks Console 6.1.1/File 7.0.0, HealthChecks.NpgSql 9.0.0, JsonSchema.Net 9.3.0, Mvc.Testing 10.0.10,
  Test.Sdk 18.8.1, xunit 2.9.3/runner 3.1.5. System.Threading.RateLimiting-Referenz ENTFERNT
  (NU1510: ab net10 im Shared Framework). Docker: sdk/aspnet 10.0-noble (Debian existiert fuer
  .NET 10 nicht mehr; .NET 9 seit Mai 2026 EOL) + wget fuer Healthcheck nachinstalliert.
  CI komplett gruen, :main-Image auf GHCR. Deploy-Job repariert (self-hosted, /home/runner-Key,
  Host/User-Fallbacks — Secrets waren leer). BEFUND: mcp.botmatiq.com war NIE live —
  DNS zeigt auf die Website-Plattform (216.227.142.171, kein SSH), auf test.botmatiq.de
  existiert kein /opt/botmatiq; Envoy-503 seit jeher. Go-Live (Zielhost, compose, DB-Views,
  DNS) ist offene Produktentscheidung. KAI: .env.from-vault-Duplikat geloescht.
- 2026-07-20 — Automatisierungs-Audit ueber alle 34 Repos + 4 Server ("keine Fehler mehr"):
  20 disabled Workflow-Leichen geloescht (rissfest 11, vertriebsarchitekt 9). botmatiq-mcp
  CI seit 15.06. rot — 4 gestapelte Defekte: Test-Subclass gegen sealed DbContext (Fix:
  IModelCustomizer via ReplaceService, Shadow-Property VOR HasKey), trivy-action@0.24.0
  upstream geloescht (auf v0.36.0-SHA gepinnt), SARIF-Upload in privatem Repo ohne GHAS
  unmoeglich (entfernt, trivy bleibt exit-code-Gate), danach Pipeline gruen. Folgeeffekt
  behoben: 13 Dependabot-PRs per rebase gegen gefixten main — alle gruen; 4 Actions-PRs
  gemerged, 7 Major-PRs (dotnet-9-Images, nuget-Majors) bewusst offen fuer Andreas.
  frag-einen-v2 PR#41: Dependabot-Lockfile-Sync-Bug (npm ci "Missing from lock file") —
  Lock mit npm 10.8.2 --package-lock-only regeneriert, auf PR-Branch gepusht, gruen, gemerged.
  Server: KAI certbot-Unit Altzustand bereinigt (Probelauf exit 0); Hosting mdmonitor
  failed = echtes Loch (md-RAID1+5 vorhanden, [UUU] gesund) — gefixt, active; cpgreylistd
  (WHM-Feature disabled) sauber deaktiviert; Endstand alle 4 Server ohne failed units.
  linkedin-phase2 Catch-up-Timer 08:30 UTC deployt (Delivered-Marker + Skip-Guard) —
  Pipeline jetzt selbstheilend bei transienten API-Ausfaellen.
- 2026-07-20 — linkedin-phase2 (VA Linkedin Delivery) Ausfall repariert: 06:30-Run crashte
  im fact_validator an 529-Sturm (Opus ~30min+ ueberlastet, Sonnet lief parallel — Retry-Budget
  6 Versuche/164s zu klein, kein Fallback). Live-Stand /opt driftete vom Repo (resilient-Wrapper
  nie committed). Fix: Kreuz-Modell-Fallback (Validator Opus->Sonnet, Generator Sonnet->Opus)
  mit frischem 7er-Retry-Budget je Modell, TimeoutStartSec 600->1800, run_phase2.sh auf exec-tee
  (ERR-trap sah CURRENT_STEP nicht -> "FEHLER bei unknown") + PYTHONUNBUFFERED. Live-Stand
  gepatcht ins Repo linkedin-phase2 zurueckgefuehrt (Repo wieder Source of Truth), 20 .bak-Altlasten
  nach /root/linkedin-phase2-bak. Rerun 07:19: PASS, Post+Carousel 07:20 in Kanal geliefert.
- 2026-07-20 — Cert-Incident admin.tecmatiq.de (abgelaufen 19.07.): renewal conf stand
  als einzige auf authenticator=standalone -> Port-80-Bind-Fail seit ~19.06. Fix:
  certonly --webroot (gueltig bis 18.10.), deploy-hook reload-nginx.sh angelegt (fehlte
  serverweit). Folgebefund: 8x *.kingdom-hosting.de (u.a. cloud/Nextcloud) waeren 25.07.
  gefolgt — Port-80-Blocks return 301 ohne acme-Location -> LE 404; alle 8 gepatcht
  (acme-Location vor Redirect), Certs erneuert, Zombie ki-cloud geloescht, .acmebak nach
  /root/nginx-acmebak (sites-enabled laedt *!). Monitoring war 3-fach blind:
  daily-health disabled_manually -> reaktiviert; admin/vault+4 Domains fehlten in
  DOMAINS; SSL-Check erkannte expired nicht -> gefixt (unverified ctx + openssl,
  307/308 ok, ok_doms-Zaehlung konsistent). TG_TOKEN-Repo-Secret war 401 ->
  daily-health.yml zieht Telegram-Creds jetzt live aus Vault (Fallback Repo-Secret).
  Report 18/18 gruen, TG-Versand verifiziert. Runner gha-infra-monitoring-1 haengend ->
  docker restart via Nachbar-Container. 11 One-shots geloescht (inkl. Altlast
  oneshot-deploy-va-copilot).
- 2026-07-19 — Kernel-Reboot KAI+Botmatiq (6.8.0-134->136) per One-shot aus kingdom-ai: beide gruen (KAI 82->83 Container, nginx aktiv/caddy disabled, Vault+rissfest 200; Botmatiq 11/11, test.botmatiq.de 200). Befund: kingdom-ai.service Boot-Race (6 Fehlboots), kingdom-redis fehlte komplett -> wiederhergestellt, reset-failed, Gotcha dokumentiert. Botmatiq-IP in Doku auf 49.13.142.247 korrigiert (alt 5.9.112.153, DNS bestaetigt). One-shot geloescht.
- 2026-07-19 — tender-watch live auf KAI (09bda02): taeglicher Scan TED+Bekanntmachungsservice auf Steuerungs-/Retrofit-Ausschreibungen -> Telegram; Erstlauf 65 aktive Treffer (u.a. Ruhrwehr Raffelberg Frist 30.07., WW Hermentingen/Zollernalb, IWES Leuna). Recherche-Basis: TED-API-Expertsyntax + DOEE-OCDS-Exporte (503-throttled, Retry-Design). Units via deploy-timers.yml, manueller Trigger tender-watch-once.yml.
- 2026-07-16 — Kernkette LIVE auf Merseburg-IPC verifiziert: echte 10000014.auf ->
  Ingest -> Split auf 2 Behaelter (echte Artikelmasse!) -> 2 Batches -> COMPLETED ->
  .E01+.E02 (Behaelterfolge 1/2+2/2, Wannen 4711/4712, Teil- und Gesamtmengen korrekt)
  + AutoBelege. Drei Deploys dafuer noetig, drei neue Befunde gefixt: (a) Watchdog-Task
  killte robocopy (FEHLER 32) -> Apply v2 pausiert Task + trap + /LOG + Prozess-Wait;
  (b) Serilog + 7 weitere relative data/-Defaults schrieben nach System32 (Dienst-CWD)
  -> AppContext.BaseDirectory + shared:true; (c) appsettings.{tenant}.json ueberschrieb
  .env (AddJsonFile NACH AddEnvironmentVariables) -> Env-Re-Add, .env ist wieder
  hoechste Quelle (Montag-CloudSync-Toggle haette sonst nicht funktioniert). Ingest
  ueberlebt jetzt fehlenden Klinik-Share (Setup-Retry, Test 7). Deploy-Stand IPC:
  0.0.69 / 09515e2, Suite 1035/1035. Backup-Task installiert + Probe OK (BOM-Fix
  d0192f5: Backup-Skript war UTF-8 ohne BOM -> PS-5.1-Parser-Crash). Offen:
  AMOR-Gegentest (Split-Semantik!), Demo-Seeds vor SAT bereinigen,
  Werkstatt-.env-Override -> Schalter-Blatt. NACHMITTAG (autonom,
  Andreas abwesend): Positions-Storno O1 komplett (78fbffc): POST /handheld/skip
  + SkipItemAsync (Tx, PickDetail-Audit, FC-1-Rueckmeldung); Dispatcher-
  CANCELLED-Filter entfernt (haette beim Voll-Storno die Fehlmenge verschluckt,
  rot bewiesen); Batch/Order-done via Endzustands-Zaehlung; Tests Voll-Storno
  + Split-Mix, Suite 1037/1037, CI gruen. Doku STORNO_MINDERABGABE.md +
  IBN_UMSCHALTPUNKTE_MERSEBURG.md. Wrapper-Logpfad-Fix fd01317 (Wrapper
  aktualisiert sich NICHT uebers Bundle -> einmal manuell auf IPC kopieren).
  Handheld-Storno-UI wartet auf Felde-Antwort. Kein Deploy — Montag mit Andreas.
- 2026-07-16 — Actions-Storage zweiter Ueberlauf (7,51 GB / 2 GB) geloest, diesmal
  strukturell: Ursache war ci.yml Job 8 `artifacts` — pro main-Push ~230 MB
  (backend 206 self-contained + apk 17 + frontend 2), von keinem Workflow
  konsumiert (cd.yml = git pull, IPC-Wrapper = windows-publish per $ShaPrefix).
  Der 14.07.-Retention-Fix konnte das bei 10-15 Commits/Tag nicht halten.
  Fix (botmatiq a5bbc75): artifacts-Job nur noch workflow_dispatch mit
  publish_bundle=true; retention-days explizit in JEDEM Upload (1/3/5, trivy 14);
  NEU cleanup-artifacts.yml (Mo 05:00 UTC scharf, dispatch dry_run, schuetzt
  Tag-Builds + PROTECTED_RUN_IDS + juengstes je Namensklasse+Branch, paginiert,
  Retry). Danach 194 Artifacts / 6,47 GB per API geloescht (Invarianten-Check
  vorab: Deploy-Staende e0ff6da + 218606f-Fallback, handheld-apk 2878d62
  Wochenplan-Pin 21.07. alle in KEEP). Stand: 20 Artifacts / 1,04 GB.
  Offen fuer Andreas: Repo-Default-Retention 14d -> 7d (nur UI, keine API).
- 2026-07-16 — Kernkette Merseburg repariert (Befunde 1-5, Audit 15.07.): Commits
  db59472 (Backend) / dec9857 (Handheld-Uebernahme-Hinweis) / e0ff6da (Doku Befund 6
  = SAT-Pflichtpunkt Shuttle-Retain, wartet auf Servo). Verfahren: KernketteE2ETests
  erst 6/6 ROT gegen Bestand, dann Fixes, dann 6/6 gruen + Suite 1034/1034.
  ConfirmItemAsync zieht jetzt Auftrags-Welt transaktional mit (OrderItem PICKED,
  PickDetails, COMPLETED) -> Vision-Soll-Modell feuert real; AmorV6ReturnDispatcher
  + RetryService (Outbox PENDING/WRITTEN, Header-JSON am Auftrag persistiert,
  .E01 byte-geprueft gegen echte 10000014.auf); Ingest idempotent (Dedupe +
  Unique-Backstop, processed/ ueberschreibt Audit-Kopien nicht mehr);
  Batch-Uebernahme ohne OperatorId-Filter. windows-publish Run 29436629740 +
  android-publish Run 29437057795 gruen auf e0ff6da. Deploy-SHA: e0ff6da.
- 2026-07-15 — OpenAI-Kostenanalyse (Andreas: "15-20 EUR/Tag, fuer 3 Kunden zu viel").
  Befund: **easyArchitekt ist es nicht.** 2 STT-Calls/24h, 4,5 MB Audio/7d,
  gpt-4o-mini + whisper-1 (Defaults, in der .env wird kein Modell ueberschrieben)
  -> real ~0,02-0,05 USD/Tag. Alle AI-Pfade sind user-getriggert, kein Cron, der
  AiProcessor wird nirgends enqueued (toter Code). Anthropic gesamt via Admin-API:
  ~5 USD/Tag (7d), Peak 13.07. = 14,42 USD — nicht 1442, siehe Cent-Gotcha, den
  Fehlalarm habe ich selbst fast rausgeschickt. Auf KAI iptables-Accounting
  (Chain OAI_ACCT in DOCKER-USER, reine Zaehler) gesetzt: in 10 min 0 Bytes
  OpenAI-Traffic von allen Containern. Legacy /v1/usage als Messinstrument
  widerlegt (tot, siehe gotchas). OFFEN fuer Andreas: OpenAI-Admin-Key
  (sk-admin-, Scope api.usage.read) in Vault legen -> dann exakte Zuordnung
  ueber /v1/organization/costs. Nebenbefund ai-litellm (Einschaetzung zweimal korrigiert): oeffentlich
  erreichbar via `private.kingdom-hosting.de` (nginx -> 127.0.0.1:4000, ohne
  auth_basic/allowlist). Aber Auth haelt: LITELLM_MASTER_KEY gesetzt,
  /v1/*, /model/info, /credentials, /health alle 401. 7d Logs: 2387x 404
  (generische PHP-Scans), 0 erfolgreiche Fremdzugriffe auf LLM-Endpoints.
  Offen sind nur / (Swagger-UI), /openapi.json (1,2 MB), /sso/key/generate.
  Also NICHT akut kritisch — aber unnoetige Angriffsflaeche, weil `main-latest`
  ungepinnt laeuft und ANTHROPIC_API_KEY + OPENAI_API_KEY im Container haengen:
  ein Auth-Bypass-CVE reicht. Fix: allowlist/auth_basic im Vhost + NO_DOCS=true. diag-once.yml steht auf
  "Zaehler auslesen", nicht auf noop.
- 2026-07-15 — easyArchitekt KI-Diktat: unbekannte Firmen waren aus dem Review
  heraus nicht anlegbar. Das Dropdown kannte nur Stammdaten-Firmen, ohne
  companyId filterte apply() den Gewerk-Eintrag still weg — Andreas' Diktat
  verlor Eintraege ohne Fehlermeldung. Fix: CompanyQuickCreate-/
  ContactQuickCreate-Dialoge direkt im Review, "+ Neue Firma anlegen" in allen
  drei Firmen-Selects, Dubletten-Warnung, Auto-Zuweisung an alle Items mit
  demselben erkannten Namen. Nebenbefund beim Validieren: contactId/companyId
  gingen roh aus dem Body in BegehungPerson (create, addPerson, aiApply) —
  org-fremde Relationen waren setzbar, jetzt in assertPersonRefs() gebuendelt.
  Beides auf `staging` deployt (2 Runs gruen), main wartet auf Andreas' Freigabe.
  Nebenbei: `staging` hing hinter `main` (Blog fehlte) — main gemergt, damit der
  Zwilling wieder einer ist.
- 2026-07-15 — Hilti fliegt aus der LinkedIn-Kommentar-Engine. Ursache war nicht
  das Modell, sondern der Persona-Block in `va-comment-copilot/backend/main.py`
  ("langjaehrige Karriere bei Hilti") — das Modell nutzte den Namen folgerichtig
  als Credibility-Anchor. Die POST-Pipeline (linkedin-phase2) verbietet das seit
  jeher hart, die KOMMENTAR-Pipeline hatte die Regel nie bekommen: Regel-Drift
  zwischen Schwester-Repos, jetzt in gotchas.md. Fix dreistufig: Fakt anonymisiert,
  harte Prompt-Regel mit derselben Verbotsliste (Hilti, Q-Interline, ordermed,
  DigiPark, DVAG), plus deterministischer `enforce_no_employers()`-Guard (Regex ->
  Haiku-Rewrite -> harter Drop), weil ein fremder Post den Namen selbst nennen kann.
  validate_voice.py prueft mit. Push allein deployte nicht (deploy.yml dispatch-only
  + 0 Runner, beides in gotchas.md/infra.md) — Rollout per One-shot aus
  infra-monitoring, danach geloescht. Live gegen einen Hilti-nennenden Post
  verifiziert: 3/3 Entwuerfe sauber, Modell nutzt von selbst "bei einem grossen
  Werkzeughersteller". Eigener Fehler: `ssh -n` aus repo-backup.yml kopiert, ohne
  gotchas.md vorher zu lesen — der dort dokumentierte Heredoc-Trap, stiller Erfolg
  ohne Output. Offen fuer Andreas: Runner + Repo-Secrets fuer va-comment-copilot.
- 2026-07-14 — JetBackup-Verdacht geprueft: FEHLALARM, Backup ist gesund. Der alte
  mtime von backup/jetbackup (04.05.) war kein Signal — Incremental schreibt in
  bestehende snap-Slots, jetbackup.index + files*/ sind taeglich frisch (14.07.
  01:00-01:02), Job-Log meldet "Backup Completed" pro Account. Ich hatte das
  mtime-Argument selbst als schwach benannt und es trotzdem als Verdacht eskaliert
  — Lehre in gotchas.md. Nebenbefund: zwei Waisen-Verzeichnisse auf der Box von
  geloeschten Jobs (25.04./05.04.), nur Platz. Auch aufgefallen:
  kingdom-ai/diag-hosting-morning.yml prueft die Box mit verketteten Befehlen
  (ls; echo; ls) — das scheitert an der Restricted Shell, der Workflow liefert
  dort seit jeher nichts.
- 2026-07-14 — repo-backup von Actions-Storage auf Storage Box umgezogen. Ziel jetzt
  /mnt/storagebox-nc/repo-backups/YYYYMMDD/repo-backup.tar.gz (Schema wie db-backups),
  Retention 30d offsite + 7d Artifact als Griffbereitschaft. Keine neuen Credentials:
  Runner->Hosting deploy_ed25519, Hosting->Box vorhandener fstab-SSHFS. Live getestet:
  11/11 Repos, 28 MB, byte-identisch verifiziert. Absicherung gegen stille Fehler:
  tar -tzf lokal + mountpoint-Check + remote Groesse UND tar -tzf. OFFEN: 28 GB
  cpmove-Altlasten in /home/manual-backups (03.05.) koennen weg.
- 2026-07-14 — GitHub Actions Storage bei 90% (1,81/2 GB). Ursache NICHT die Runner:
  Storage != Minuten. 16,6 GB Artifacts gefunden, 274 geloescht -> 1,6 GB. Drei
  Ursachen gefixt: botmatiq/windows-publish (21 Dispatches x 390 MB x 30d = 8,0 GB;
  jetzt 5d + kein Artifact bei Tag-Builds), botmatiq/ci.yml artifacts-Job
  (205 MB/main-Commit x 30d = 5,2 GB, von cd.yml nie gelesen; jetzt 3d),
  infra-monitoring/repo-backup (Workspace-Leak + Glob-Bug + verschluckte
  Clone-Fehler, 90d -> 7d; Steady State waere >100 GB gewesen). Repo-Retention-
  Policy auf 14d in 10 Repos gesetzt. Minuten unauffaellig: 570/3000 hosted,
  1231 min frei auf gha-runner-01. OFFEN: Backups gehoeren nicht in Actions-
  Storage — Ziel Hosting/JetBackup oder Archivcloud entscheiden.
- 2026-07-11 — Repo-level rollout started: added per-repo CLAUDE.md to `rissfest`
  (verified against the real repo, not memory). Reference implementation of
  CLAUDE_TEMPLATE.md. Remaining active repos: botmatiq, frag-einen-v2, easyarchitekt,
  then vertriebsarchitekt, kingdom-ai, linkedin-phase2, sape-control-plane.
- 2026-07-11 — Added bootstrap.sh: one-command memory load + secrets-free auth
  health check. CLAUDE.md load-block now calls it; file set declared in 2 places only
  (index layout table + bootstrap FILES).
- 2026-07-11 — Restructured durable memory in asawall/.github from monolithic CLAUDE.md
  into index + regeln.md / infra.md / gotchas.md / worklog.md / runbooks.md +
  CLAUDE_TEMPLATE.md. Killed the second (drifted) `.github/CLAUDE.md`. Boundary set:
  native memory = top-of-mind only, Git files = authoritative.
- 2026-07-18 — Leadgen/Mail-Diagnose (Rissfest+easyArchitekt): Root causes: (1)
  approvals-poller tot seit 06.07. (Telegram 409 — AUTOSAPE-Bot hat Webhook auf
  n8n automation.vertriebsarchitekt.eu/webhook/tq-telegram-cmd; getUpdates damit
  unmöglich), (2) ea_mailserver down seit Docker-Restart 17.07. 04:06 (state- UND
  config-Bind-Mounts /opt/easyarchitekt/infra/mail/{state,config} geleert →
  Postfix-Symlinks tot, keine Accounts), (3) vertriebsarchitekt-outreach Cron-Key
  falsch seit 08.07. (nie getickt) — gefixt, (4) IP 46.224.164.200 bei t-online
  (DIAL) + Proofpoint geblockt, (5) post.frag-einen.com ohne DNS + fehlt in
  va-mail ALLOWED_SENDER_DOMAINS. Fixes: ea_mailserver recreatet (Image-Pin
  15.1.0, Host-Ports 25/465/587 raus — Konflikt mit rissfest-mail, rissfest-net
  in Compose persistiert), Account alexander.graf@ + 4 Aliase restauriert, IMAPS
  wieder ok; Compose-Fix in asawall/easyarchitekt committed (1d35e532).
  INCIDENT dabei: postqueue -f während ea_mailserver-DNS unauflösbar → 15
  gestaute Inbound-Mails (13.-18.07.) permanent gebounced (5.4.4) statt weiter
  deferred. Absenderliste extrahiert (u.a. sieckmannwalther.de,
  telluride-architektur.de). Rissfest-Machine selbst gesund (Sa = geplante
  Sendepause).
- 2026-07-18 (2) — Autonome Umsetzung nach Diagnose: MX post.frag-einen.com
  angelegt (Zone 823150; SPF/DMARC existierten, nur MX fehlte -> Ursache der
  450 "Domain not found"). post.frag-einen.com in va-mail
  /etc/postfix/allowed_senders + Compose-Env ergaenzt (allowlist_sender-Muster,
  KEIN Recreate). 98 approvte lead_candidates aus state.db in Outreach-DBs
  importiert (ea +27, ledgura +38, kingdomhosting +33, status=ready, Suppression
  beachtet) — Rest der 232 approved hatte keine Mail-Adresse. TICK_KEYs aller 5
  Outreach-Container rotiert (Env+Recreate+Cron, verify 200/401).
  deploy-timers.yml um leadgen erweitert (Units lagen schon im Repo, waren nur
  nicht verdrahtet). t-online-Freischaltungsentwurf + Proofpoint-Anleitung an
  Andreas (reCAPTCHA -> manuell). approvals-poller BEWUSST nicht gestartet:
  AUTOSAPE-Webhook zeigt auf aktiven n8n-Flow tq-telegram-cmd (POST 200) —
  Entscheidung neuer Bot vs. Webhook liegt bei Andreas; Dashboard-Approvals
  funktionieren unabhaengig.
- 2026-07-19 — Botmatiq Pre-IBN-Restarbeiten autonom: Vision-Bug-Trio
  (OnvifSnapshotClient Digest/Alias/Vendor) im Repo als bereits gefixt+getestet
  verifiziert (OnvifCredentialStore + DigestOnlyServer-Integrationstest) —
  Memory war stale. Einziger echter Code-Restpunkt umgesetzt: Multi-Band-
  Randfall Chargen-Verdikt (Capture Band 2 bestätigte Charge derselben Order
  auf Band 3). Fix d07e64c: vision_captures.BeltId nullable additiv
  (ddlStatements-Pfad), CaptureProcessor + reconcile/test setzen BeltId,
  ComputeAsync filtert bandscharf (null=Altbestand bandagnostisch),
  vision:capture-Payload +beltId, 5 neue Tests, Suite 1054/1054, Spec_Addendum.
  windows-publish Bundle mit Fix gebaut (botmatiq-backend-win-x64, Run
  29677885013) — liegt fuer Mo-Deploy bereit. Cloud-Ingest-Negativprobe:
  whoami/stats 401 ohne+mit Fake-Token, health public by design. Hinweis:
  Dependabot meldet 7 vulns (2 high) auf main — vor Feature-Freeze sichten.
- 2026-07-20 — Merseburg Mo-Vorzug: Deploy d07e64c + CloudSync live via RDP-Schritte
  (BeltId-Spalte verifiziert, Backup-Kette inkl. Cloud-Upload OK). 413-Vorfall
  Learn-Sync (22 Messungen > 8mb express-Limit) gefixt 3af5060: Pusher chunkt
  byte-basiert (MaxBatchBytes 4mb default, 413-Halbierung, Einzel-413-Skip gegen
  Kopf-Blockade), ingest.js Limit 64mb + JSON-Fehlerpfad. Suite 1058/1058.
  SuperAdmin-Deploy success, Cloud live. Gegenproben-Header ist
  x-license-sync-token (NICHT Bearer). Offen: Nightly-Task 02:30 ohne Logeintrag
  heute — schtasks-Check laeuft; Restore-Probe + Update-Pause als Bloecke geliefert.
- 2026-07-20 (2) — Tagesabschluss Merseburg Mo-Vorzug KOMPLETT: 0.0.75 (3af5060)
  live, Learn-Sync 23/23 synced (Chunking-Fix E2E verifiziert), PZN-Fragmentierung
  bereinigt (Canonical-Praefix-Fix 4e8cb6b + Cloud-Upsert pzn, Altmessung per
  SQL-Datei korrigiert + re-pusht, Cloud-stats sauber), Nightly-Task repariert
  (Conditions + Action-Quotes; Teststart gruen, 02:30-Beweis morgen), Restore-
  Probe BESTANDEN (58 Tabellen, BeltId, prod-Gegencheck 0), Update-Pause bis
  24.08. postgres-PW: Andreas-Entscheid KEINE Rotation, Chat-Exposure akzeptiert
  (localhost-only, gehaertetes Geraet); Vault POSTGRES_SUPER_MERSEBURG entspricht
  Ist-PW. Bundle 4e8cb6b bereit. Di: Bundle-Deploy (1 Wrapper-Befehl),
  Handheld-APK, Vision-Einlernen live (verifiziert PZN-Kanonik am Scan),
  02:30-Nightly-Kontrolle, UCG-WG Stufe 2 weiter offen.
- 2026-07-20 (3) — UCG-WG Stufe 2 ABGEBROCHEN + sauber RUECKGEBAUT: Network
  10.4.57 auf UCG-Ultra hat kein WG-Site-to-Site; der WG-VPN-Client terminiert
  (Handshake ok, LF/DNS-Import-Gotchas geloest), forwardet aber nicht — Diagnose
  eindeutig (Mac-traceroute Hop1 10.99.0.1 ok, Server-Route ok, UCG verwirft
  eingehend). Entscheid: 50er-Netz remote via IPC (24/7-Empfehlung), UCG via
  UniFi Remote Management; Guettel-Liste +HTTPS-outbound; Packliste v2 im Repo.
  Server bereinigt: UCG-Peer + 2 Leichen-Peers raus, 50er-Route weg,
  iptables-Duplikat weg, wg0.conf bereinigt (Backup .bak-2026-07-20), Endstand
  3 Peers (.2 Mac/.3 Alex/.10 IPC) verifiziert. Andreas-Resthandgriffe: Mac-
  AllowedIPs zurueck auf 10.99.0.0/24, UniFi-VPN-Client-Eintrag loeschen,
  Remote Management aktivieren. Alias-Korrektur dauerhaft: ssh botmatiq.
- 2026-07-20 (4) — KORREKTUR (Andreas): Alex ist NICHT am Botmatiq/Merseburg-
  Projekt beteiligt. Alle frueheren Alex-Bezuege (Field Engineer, WG-Peer
  10.99.0.3, alex-tecmatiq.conf) waren Fehlannahme — nicht reproduzieren.
  Peer 10.99.0.3 (nie ein Handshake) zur Entfernung vorgeschlagen.
- 2026-07-20 (5) — UCG Remote Management VERIFIZIERT: "Remote Access" (Control
  Plane > Console) war seit Setup aktiv, Konsole "Merseburg" erscheint im Site
  Manager (unifi.ui.com) und ist vom Mac ohne IPC erreichbar. Direct Remote
  Connection + SSH bewusst AUS. Klinik braucht dafuer TCP 443+8883 outbound
  (Packliste v3). Tag komplett abgeschlossen; offen nur Nightly-Kontrolle 21.07.

## 2026-07-20 — Botmatiq MCP: Go-Live test.botmatiq.de + Release v1.1.0 + IPC-Installer

**Go-Live (test.botmatiq.de):** botmatiq-mcp laeuft als Container `botmatiq-botmatiq-mcp-1`
(ghcr.io/asawall/botmatiq-mcp:main) im botmatiq-Stack (/mnt/data/botmatiq,
docker-compose.mcp.yml, beide Netze botmatiq-net+internal — db haengt nur in internal).
Caddy-Routen: `/mcp*` (JSON-RPC), `/mcp-healthz*` (rewrite -> /healthz, wildcard wegen
daily-health-trailing-slash), `/dl/*` (Download-Spiegel, Basic-Auth botmatiq). SQL-Bootstrap
v2 eingespielt: Rolle botmatiq_mcp (nur View-SELECT + audit-INSERT), mcp_audit_log, 6 Views
gegen das REALE v4-Schema mit PascalCase-quoted Spalten (pick_runs, pick_batches+OrderItems-Join,
article_stock+batch_tracking, compliance_protocols; AMOR-Views bewusst leer — kein Import-Log
in v4). Tenant-Slug auf test: `test` (aus tenant_settings). Secrets NUR auf Host:
`/mnt/data/botmatiq/.env.mcp` (DB-PW + BOTMATIQ_MCP_TENANT_TEST_KEY) und
`deploy/downloads/.credentials` (DL-Basic-Auth). Smoke: /mcp-healthz=200 Healthy,
tools/list extern ok. daily-health prueft jetzt `test.botmatiq.de/mcp-healthz`.

**Runner:** botmatiq-mcp hatte 0 self-hosted Runner (Runner sind pro Repo) — `gha-botmatiq-mcp-1`
als Sibling-Container auf gha-runner-01 registriert (generisches Klon-Muster, s. gotchas).

**CI/Release v1.1.0:** kompletter Zyklus gruen (test, trivy, build+push, win-x64-release,
mirror-to-test, ssh-deploy mit frischem GHCR-Login via job-scoped GITHUB_TOKEN — kein PAT
auf Hosts). GitHub-Release-Assets: win-x64-ZIP (58 MB, self-contained), .sha256, install.ps1,
latest.json; alles zusaetzlich im Spiegel https://test.botmatiq.de/dl/mcp/ inkl.
SqlViewsBootstrap.sql. Code: UseWindowsService + konfigurierbarer Serilog-Pfad
(On-Prem-IPC-faehig). install.ps1: Erstinstall/Update, SHA256-Check, Dienst BotmatiqMcp,
Config in Service-Registry-Env, API-Key-Autogenerierung am Geraet.

**Offen/Hinweise:** Merseburg/Gera-Rollout per install.ps1-Einzeiler (DB-Zugang lokal
noetig); mcp.botmatiq.com-DNS zeigt weiter auf Website-Plattform (Produktentscheidung);
Empfehlung: dediziertes read-only-GHCR-PAT rotieren statt breitem Zugriff.

