# worklog.md — last ~30 sessions in keywords

> Newest on top. One line per session: `YYYY-MM-DD — what changed`. Keep it terse.
> When it grows past ~30 lines, trim the oldest — this is a rolling window, not an
> archive. Deeper detail lives in the per-area files, not here.

- 2026-08-03 (7) — HOSTING-HAERTUNG Teil 2 (WebShield + MPM event + Worker/FPM), je mit Backup davor/danach
  + Offsite + Full-Verify aller 60 Domains + Auto-Rollback. Ergebnis: 0 Regressionen, alle Domains 200/301/403 wie Baseline.
  Backups: /root/ops-backups/pre-harden-20260803-195603 + post-harden-20260803-201918 (+ /mnt/storagebox-nc/ops-backups/*.tar.gz);
  Prefork-Rollback-Profil: /root/ops-backups/rollback-prefork-profile.json.
  (1) imunify360 WEBSHIELD.enable=true + WORDPRESS.waf_default=true + ai_bot_protection=true(balanced) -> Edge-Schutz aktiv.
  (2) Apache MPM prefork->event: `dnf -y install ea-apache24-mod_mpm_event ea-apache24-mod_cgid --allowerasing`
      (CloudLinux-Falle: mod_cgi verlangt mpm=forked -> mod_cgi MIT nach cgid tauschen!), dann rebuildhttpdconf + restart. Server MPM=event.
  (3) MaxRequestWorkers 150->400 via post_main_global.conf (<IfModule mpm_event_module>, cPanel hatte 150 uebernommen);
      FPM /var/cpanel/ApachePHPFPM/system_pool_defaults.yaml NEU (pm_max_requests:500, request_terminate_timeout:120s) -> php_fpm_config --rebuild, in 108 Pools aktiv.
  Endzustand: MPM=event, MaxRequestWorkers=400, Timeout/ProxyTimeout=60, reqtimeout+xmlrpc-deny aktiv, WEBSHIELD/WP-WAF/AI-Bot=on, FPM rtt=120s, ops-connlimit aktiv.

- 2026-08-03 (7) — HOSTING HAERTUNG 1/2/3 auf server.kingdom-hosting.de (88.99.195.89), jeder Schritt mit
  Backup davor+danach (Config + EA4-Profil; Offsite /mnt/storagebox-nc/ops-backups/{pre,post}-harden-*.tar.gz)
  und Vollverifikation ALLER 60 vhosts gegen baseline.tsv + Auto-Rollback -> 0 Regressionen in jedem Schritt:
  (1) imunify360 WEBSHIELD enable=true (war false -> Edge-DOS/graylist/CAPTCHA liefen nie) +
      WORDPRESS.waf_default=true + ai_bot_protection=true(balanced) via `imunify360-agent config update`.
  (2) MPM prefork->event: `dnf -y install ea-apache24-mod_mpm_event ea-apache24-mod_cgid --allowerasing`
      (event=threaded -> mod_cgi[forked] MUSS gegen mod_cgid[threaded] getauscht werden, sonst Konflikt
      "ea-apache24-mpm = forked"); dann `/scripts/rebuildhttpdconf` + `restartsrv_httpd`. `httpd -V`=event.
      Rollback: `dnf install ...mpm_prefork ...mod_cgi --allowerasing` + rebuild; Profil-Kopie
      /root/ops-backups/rollback-prefork-profile.json.
  (3) event MaxRequestWorkers 500 explizit gepinnt (ServerLimit 20 x ThreadsPerChild 25) im cPanel-Include
      pre_main_global.conf `<IfModule mpm_event_module>` (cPanel generierte KEINEN event-Block; lief auf
      Default ~400; /var/cpanel/conf/apache/local existiert nicht). FPM `/var/cpanel/ApachePHPFPM/
      system_pool_defaults.yaml` NEU: `request_terminate_timeout: 120s` + `pm_max_requests: 500`
      (pm/max_children unveraendert), `/scripts/php_fpm_config --rebuild`. Extern verifiziert: alle Domains
      200/301, easyconcerts 403 (Ausgangswert), xmlrpc 403, Server MPM=event. Zusammen mit (6) [Timeout 60,
      reqtimeout, xmlrpc-deny, connlimit] ist die Worker-Exhaustion strukturell abgestellt. CloudLinux-Swap-
      Details in gotchas.md.

- 2026-08-03 (7) — easyconcerts.de WEB deaktiviert (Andreas: "nichts Vernuenftiges", Mail offen).
  User=timo (WP-Install /home/timo/public_html, war Mit-Ziel des Floods). 403 NUR fuer Apex+www via
  GLOBALEM Admin-Include /etc/apache2/conf.d/includes/pre_virtualhost_global.conf:
  `<If "%{HTTP_HOST} =~ /^(www\.)?easyconcerts\.de(:\d+)?$/"> RedirectMatch 403
  ^/(?!\.well-known/acme-challenge/)`. ACME frei (Cert renewbar), mail.-Alias + Mail (Exim/Dovecot,
  4 MB, localdomain) UNBERUEHRT, Subdomains eventservice-stuhrmann/easy-entertainment/famstuhrmann +
  andere Sites unberuehrt. Verifiziert intern+extern 403. Rueckbau: <If>-Block aus dem Include
  entfernen + rebuildhttpdconf + restartsrv_httpd. GOTCHA: per-Domain-userdata-Includes werden auf
  dieser Box NICHT angewandt (s. gotchas.md) -> global mit <If Host> loesen.

- 2026-08-03 (6) — HOSTING-AUSFALL server.kingdom-hosting.de (88.99.195.89) behoben+gehaertet.
  Alarm CRIT planning-x.de + kingdom-hosting.de "HTTP no-response". Ursache NICHT Ressourcen
  (Load 1.3, 57G frei, kein OOM) und NICHT der zuerst aus dem error_log vermutete Self-Proxy
  (self-loop-Conns==0). Real: verteilter WP-Brute-Force/Exploit-Flood (Azure 20.x/4.x, 85.204.70.96;
  POST /xmlrpc.php 793x, /?rest_route=/batch/v1 945x, /wp-login.php 400x, /1.php-/8.php-Webshell-
  Probes) saettigt PHP-FPM-Pools (easyconcerts/christliches-fernsehen/livinggospel) -> Apache-
  Prefork-Worker blockieren beim FPM-Proxy bis `Timeout 300` -> alle 150 Worker dicht -> server-
  weiter Ausfall inkl. chkservds eigenem 127.0.0.1:80-Check. Ungebremst weil CSF NICHT installiert
  (Firewall=imunify360) UND imunify WEBSHIELD=false -> DOS/graylist/CAPTCHA greifen nicht am Rand.
  Beweis (additiv/reversibel): extern 80/443 droppen + httpd-Restart -> Loopback sofort 200 in 7ms.
  FIX+HAERTUNG (infra-monitoring One-shot -> gha-infra-monitoring-1 -> deploy_ed25519 -> root@Hosting):
  Apache `Timeout 300->60`+`ProxyTimeout 60` (pre_main_global.conf, Anti-Kaskade); `mod_reqtimeout`
  (Anti-Slowloris); `<Files xmlrpc.php> Require all denied` (pre_virtualhost_global.conf) -> 403 VOR
  FPM, killt Amplification; iptables connlimit >100/IP auf 80,443 boot-persistent
  (systemd ops-connlimit.service, /usr/local/sbin/ops-connlimit.sh) + 45.148.10.4 gedroppt; FPM+httpd
  restart. Verifiziert: alle Domains 200 extern, xmlrpc 403, httpd-Worker 15. One-shot-Workflows geloescht.
  OFFEN BEI ANDREAS (staerker als connlimit gegen verteilte Floods): imunify360 WEBSHIELD einschalten
  + WORDPRESS.waf_default=true + ai_bot_protection=true; optional MPM prefork->event +
  MaxRequestWorkers 150->256; FPM request_terminate_timeout (system_pool_defaults.yaml existiert
  NICHT -> anlegen oder per-Pool). Details/Reproduktion in gotchas.md.

- 2026-08-03 (5) — LAGERORTE FINAL (13:22, Beweis statt Annahme): Freitag-Kopie
  01.08.T00-30 (Nacht Fr->Sa, VOR Sa-Schaden) geladen und diagnostiziert:
  Fr-Endstand hatte 813 Lagerorte (nicht nur die 399 aus Juni-ARTFACH — am Fr
  wurde massiv nachgepflegt; Alprazolam Fr='007' statt Juni-'011'!). Fuellender
  Restore (COALESCE, Backup gewinnt wo gefuellt, nichts geleert, Belt/Slot
  unangetastet): live jetzt 902 mit Lagerort, nur 100 ohne (Liste als CSV fuer
  Poppitz: C:\Botmatiq\ops\lagerort-fehlend.csv — die hatten auch am Fr
  keinen). Poppitz-Beispiele exakt auf Fr-Werten: Amoxicillin 013/1.2,
  Aprepilor 017/1.2. Vision aktiv 103 (Poppitz lernt laufend ein). Lehre:
  Klinik-Egress braucht beim ERSTEN HTTPS-Connect oft 42s-Timeout -> alle
  IPC-curl-Aufrufe mit Retry-Schleife bauen.
- 2026-08-03 (4) — v4.0.10 LIVE auf IPC (10:52, ERGEBNIS OK): Schutz aktiv
  (CSV-Merge-Semantik, AllInOne-Import nur -WithImport, Slot 1-2 erzwungen,
  clear-all Confirm+Audit, /articles+/vision Operator+). Einlern-Merge lief
  idempotent: 0 zusammengefuehrt, 7 ohne Ziel = echte Nicht-AMOR-Testartikel
  (inkl. Duplikatpaar 1418925/PZN-01418925 — beide Platzhalter, kein echter
  Zielartikel; bewusst belassen). Sync push 22 Messungen + 90 Bilder (Poppitz-
  Wochenendarbeit in Cloud gesichert), Vision aktiv 21 (Poppitz lernt schon
  wieder ein). Stamm 820/770 mit Massen. IBN-Software-Themen damit rund;
  vor Ort offen: Not-Halt, Vision-Kalibrierung, V7, Haertung/PW-Rotation.
- 2026-08-03 (3) — FREITAGSTAND KOMPLETT WIEDERHERGESTELLT (10:47): Die Sa-02:30-
  Cloud-Kopie war nachweislich schon kaputt (restore3 bewies es: 819 geladen,
  Kennzahlen unveraendert) -> Schaden lag VOR Sa 02:30. Finale Loesung aus den
  ORIGINALQUELLEN statt Backup: (a) Band/Slot fuer 746 Artikel aus den
  'Uebergabe B.S'-Notes der Bundle-CSV generiert (Verteilung exakt Soll
  36/58/103/103/91/98/169/88, UPDATE 746); (b) Lagerorte aus ARTFACH.FCH
  (TestData im Repo) als SQL: 399 gesetzt (mehr als die alten 334 — AmorNr-
  Bruecke matcht vollstaendiger). Endstand: lagerort 399, slot_1_2 746,
  ungueltig 0, Alprazolam 011/1.1. Cloud-Route db-backup/download/:file
  ergaenzt (Tag deploy-superadmin-*). Neue Gotchas: psql-HINWEIS auf stderr
  sieht in PS rot aus, ist aber harmlos (DROP IF EXISTS); processed/ auf dem
  Share wird offenbar fremdbereinigt — Originaldateien im Repo-TestData sind
  die verlaessliche Rekonstruktionsquelle.
- 2026-08-03 (2) — FREITAGSTAND-VERLUST geklaert + v4.0.10 (037d084): Poppitz-
  Meldung (Lagerort weg, Slot wieder Schacht-Semantik B1/7). Root Cause: der
  v4.0.5-AllInOne-Lauf Sa 16:22 lief MIT CSV-Import; Bundle-CSV = Stand vor
  Freitag; ApplyRequest = Replace-Semantik -> Lagerorte 334->67, Belt/Slot alt,
  VisionEnabled+PZN2/3+ScanBarcode genullt (daher auch nur 8 Vision aktiv:
  Rest waren [Eingelernt]-Platzhalter). Meine 4.0.7-4.0.9 liefen -SkipImport.
  Restore: freitagstand-restore.ps1 aus pg_dump Sa 02:30 (Logistik 1:1,
  Vision/Bruecken fuellend/OR, Sanity Slot 1-2). Schutz 4.0.10: CSV-Import
  Merge-Semantik (MergeCsvIntoExisting), ValidateRequest Band 1-4/Slot 1-2,
  AllInOne-Import nur mit -WithImport, LearnedArticleMergeService+Endpoint+
  Button (Platzhalter->echte Artikel), /articles+/vision fuer Operator+,
  canEdit-Hack raus, Ladefehler!=leer. Suite 1215/1215. Leere-Artikelliste
  heute frueh war NUR abgelaufene Session (F5 reichte).
- 2026-08-03 — botmatiq v4.0.9 (6e30f99) + Artikelstamm-Rettung Merseburg:
  Artikelstamm zeigte 0 Artikel. Befund: ALLE Loesch-Pfade sind Soft-Deletes
  (IsActive=false), Liste filtert activeOnly -> Daten in DB, nur deaktiviert;
  UI-Button "Alle loeschen" (POST /articles/clear-all) hatte nur EIN confirm
  und KEIN Audit (nur LogWarning "Clear-All: ... by {User}"). Rettung per
  artikel-repair-Block: psql aus .env-ConnectionString, Fall A UPDATE
  IsActive=true WHERE UpdatedAt>=02.08. 12:00Z, Fall B pg_restore
  --data-only -t article_master aus C:\Botmatiq-backups (02.08.-Dump
  bevorzugt), Validierung DB+API. Haertung v4.0.9: clear-all Body-Confirm
  ALLE-DEAKTIVIEREN (Muster purge-history), UI zweistufig, Audit
  ARTICLE_DELETE/BULK_DELETE/CLEAR_ALL. Audit-Tabelle heisst audit_log
  (nicht audit_logs). Masse-Frage geklaert: Juni-Testexport hatte nur
  85/949 Zeilen mit L/B/H (Reader-Offsets [120,129) korrekt) — frischer
  AMOR-Komplettexport bringt die seit Juli gepflegten Masse.
- 2026-08-02 (2) — botmatiq v4.0.7+v4.0.8: AMOR-Ingest & Plaene sichtbar. v4.0.8
  (8b6da85): "Batch optimieren"-Befund (9x Auftrag 5, Behaelter 1-9 von 37, je 22
  Schachteln) war KEIN Composer-Bug: ~800 Schachteln Sollmenge auf 3 Positionen,
  Artikel ohne Masse -> Fallback 250ccm; BFL-Default nutzbar 5500ccm (33000x30%
  minus 4400 Fardelage) -> exakt 22/Wanne -> 37 Wannen; ESTIMATED/EXCEEDS-
  Warnungen wurden gespeichert aber nie angezeigt. Fix: GetPlanAnnotationsAsync,
  pick-runs-DTO additiv planWarnings+dimensionsEstimated, Warnbanner+Badge im UI.
  Suite 1202/1202. update407 lief (4.0.7 live, AmorV6 auf UNC) aber Purge brach
  am falschen Health-Check ab (/health existiert nicht, richtig: /api/v1/health/
  live bzw. EXE-VersionInfo) -> update408-Block holt Purge nach + Diagnose-Beleg.
  ERGEBNIS 18:02: v4.0.8 live auf IPC, Diagnose-Beleg exakt wie berechnet
  (Auftrag 5 = Zolpidem 100 + Ibuflam 500 + ASS 200 = 800 Schachteln, alle 3
  ohne Masse), Purge 115 Zeilen (5 Orders/42 Plaene/7 Laeufe/32 Slots),
  Historie 0. Merseburg-DB ist sauber fuer den Produktivstart.
  v4.0.7 (376f1e7): AMOR-Ingest sichtbar. Felde-Befund
  (Dateien Fr automatisch abgeholt, UI zeigte nichts): order:ingested via
  PlcStateStore.EmitOrderEvent (AmorV6Ingest+FolderWatcher, additiv) -> globaler
  Toast + Sofort-Refresh OrdersPage; Datum+Zeit in Historie-Spalten (war nur Zeit);
  OrderHistoryPurgeService + POST /orders/purge-history (Service/Admin, Confirm
  HISTORIE-LOESCHEN, Audit ORDER_PURGE, InMemory-Weiche RemoveRange) + roter
  UI-Button — loescht Bewegungsdaten inkl. PickBatch-Waisen, behaelt Audit/
  Artikelstamm/Einlern-Captures(OrderId=null). Suite 1194/1194, i18n DE/EN/FR.
  ACHTUNG Frontend: store/index.ts ist TOTER Zweitbestand — aktiv ist src/store.ts
  (App.tsx importiert './store'); Events dort verdrahten. Deploy: update407-Block
  (stats-Poll -> AllInOne -SkipImport! Bundle-CSV wuerde AMOR-Masse vom 31.07.
  manual ueberstempeln -> Health 4.0.7 -> Purge via Ops-Login -> Verify).

- 2026-07-31 (4) — ARTFACH-ROSETTA + Kamera-Befund: (a) Einlernbox komplett offline,
  Ursache HARDWARE: PoE-Switch in der Visionbox abgeraucht (Progression 08:09 zwei
  Cams -> 11:24 drei -> mittags alle sechs; X104 up, USW .2 pingbar). Ersatz:
  beliebiger unmanaged 8-Port-PoE+ (z.B. TL-SG1008P), Einbau KW33. (b) Band/Slot-
  Herkunft final geklaert via AMOR-SBKA-Maske (Andreas vor Ort): Lagerfachbereich
  UND Zusatz werden IN AMOR gepflegt; Zusatz = Uebergabe 'Band.Oeffnung' (Slot nur
  1-2). Export-Rosetta: '00110000' = [0,3) Bereich '001' + [3] konstant '1' + [4,8)
  Zusatz (im 08.06.-Export noch LEER — Apo pflegt seit Juli; Allopurinol Juni-Bereich
  011 -> heute 007 = Umpflege). CSV-'Uebergabe B.S'-Notes stammen aus AMOR-Report
  'Artikelmasse fuer Kommissionierer' (24.07.). Fix 0.0.97/634b1ff: Reader splittet
  ARTFACH (Lagerfachbereich/Zusatz), ShelfLocation lesbar wie Maske, Belt/Slot via
  ParseUebergabeZusatz (tolerant 1.1/1,1/11/1100; Tests, Suite 1190/1190). Interim-
  Block 12b AUSGEFUEHRT: 746 gesetzt (36/58/103/103/91/98/169/88 auf 1.1-4.2,
  73 NULL = AMOR-Neue+learn-station ohne Notes), Allopurinol+ACC beide 1/1; Gruppen-
  Ableitung verworfen (Juni-Bereiche teils umgepflegt). WICHTIGSTER OFFENER PUNKT:
  frischer AMOR-Komplettexport mit gepflegten Zusaetzen (Apo/Felde) -> danach ist
  die Kette AMOR->Botmatiq fuer Lagerort+Uebergabe vollautomatisch.

- 2026-07-31 (3) — KORREKTUR zu (2) + finaler Stand Nummernwelten: Eintrag (2) enthielt
  von mir faelschlich als Erfolg verbuchte Zahlen (der 0.0.94-Lauf endete real im
  Versions-Gate; "298 neu/651 akt." und AmorNrn 1004479/1004102 waren nie Realitaet).
  Tatsaechliche Kette: 0.0.94-Lauf-2 stempelte mangels Cleanup (psql-Inline-Quoting
  kaputt -> DELETE lief nie; seither ALLE psql-Aufrufe via -f Datei) die Duplikate
  (0 neu/949 akt.); 0.0.95 (3030d45) Lauf-Cache gegen datei-interne Wiederholungs-
  zeilen (ARTIKEL.ART fuehrt AmorNr mehrfach, ~400 distinct auf 949 Zeilen), Lauf
  ergab 396/553 aber Bruecke griff nicht: ArtikelbarcodePzn in ARTIKEL.ART dupliziert
  nur die AMOR-Nr — echte PZN/EAN kommen aus BARCODE.DAT (len8-PZNs/EAN13). 0.0.96
  (07401b6): BARCODE.DAT-Vorablesung als Map amorNr->Barcodes, Bruecke ueber alle
  Barcodes, PickPznFromBarcodes (Rohformat 7/8 Ziffern), Suite 1178/1178. Robocopy-
  exit-11-Zwischenfall (FEHLER 32 Core.exe trotz Kill+Watchdog-Pause+Recovery-Disable
  = nachlaufendes Handle/Defender) -> /R:20 /W:3 (ff8b756). ENDSTAND nach Cleanup+
  Re-Import auf 0.0.96: ARTIKEL 67 echte Neue + 882 aktualisiert (949 Zeilen),
  BARCODE 529, ARTFACH 402; admin-Bestand 746 mit 332 AmorNr/334 Lagerort/73 amor-
  Massen; Nullprobe 0, distinct 67/67. Fix-PZNs real: 17923772->AmorNr 34915,
  11350016->34440 (beide manual, Andreas-Handwerte); 00010808->14867. ARTFACH
  liefert Rohcodes (z.B. 00410000) als ShelfLocation — Anzeige-Mapping offen.
  NEU offen: Einlernbox-Kameras nach 0.0.96-Update nicht gefunden (Diagnose laeuft).

- 2026-07-31 (2) — ZWEI NUMMERNWELTEN geloest: Stammdaten-Erstimport (Testexport 08.06.)
  legte 949 Duplikate an — ARTIKEL.ART Spalte 1 ist die interne AMOR-Warenwirtschafts-
  nummer (1000441…), NICHT die PZN; echte PZN im Barcode-Feld (Pos 144), .auf-Positionen
  referenzieren die AMOR-Nr. Fix b0a3ad0 (Bundle 0.0.94, Suite 1173/1173):
  article_master.AmorArtikelnummer (additiv+Index) + Lookup-Kaskade AmorNr -> Barcode-
  Bruecke PZN/PZN2/PZN3 -> PZN-Formen (rueckwaertskompatibel Felde-Testdaten) in
  ARTIKEL/BARCODE/ARTFACH (Resolver internal, AmorStammLookupTests 11 Tests);
  OrderItems.PZN wird via AmorNr auf echte PZN aufgeloest (Handheld/Vision/Bilder
  positionsseitig intakt), AmorArtikelnummer bleibt roh fuer die Rueckmeldung.
  IPC: Update 0.0.94, 949 Duplikate geloescht (Filter amor-v6 + AmorArtikelnummer IS
  NULL), Re-Import: ARTIKEL 298 neu + 651 aktualisiert (=Brueckenzahl), BARCODE 396,
  ARTFACH 402 -> Altbestand traegt AmorNr (651/746) + Lagerorte (396) + 77x amor-Masse.
  Fix-PZNs: 17923772 AmorNr 1004479 bleibt manual (AMOR ohne Masse), 11350016 AmorNr
  1004102 jetzt amor 105x95x40 (identisch zur Handmessung — doktrin-korrekt).
  00010808 -> AmorNr 1001040, Lagerort 2.1. Offen: frische Stammdaten + Live-Testauftrag
  von Felde (Export ist vom 08.06.), formale Bestaetigung E01-Verbuchung 20.07.

- 2026-07-31 (1) — AMOR-Share Merseburg PRODUKTIV: Fehlerbild 86/67 = fehlende DOMAENE,
  Auth klinikum-merseburg.lan\svc_batchflow (Vault-PW korrekt, keine Rotation); DNS-FQDN
  cvb-app-12.klinikum-merseburg.lan -> 10.53.20.16 vorhanden, Kurzname weiter via hosts.
  Beyer-Rechte (Aendern) verifiziert (Anlegen+Listing+Loeschen), .env-Overrides Z25/26
  entfernt, Dienst-Log: DropFolder=UNC, keine Fehler. DATEIKUNDE: LIEF<nr>.dat = AMOR-
  AUSGABE (Lieferschein-Kopfsaetze 254B/Zeile, alle Zeilen identisch, keine Positionen)
  -> ignorieren, KEIN Scanner-Ausbau; Archiv/*.E0x.OLD<ts> = AMOR archiviert unsere
  Rueckmeldungen -> E01-Gegentest de facto bestanden (10000017.E01 20.07. 08:28 verarbeitet,
  LIEF 08:59 erzeugt). Testexport 08.06. (ARTIKEL/BARCODE/ARTFACH/CHARGE) liegt fuer
  Stammdaten-Erstimport bereit (Block geliefert: Kopie in Root -> Ingest -> Verify inkl.
  ShelfLocation/DimensionSource). UI-Fixes 30.07. spaet: MeasureSession immer sichtbar
  (Operator+, f734352) + Banner drei Zustaende statt ABGELEHNT (3a5628a), Bundle
  dispatched. Doku: Spec_Addendum_Amor_Share_Merseburg.md. Memory #12 ersetzt.

- 2026-07-30 (3) — AMOR-Austauschpfad Merseburg: Klinik-LAN blockt 443/GitHub; DNS
  fuer cvb-app-12 fehlt -> hosts 10.53.20.16 (+ hosts 10.99.0.1 admin.botmatiq.de fuer
  Cloud via WG). Share \\cvb-app-12\aescudata existiert (Fehler 67 war DNS/Credential),
  svc_batchflow-PW live-getestet + Admin/SYSTEM-Store Host+IP geseedet (Set-AmorShare-
  Mechanik inline, Read-Host MIT Echo gegen RDP-86er). batchflow = Drop-Box-Rechte:
  Anlegen ja, Listing/Loeschen nein -> Ingest braucht MODIFY (MoveToProcessed/ACK/E0x);
  Anforderung an Beyer/Guettel raus, verwaiste ~botmatiq-writetest-*.tmp dort loeschen
  lassen. Activate-AmorV6 lief (JSON=UNC, Neustart), Dienst blieb aber lokal: .env-
  Werkstatt-Override Z25/26 (Botmatiq__Amor__DropFolder/ReturnFolder) gewinnt ueber
  Tenant-JSON (Befund 16.07.). ReturnFolder-Default=DropFolder -> Umschalt-Block fertig
  (beide .env-Zeilen raus + Restart + Log-Check), gated hinter Rechte-Fix. IPC auf 0.0.91
  (Andreas-Parallelsession FieldCount); AllInOne-WARN service-Login = PW-Rotation anderes
  Thema. SMB-PW im Vault: SMB_BATCHFLOW_MERSEBURG /providers (Andreas via UI, per Read
  verifiziert). Web-PW-Recovery-Pfad: DB-Zugang aus .env + Set-BotmatiqPasswords.

- 2026-07-30 (2) — Doktrin-Umkehr Mass-Hoheit (botmatiq 4d19436/16a5a39/c6ccba8): AMOR
  absolut, Hierarchie amor>manual>vision (DimensionAuthority+Bestandsheuristik), Einlernen
  bricht nie ab (Bilder immer, Session-Commit ab 1 Auflage, Legacy-Pfad gleich), Lernpaare
  Ref*/RefSource + MeasurementBias (Median je Kante, Klemme ±3mm, ab 5 Paaren), Handmessung
  lengthMm/widthMm/heightMm am Commit + UI-Felder, Artikelstamm dimensionSource/
  referenceImageCount/hasReferenceImages + Einlernen-Button /vision?pzn=, manual-Stempel bei
  Massaenderung (PUT/POST/CSV/PATCH). Schema+Cloud-Wire additiv, Suite 1162/1162,
  Spec_Addendum_Dimension_Provenance. CI-FIX: rollup exakt 4.46.4 (resolutions) — 4.47+
  fordert GLIBC>=2.32, Runner hat 2.31; erster gruener CI seit dabb30c. IPC-DEPLOY 0.0.90:
  Klinik-LAN blockt 443/GitHub -> hosts-Eintrag 10.99.0.1 admin.botmatiq.de (WG-Tunnel),
  AllInOne -SkipImport; robocopy exit 9 = FEHLER 32 auf repo\plc\.vs (TcXaeShell-Index) ->
  Apply-Backup /XD .vs bundle-latest plc-refresh + /XF Bundle-ZIP (c6ccba8, IPC lokal
  gepatcht). DATENFIX SQL: 17923772=110x60x40/92g, 11350016=105x95x40/159g, source=manual
  (Bundle-CSV ist Quelle — processed leer, nie ARTIKEL.ART-Import gelaufen), Fehl-Messungen
  Accepted=f manual-reference + Ref-Lernpaare, SyncStatus pending. Legacy-Taster speichert
  nur R1-Bilder als DB-Zeilen (6 statt 18; alle Dateien vorhanden, CapturePathsJson). AMOR-
  Share: 445 offen, aber Fehler 67 (\\cvb-app-12\aescudata existiert nicht) + 53 bei net
  view — exakter UNC-Pfad von Beyer noetig. CD 16a5a39 success = Doktrin live in Cloud.
  ef89d48 = Andreas FieldCount-Fix aus Parallelsession (kein Konflikt).

- 2026-07-29 (2) — Merseburg SPS-Scharfschalt-Paket (botmatiq 6b7ae64): PDF-Vollabgleich
  gegen finales EPL23032026 (142 Bl.) — alle 80 GVL_IO-Adressen deckungsgleich Blatt 16/16.1.
  BEFUND-KORREKTUREN: Behaelterkette liegt in G8.0 NICHT G6.0 (falsche K-2-Kommentare in
  GVL/FB/IO_LISTE bereinigt; K-2 real offen, Entscheidungsvorlage Abgleich §6, Empfehlung
  SW-Stopp genuegt); MOVITRAC Ein->X12.2/Freigabe->X12.3 lt. Bl.4/5 (18.07.-Kommentar war
  vertauscht, Bench T3 prueft P60x); K-3 erledigt (H4/H5/H6-Hardware-Leuchten existieren);
  K-4 = 2-min-LED-Test (Plan zeigt A2.4, Draht D56 sagt A2.6). CODE: A-8 Quittier-Sequenz
  (Delay+Retry statt Einmal-Flanke, S3.0 = Quittiergeraet), A-9 + Bewegungssperre (Level),
  Vision_bSorterBeltStopped + 5 Diagnose-Knoten additiv, bVisionInstalled=TRUE (sonst
  DYNAMIC-Burst e9c953f nie aktiv — PERSISTENT-Falle: am IPC online setzen!),
  ConveyorControl-Startsperre, TcTTO Safety->Main->Motion, Task-Entscheid 1x10ms bleibt.
  NEU: docs/IBN_SPS_SCHARFSCHALTEN_MERSEBURG.md (V0-V7, pro Punkt XAE+Hardware-Verify,
  Abbruchkriterien) + deploy/scripts/Invoke-TwincatIbn.ps1 (Preflight/Build/Activate/
  IoPass-CSV/Status/Scharfschalten/Disarm via XAE-AI+ADS, PS5.1 ASCII+BOM). Konnektivitaet
  verifiziert: Mac-WG 10.99.0.2 -> IPC .10 ping 64ms, RDP offen, ADS 48898 zu (Skript
  laeuft lokal). NC-Achse bewusst NICHT im tsproj (Scan-Verify-Doktrin). Scharfschalten
  (Bootprojekt+Autostart) gated hinter V1-V6, morgen vor Ort mit Andreas. NACHTRAG:
  gefuehrter Tagesmodus -Phase Tag (T01-T19, resume-faehig ueber Reboot) + Phasen
  SetParams/K4Test/Watch; PRG_Interface: FB_WritePersistentData auf OPC-Kommando
  (System_bCmdWritePersistent) — CALIBs/bVisionInstalled sofort persistent.
- 2026-07-23 (8) — PROD-ROLLOUT durchgefuehrt (main 084a7f0, Tag release/2026-07-23). Deploy gruen, api.easyarchitekt.de/health ok, app + Marketing 200, alle neuen Endpunkte registriert (reports revise/translate, inspections start/items/notes/signatures/report/send, ai/handwriting, defects/reports). Verifikation per diff-prod-staging: Prod 44 Migrationen (vorher 41 + 3 neue), 672 Spalten identisch zu Staging, 0 Abweichungen. Sicherungspunkt pre-rollout-2026-07-23 (Prod 115K/61 Tab.) vorher erstellt. ROLLOUT-METHODE wegen getrennter Historien: Branch aus origin/main + datei-genau 113 Dateien aus staging uebernommen. KRITISCH: cookie-consent.tsx war auf BEIDEN geaendert — main hatte den domainweiten Ads-Consent-Cookie (Domain=.easyarchitekt.de), staging nur die Uebersetzungen. Staging-Fassung zu kopieren haette das Conversion-Tracking still zerstoert; stattdessen main-Fassung behalten und tr() daraufgesetzt. Zweiter Fund: use-org-role.ts existiert auf staging seit laengerem, fehlte auf main komplett (Typecheck deckte es auf). Zuvor: Handschrifterkennung (POST /ai/handwriting, Vision-Modell, Canvas mit Pointer-Events inkl. Pencil-Druck; erkannter Text wird NICHT direkt uebernommen sondern zur Kontrolle angezeigt).
- 2026-07-23 (7) — staging f317032 (Deploy gruen): Mobile + Restarbeiten. Versand friert das PDF jetzt ein (reports.generate setzte nur sentAt -> versendete Fassung war nicht reproduzierbar; jetzt lockedPdfKey/lockedReason SENT/contentSnapshot). Uebersetzungen dateiweise weiter: 336 -> 159 offen, Woerterbuecher 918/918 in 7 Sprachen. MOBILE: DataView startete immer als Tabelle -> unter 768px ohne gespeicherte Vorliebe Kartenansicht; iOS-Zoom-Bug behoben (Felder <16px lassen Safari beim Fokus zoomen -> 16px unter 768px); Dialoge nutzen volle Breite; Icon-Buttons 44px Mindestgroesse via button:has(>svg:only-child); Gantt startet mobil mit 10px statt 24px pro Tag.
- 2026-07-23 (6) — staging f19cd3d (Deploy gruen): Pruefungen ausgebaut. BEFUND: Es gab gar keine Detailseite — eine angelegte Pruefung liess sich nicht oeffnen. Neu: /inspections/[inspectionId] mit Checkliste (Punkte einzeln anlegen/abhaken/loeschen ueber neue Item-Endpunkte; NICHT ueber das bestehende PATCH mit items[], das alle Punkte loescht und neu anlegt -> Kommentarbezuege waeren weg), 'Pruefung jetzt starten' (Status IN_PROGRESS + startedAt), Kommentare je Punkt mit Phase (PREPARATION grau / INSPECTION gruen, Phase automatisch aus startedAt abgeleitet), KI-Diktat je Punkt. Danach: mehrere Unterschriften mit Unterzeichner-Auswahl aus Stammdaten (Contacts+Companies) ueber den bestehenden SignaturePadModal, sowie Pruefprotokoll-PDF (renderInspection -> MediaAsset) und Mailversand. Migration 20260723160000 (InspectionItem.checked/checkedAt/checkedById + Tabelle InspectionItemNote) handgeschrieben, additiv, idempotent, lokal gegen PG16 mit Funktionstest geprueft. Zuvor 2383f01: Menuepunkt Berichte entfernt, Maengellisten-Archiv unter Maengeln (GET /defects/reports), Zeitraum-Filter dateFrom/dateTo, Spalten Erstellt + Status geaendert aus DefectHistory.
- 2026-07-23 (5) — staging 7e246e7 (Deploy gruen): Berichte festgeschrieben + Fassungen + Uebersetzung auf Knopfdruck. BEFUND: renderPdf rendert bei JEDEM Abruf neu aus Live-Daten -> versendetes PDF war nicht reproduzierbar. Jetzt: /pdf = Ansicht (kein Lock), /download = Lock; beim Lock wird das PDF via media.uploadBuffer eingefroren (lockedPdfKey) und danach immer aus dem Objektspeicher ausgeliefert. POST /reports/:id/revise erzeugt neue Fassung (revision+1, supersedesId, revisedBy/revisedAt, Pflicht-Begruendung, changedFields aus Diff gegen contentSnapshot). POST /reports/:id/translate erzeugt eigenes Dokument (translatedFromId, locale) via ai.translateStructured — Original unveraendert, nichts wird automatisch uebersetzt. Revisionskopf + farbliche Hervorhebung zentral in pdf.service.injectRevisionBanner (nach Template-Kompilierung ins HTML injiziert -> gilt fuer alle Berichtsarten ohne .hbs-Aenderung). Migration 20260723120000 handgeschrieben, additiv, idempotent, lokal gegen PG16 geprueft; setzt bereits versendete Berichte rueckwirkend auf lockedAt=sentAt.
- 2026-07-23 (4) — staging 39d15c1 (Deploy gruen): Bauzeitenplan komplett. 'Ueberschrift'-Aktion legt SUMMARY-Vorgang an (vorher nur implizit durch Einruecken erzeugbar). Positionsspalte zeigt wbsCode (1 / 1.1 / 1.2) statt flacher sequenceNumber; laufende Nummer bleibt fuer Vorgaenger-Notation sichtbar. Neuer Endpoint POST schedule/tasks/:id/move (direction up|down ODER targetId+position before|after|child) mit Tiefensuche-Neunummerierung aller sequenceNumbers und Zyklusschutz. KORREKTUR einer frueheren Fehlaussage: gantt-drag.ts ist NICHT toter Code — es ist voll verdrahtet (useGanttDrag in GanttView, onPointerDownBar an Bars, Resize-Handles, handleBarMove -> PATCH). Mein damaliger grep hat den mehrzeiligen Import durch das eigene 'grep -v lib/gantt-drag' ausgeschlossen. Zuvor: KI-Diktat mehrsprachig (7c0a0c0).
- 2026-07-23 (3) — Sicherungspunkt vor Gantt-Umbau: Git-Tags backup/pre-gantt-2026-07-23 (main 68e70b5) + -staging (871d79f), DB-Dumps auf KAI unter /opt/backups/easyarchitekt/pre-gantt-2026-07-23/ (prod 115K/61 Tab., staging 32K/61 Tab., images.txt, RESTORE.txt), Skript infra/scripts/backup-db.sh prueft gzip+Groesse+Tabellenzahl. Gantt-Diagnose: Schema traegt alles (parentId, taskType SUMMARY, wbsCode, sortOrder) -> KEINE Migration noetig; Engine berechnet und persistiert wbsCode bereits; apps/web/src/lib/gantt-drag.ts ist ein fertiges Drag-System, wird aber NIRGENDS importiert (toter Code) -> deshalb kein Ziehen. Offen: wbsCode statt sequenceNumber anzeigen, Ueberschrift/SUMMARY anlegen, useGanttDrag verdrahten. Ausserdem staging e850d4b (Deploy gruen): Filter-Korrektur (Projekt als Chip statt Pill-Liste aller Projekte — Muster wie Aufgaben), Breiten aller Listenseiten auf space-y-4 vereinheitlicht, BIM-Filter, und Eigenschaften nachtraeglich bearbeitbar (PATCH /documents/:id + /bim-models/:id neu, Edit-Dialoge fuer Dokumente/Plaene/BIM). Wartet auf Prod-Freigabe.
- 2026-07-23 (2) — PROD-Freigabe umgesetzt: Gewerke-Fix live. main f7fe4ee (register() legt DEFAULT_TRADES an) -> Prod-Deploy 29993173785 gruen, api.easyarchitekt.de/api/health ok. Backfill in Prod ueber diag-once (ref=main, TARGET=prod): INSERT 0 128 -> alle Orgs haben jetzt Gewerke (hallo/landscap-ing/test je 0->32, sr-ing 3->35, manuelle Gewerke unangetastet). WICHTIG: main und staging haben KEINE gemeinsame Historie (no merge base) -> Merge unmoeglich, stattdessen Branch aus origin/main + gezielt Dateien per 'git checkout staging -- <paths>'. Ausserdem: Filter vereinheitlicht (staging 871d79f, Deploy gruen) — neue FilterBar-Komponente + useProjectFilter-Hook fuer Pruefungen (hatte keinen Filter), Begehungen (Filter war unsichtbar), Plaene (abweichende Optik), Dokumente (Projekt-Filter fehlte). Wartet auf Prod-Freigabe.
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

- 2026-07-20 (6) — Klinik-IT-Rueckmeldung (ACHTUNG: Kontakt heisst Jonathan
  BEYER, j.beyer@klinikum-saalekreis.de, 03461/27-1088 — NICHT Guettel):
  i219 = 10.42.0.1/24, GW 10.42.0.254, DNS 10.53.20.2/.3/.1, VLAN 420, NTP
  10.53.20.2, kein NAC, Ports C1-C2 + C19-C22, IBN-Kontakte Platzer+Beyer.
  UDP51820+TCP443-Freigaben bestaetigt. EINZIGER BLOCKER: SMB-Dienstkonto
  cvb-app-12 "in Einrichtung" — nachfassen bis 24.07. (+ Frage tagged/access
  VLAN + UCG 443/8883). Umsetzung: Set-KlinikLan.ps1/-WerkstattLan.ps1 im
  Bundle (windows-publish jetzt Wildcard), NICHT vorab scharf (Tunnel laeuft
  ueber i219), Vor-Ort-Schritt 1. NTP sofort konfiguriert (10.53.20.2 +
  pool-Fallback). Packliste v4.
- 2026-07-20 (7) — Beyer 2. Rueckmeldung: KLINIK-IT KOMPLETT, kein Blocker.
  SMB: cvb-app-12 = 10.53.20.16, Konto svc_batchflow (PW NICHT hier — Vault
  SMB_BATCHFLOW_MERSEBURG + via Set-AmorShareCredential.ps1 auf IPC in Admin-
  UND SYSTEM-Kontext, Dienst laeuft als SYSTEM auf Nicht-Domaenen-Geraet,
  cmdkey fuer Host+IP). SMB-Dialekte 2.0.2-3.1.1. VLAN 420 UNTAGGED an C1-C2
  -> Set-KlinikLan OHNE -VlanTag (Fallback bleibt). UCG 443+8883 zugesagt.
  Offen an Beyer: "Kennwort laeuft nicht ab" bestaetigen + Rotation nach IBN.
  Packliste v5 (ohne Klartext-PW). Neues Bundle dispatched.
- 2026-07-23 — Deploy 0.0.80 (d10bf13) sauber, Retention-Fix wirksam (nur
  Update-Ordner geraeumt). Set-AmorShareCredential ParserError: BOM-lose
  UTF-8-PS1 + Em-Dash (0x94=Quote) — Sofort-Fix per BOM-Einzeiler am IPC,
  Repo dauerhaft ASCII+utf-8-sig fuer alle drei neuen Skripte, Gotcha erfasst.
- 2026-07-23 (2) — SMB-Credential-Seeding VERIFIZIERT: SYSTEM-Store enthaelt
  cvb-app-12 + 10.53.20.16 (cmdkey /list via SYSTEM-Task), Admin-Kontext ok,
  Klartext-Tempdateien entfernt. Zwei Skript-Bugs unterwegs gefixt (BOM/ANSI
  + [regex]::Escape-Klammern, beide im Repo). Klinik-IT-Vorbereitung am IPC
  damit KOMPLETT: Deploy 0.0.80, LAN-Umschaltskripte, NTP, Credentials.
  Vor Ort netzseitig nur noch: Set-KlinikLan (ohne -VlanTag) -> Tunnel-Check
  -> Activate-AmorV6 (Pre-Flight-Schreibtest gegen Share).
- 2026-07-24 (2) — Einlernbox-Paket Punkte 1-7 KOMPLETT (4 Commits bis
  f262cd5, Suite 1099/1099, CI/CD gruen fuer 7dce282): (1) JPEG-Encoder-Fix
  — tote Reflexion (Mat-Ctor existiert in OpenCvSharp 4.13 nicht mehr) durch
  direktes Mat.FromPixelData+Cv2.ImEncode ersetzt (Muster Kalibrier-Vorschau,
  IPC-feldbewaehrt); .bgr-Bestand nativfrei lesbar (BgrRawFormat) — vorher
  Score 0 fuer alle Altbestaende; BgrMigrationWorker konvertiert Bestand beim
  Boot idempotent nach JPEG (alle 3 Tabellen, Datei-Loeschung erst nach
  DB-Commit, temp+rename). (2) SessionCommit loescht Dateien ersetzter
  Einlernbilder. (3) MinFillRatio 0.85. (4) Sicherheitszuschlag explizit
  (SafetyMargin L/W/H, Default 0/0/3mm) — Stamm=Messwert+Zuschlag, Rohmessung
  + angewandter Zuschlag persistiert. (5) Cloud-Sync Stufe 2: Einlernbilder
  einzeln als Multipart an /api/ingest/v1/learn-image (sha256, temp+rename,
  Upsert tenant/captureId/role, Ablage /mnt/data/botmatiq/learn-images,
  neues Compose-Volume — Server-Recreate noetig!), Outbox-Spalten additiv,
  Bestand synct einmalig komplett. (6) deploy/scripts/Set-VisionConfig.ps1:
  EIN gefuehrtes Skript (EdgeOffset 1.8/MinFill/Zuschlag + CloudSync-
  Scharfschaltung mit whoami-Test, Merge+.bak, ASCII+BOM, pwsh-geparst).
  (7) PZN-Namensquelle GEPRUEFT: gebrauchs.info = B2B-Vertrag hinter Login
  (NICHT frei), ABDA-Stamm kommerziell -> Artikelname als Operator-Eingabe
  beim Commit (?name=, Measure-Article.ps1 fragt ab), Master-Regel: echter
  AMOR-Name wird NIE ueberschrieben (LearnedArticleName + Tests). OFFEN:
  IPC-Update + Set-VisionConfig ausfuehren, Server-Recreate superadmin-api,
  Felde-Gegentest, Punkt 8 (Handheld CT37) eigene Session.
- 2026-07-24 (3) — Deploys VERIFIZIERT + Punkt 9 + Feature-Freeze: superadmin-
  Deploy Run 30080732955 gruen (Compose-Volume learn-images in Server-Compose
  Zeile 185, sa_learn_images-Schema angelegt, Health ok, whoami merseburg,
  learn-images/stats {"articles":[]}). Windows-Bundle Run 30080734124:
  botmatiq-backend-win-x64 391 MB, gueltig bis 29.07. — IPC-Update-Stand
  c778dba. Punkt 9 (Speicher): Einlernbestand nach JPEG-Fix ~2,4-9 MB/Artikel
  (vorher 176-265 MB .bgr) -> 500 Artikel = 1,2-4,5 GB, dauerhaft, jetzt via
  Stufe 2 OFFSITE (Einlern-Datensatz erstmals katastrophenfest).
  Betriebsbilder: Rotation 30d laeuft (ImageRotationWorker, Learn-Images
  ausgenommen); Formel Positionen/Tag x MB x 30 — echte Rate nach IBN-Woche 1
  aus vision_captures ablesen, ImageRetentionDays ggf. anpassen. RESTLUECKE:
  appsettings.merseburg.json (inkl. SyncToken) nur lokal+.bak — in Go-Review
  aufnehmen (Vault-Doku oder verschluesselte Kopie). FEATURE-FREEZE
  festgestellt: Punkt 8 (Handheld-Fuehrung CT37) NACH IBN (KW33+) —
  Measure-Article.ps1 fuehrt vor Ort bereits durch die Auflagen.
- 2026-07-24 (4) — IBN-Vorbereitung IPC ABGESCHLOSSEN (Repo d74c4fc):
  IPC laeuft 0.0.86, Migration 66 Dateien konvertiert, 612 Waisen/8,6 GB
  entfernt (frei 36,6 -> ~40 GB). Messkonfig EdgeOffset 1,8 / MinFill 0,85 /
  Zuschlag 0/0/3 aktiv. CloudSync scharf: 4 Messungen + 66 Bilder in der
  Cloud (17,9 MB, ~271 KB/Bild — JPEG-Fix bestaetigt, vorher waeren es
  970 MB gewesen). Sync-Token rotiert (alter Token stand im Chat), Datei +
  sa_licenses.slug='merseburg' synchron, whoami gruen. WICHTIG: .env trug
  Botmatiq__CloudSync__* — ENV schlaegt appsettings; Zeilen entfernt
  (.env.bak), Standortdatei ist jetzt einzige Wahrheit. NEU im Repo:
  claim-token-Route + issue-token-claim-Workflow (Token-Uebergabe an
  Anlagen ohne Abtippen), Run-BotmatiqUpdate.ps1 (Ein-Durchlauf-Update),
  update-bundle-Route + ship-update-bundle (Bundle-Download ohne
  GitHub-Zugang), Waisen-Cleanup im Worker (OrphanMinAgeHours 24).
  OFFEN vor SAT: PZN-Kanonisierung fuers Cloud-Merging (Altbestand mischt
  1418925 / PZN-01418925 / 01484543), Einlern-Gegentest mit neuer Messkette
  (Zuschlag + Namensvergabe) steht noch aus, Servo-Achsparameter-Vorlage
  (AM8122-0NH1 + PLE60 8:1 + ELM7221) — Beckhoff-Hardware noch nicht da,
  Parametrierung muss vorbereitet sein damit SAT-Zeit reicht.
- 2026-07-24 (5) — Nachmittag/Abend, IPC bereits verladen (Repo bfd7068):
  SERVO b0554a0: docs/SERVO_ACHSPARAMETER_MERSEBURG.md (NC-Parameter,
  Scan-Verify, Zweipunkt-Kalibrierung) + deploy/scripts/Prepare-ServoAxis.ps1;
  Hardware kam NICHT rechtzeitig und geht direkt nach Merseburg -> Woche wird
  servo-entkoppelt gefahren, siehe docs/IBN_KW31_ABLAUFPLAN_MERSEBURG.md.
  DEPS c8e8c69: Dependabot 14 -> 3 (HIGH weg; 3x moderate = react-router-v6
  ohne v6-Patch, dokumentiert akzeptiert, v7-Migration Post-IBN).
  SECURITY f2e34f7: Set-BotmatiqPasswords.ps1 rotiert alle 7 Seed-User direkt
  in der IPC-DB (BCrypt via Add-Type, Live-Login-Test); docs/SECURITY_VOR_
  KLINIKBETRIEB.md mit Passwort-Ablauf, appsettings-Vault-Sicherung,
  PAT-Runbook, Dependency-Restrisiken, IBN-Reihenfolge.
  PZN a49c0bd: Kanonisierung jetzt auch cloudseitig — pznCanonical (JS-Port
  von PznUtil.Canonical, 16/16) + SQL-Zwilling sa_pzn_canonical + idempotente
  Bestandsmigration im DDL; Deploy verifiziert 0 nicht-kanonische Zeilen,
  Otowaxol vereinigt (1418925 total=15), 01484543 -> 1484543. IPC-Seite war
  bereits sauber -> kein IPC-Update noetig, Feature-Freeze gehalten.
  BACKUP-BEFUND: letzter manueller Lauf vor Verladung meldete "Kein Sync-Token
  in .env - Backup bleibt lokal", Exit 0. URSACHE laut Worklog-Eintrag (4):
  die Botmatiq__CloudSync__*-Zeilen wurden bewusst aus der .env entfernt,
  appsettings.merseburg.json ist einzige Wahrheit — das Backup-Skript kannte
  nur die .env. Learn-Sync lief unbeeintraechtigt weiter (Eingang 13:14), nur
  der DB-Upload unterblieb seit 07:24. FIX fb96b50: Fallback-Kette (.env ->
  appsettings*.json -> secrets\cloud-sync.token) + Quelle im Log + neues
  Verify-CloudBackup.ps1 (Token-Quelle, whoami, Alter der juengsten Kopie,
  -SetToken als Notnagel). Behebung = reiner Skript-Transfer vor Ort.
  SERVER-ERHEBUNG (via SSH auf DEPLOY_HOST): IPC-Cloud-Backups vorhanden
  (juengste 24.07. 07:24, Retention greift). Server-eigenes Backup existiert
  (/opt/botmatiq-backup/backup.sh -> /mnt/data/backups/<ts>/pgdumpall.sql.gz),
  ABER mit Tagesluecken (18./21./23./24.07. da, 19./20./22.07. fehlen) und
  OHNE sichtbaren Trigger (weder root-Cron noch systemd-Timer) — OFFEN, vor
  Klinikbetrieb klaeren. /mnt/data/botmatiq IST ein Git-Checkout (frueherer
  Gegenbefund ueberholt). DB botmatiq 403 MB, superadmin 13 MB, /mnt/data 14%.
  IBN-PLANUNG: docs/IBN_KW31_ABLAUFPLAN_MERSEBURG.md neu — blockierte Punkte
  mit SAT-Relevanz (Bootprojekt+Autostart, Shuttle-Retain, DI/DO-Pass),
  servo-unabhaengiger Arbeitsvorrat (Folierung Mattschwarz + Vision-Kalibrierung
  sind der Wochenzweck), Tagesgeruest, Nachzieh-Block ~2,5-4 Tage,
  Terminrisiko: bei Lieferung Do/Fr passt die Servo-Kette NICHT mehr in KW31
  -> Zusatztermin KW33 Mo/Di vor SAT terminieren, solange Kalender frei ist.
  Packliste entsprechend angepasst (Servo aus der Mitnahme, Skript-Transfer-
  liste erweitert).
  OFFEN: Felde-Gegentest 10000017.E01; appsettings-B64 in den Vault
  (einzige Kopie des SyncTokens ausserhalb der Maschine); Server-Backup-Trigger
  + Luecken; PAT-Rotation.
- 2026-07-27 — IBN-Vorbereitung Abend: Freeze bewusst aufgehoben (Andreas-
  Entscheidung). Bundle 0.0.88 gebaut + ausgeliefert (Testsuite 1101/1101),
  enthaelt gegenueber 0.0.86: Gewicht-Import (de0b3e6), Servo-Vorlage im Code,
  Passwort-Rotation, Dependency-Fixes. NEU Invoke-BotmatiqAllInOne.ps1
  (948ddb3): EIN Befehl, der auf dem IPC alles macht — Sync-Token aus
  appsettings holen, neuestes Bundle aus der Cloud laden (update-bundle-Route,
  Header x-license-sync-token), entpacken (Deploy-Skripte + Artikelstamm-CSV
  reisen im Bundle mit), Run-BotmatiqUpdate.ps1 ausfuehren, 746 Artikel
  importieren (/api/v1/articles/import/csv, Multipart), Verify-CloudBackup.
  Selbstaktualisierend (spiegelt Skripte nach deploy\scripts\), idempotent.
  windows-publish nimmt jetzt deploy/data/ ins Bundle (CSV via git add -f, war
  durch data/-Regel geignored). CSV-Import las Weight_g vorher hart null trotz
  Persist-Faehigkeit -> behoben. Merseburg-Export = 845 Artikel, 746 mit
  vollstaendigen Maszen+Gewicht, 99 Nacharbeit (Blatt 'Masze fehlen').
  Datenhinweis: Masze als physische Packungsorientierung (Breite>Laenge bei
  109), Huellensolver muss orientierungstreu vergleichen. Erstlauf am IPC =
  kompletter Copy-Paste-Block (Skript liegt im Bundle, beim ersten Mal noch
  nicht auf dem IPC -> Henne-Ei), danach als Datei auf dem IPC.
  KABELLISTE (1ef8cbb): alle 8 Netzwerkstrecken im Plan als 1,5-m-Patchkabel,
  reale Wege 8-15 m -> 6 Strecken neu verlegen; W304 Servo 13 m konfektioniert
  (Weg messen); Plan-Widersprueche Aenderungsliste vs Schaltplan (ELM7221 vs
  EL7211, ZK4704 13m vs 10m, STO: Blatt 23 sagt KEIN STO an der Klemme,
  Stillsetzung ueber K8.0/K9.0). AM8122-0NH1 vs -0JH1 + ZB8103 vs ZB8110 beim
  Wareneingang pruefen.
  OFFEN unveraendert: Felde-Gegentest; appsettings-B64 in Vault; Server-Backup-
  Trigger+Luecken; PAT-Rotation.
- 2026-07-28 — easyArchitekt Bugfix aus dem Feld (Screenshot Alexander,
  Pruefung "Brandschutz-Begehung"): Pruefprotokoll-PDF brach mit
  'Missing helper: "inc"' ab. Ursache: inspection.hbs nutzt {{inc @index}},
  Helper war in pdf.service.ts nie registriert. Zweiter Fund: inspections.
  generateReport uebergab insp OHNE { inspection }-Wrapper -> haette nach
  Helper-Fix ein inhaltsleeres PDF ergeben. Fix cf39386: inc+phaseLabel-
  Helper, Wrapper korrigiert, Template ausgebaut (Teilnehmer-Klarnamen via
  zentrale Aufloesung im PdfService statt roher IDs — InspectionParticipant
  hat KEINE Prisma-Relation zu User/Contact; checked-Status mit von/am;
  Item-Kommentare im PDF: Vorbereitung grau / Termin gruen wie in der App;
  Titel "Pruefprotokoll" statt "Begehungsprotokoll"). reports.gatherData
  laedt notes+checkedBy fuer INSPECTION mit. Verifiziert: Typecheck lokal,
  Deploy-Restart 16:25Z beobachtet, E2E ueber eigenen Trial-Account
  (claude-e2e-test@planning-x.de, Org "E2E-Testorg (loeschen)") — PDF ok,
  Testdaten soft-geloescht, Account/Org besteht noch (kein Self-Delete-
  Endpoint; bei Gelegenheit hart loeschen wegen Trial-Metriken).
  GOTCHA Sandbox: api.github.com wird vom Cowork-Proxy geblockt ("add_repo"),
  git push/clone gehen aber -> CI-Status nicht lesbar, Verifikation ueber
  Live-Verhalten statt Actions-API.
- 2026-07-28 (2) — easyArchitekt Mail-System-Ausbau (ad892a7): Alle 4
  Berichts-Versandwege (Begehung Voll/Teil, Mangelprotokoll, Pruefprotokoll,
  Berichtswesen) auf SAMMELMAIL umgestellt (alle To sichtbar, CC/BCC ueberall,
  vorher Einzelmail-Schleifen). Absender: fromName='Vorname Name · Buero' +
  Reply-To=User-Mail; From-Adresse bleibt easyarchitekt.de (SPF/DKIM, Andreas
  wollte 'reale Absender' — Reply-To-Pattern erklaert+umgesetzt).
  MailSendLog: +empfaengerFeld TO/CC/BCC, +projectId, Enum +PRUEFPROTOKOLL
  +BERICHT; Inspections+Reports loggten vorher GAR NICHT, jetzt lueckenlos;
  Zeile pro Empfaenger, Sammelmail = gemeinsame smtpMessageId.
  Neu: send-logs-Endpoints je Quelle (inspections/defects/reports/daily-logs
  via Report-Join params.dailyLogId), /protocol-distribution/mail-history
  (+.csv, Filter Zeitraum/Art/Projekt/q/Status, Excel-DE BOM+Semikolon),
  source.csv je Bericht. Frontend: CcBccFields+MailHistoryCard+
  SendProtocolDialog (components/distribution), Historie-Cards auf 4 Detail-
  seiten, neue Seite /mail-historie + Nav. Migration additiv, laeuft im
  Container-CMD. E2E auf Prod verifiziert (Feld-Logging, SENT+messageId,
  Uebersicht, beide CSVs). Testmail an a.sawall ging raus (Absender-Demo).
  MERKE: example.com hat nullMX -> als Test-Empfaenger unbrauchbar, va-mail
  lehnt komplett ab wenn ALLE rcpt rejected. Zweite Test-Org angelegt
  (claude-e2e2@planning-x.de, 'E2E-Testorg-2 (loeschen)') — BEIDE Test-Orgs
  + claude-e2e-test@planning-x.de bei Gelegenheit hart loeschen.
  OFFEN/Idee: Partial-Reject (einzelne rcpt abgelehnt) markiert aktuell alle
  SENT; Bounce-Tracking (Status BOUNCED) waere naechster Ausbau.
- 2026-07-29 — easyArchitekt Support-Ausbau (Session-Trigger: Ticket-Mail von
  Isabell Piela nicht lesbar/Button fuehrte ins Dashboard). PROD-DEPLOYS:
  04c5c49 + 511d43b, alle verifiziert (Deploy+Post-E2E gruen).
  (1) Ticket-Mail-Fix: messagePreview (600c) in ticket-new-admin +
  ticket-reply-admin; Deep-Link: Login respektiert ?next= (nur relative
  Pfade), Admin-/App-Layout geben echten Pfad mit; Super-Admin-Navlink
  (/admin/tickets) fuer isSuperAdmin.
  (2) Passwort-Reset NEU (gab es nicht!): POST /auth/forgot-password +
  /auth/reset-password, 60-Min-Token (sha256-Hash am User, additive Migration
  20260729210000), kein Enumeration-Leak, alle RefreshTokens revoked; Seiten
  /forgot-password + /reset-password; Login-Link. E2E auf Staging komplett:
  Token 64c aus Mailpit, reset ok, Token-Reuse 401, Login neu ok/alt abgelehnt.
  (3) KI-Ticket-Triage (SUPPORT_AI_REPLY_ENABLED, Compose-Default true in
  Prod+Staging): AiService.supportTriage klassifiziert gegen kuratierte KB
  (apps/api/src/templates/support-kb.de.md); How-to+confidence>=0.75 →
  Auto-Antwort als Thread-Message vom System-User assistent@easyarchitekt.de
  (isSuperAdmin=t fuer Support-Styling, isActive=f gegen Login/Admin-Mails)
  + Kundenmail + waiting_customer; sonst Eingangsbestaetigung
  (ticket-received.hbs) + INTERNE KI-Notiz mit Zusammenfassung. E2E: How-to-
  Ticket korrekt auto-beantwortet (inhaltlich richtig), Billing-Ticket korrekt
  eskaliert. Nur bei create, nie bei Replies; Fehler brechen Flow nie.
  (4) Vorlagen bei Pruefungen nutzbar gemacht: Dropdown im Neue-Pruefung-
  Dialog (befuellt Pruefpunkte aus schema.items), Server-Fallback
  instanziiert org-scoped. Isabellas Frage traf echte Luecke (Vorlagen waren
  erstellbar, aber nirgends auswaehlbar).
  DIAGNOSE Piela: User seit 10.07. intakt (ORG_ADMIN, 32 Trades, pro/trialing
  bis 09.08.); "Fehler bei Konto-Erstellung" 19 Tage alt, aus Logs nicht mehr
  rekonstruierbar. 2 Templates "Oekologische Baubegleitung" (INSPECTION).
  INFRA: diag-once.yml jetzt parametrisierbar (workflow_dispatch input
  "script", SSH auf KAI, read-only-Konvention), nach Session auf Noop zurueck.
  Staging-Infra-Dateien von staging-Branch nach main uebernommen (siehe
  gotchas). Test-Account Staging: claude-e2e-ticket@planning-x.de
  (Passwort nach E2E: NeuesPw!2026e2e), 2 Test-Tickets auf Staging-DB.
  OFFEN: Alex ueber KI-Auto-Antwort informieren (live in Prod!); Antwort an
  Piela kann raus (Features live); KB pflegen wenn Features dazukommen;
  ticket-reply-admin bekommt kein messagePreview-E2E (Codepfad symmetrisch,
  typechecked); Assistent-User entsteht in Prod lazy beim ersten Ticket.

2026-07-30 (Session 2, IBN vor Ort) BOTMATIQ ANLAGENKONFIG MERSEBURG:
  BEFUND: Anlagenkonfig war 5 Stores / 7 UI-Seiten ohne Kopplung;
  /plant doppelt geroutet (Konsistenzreport unerreichbar); 3 Seed-Pfade
  (AuthService FlapCount=BeltCount-Bug, ServiceController Werkstatt-Default,
  Wizard-Versionen); Wizard ohne StellplatzCount, Defaults 8/4; SimMode
  DB-Feld kosmetisch (Laufzeit=appsettings). IST-DB: 2 gleichzeitig aktive
  plant_configs (system+seed, beide FlapCount=4, PlcHost 192.168.1.10,
  SimMode t), belt_slot_config+transfer_openings LEER.
  BEREINIGT (Block 2d, Backup C:\Botmatiq\backup\cfg-vor-bereinigung-
  20260730-221800.dump): genau 1 aktive Config "Merseburg CvB
  Zentralapotheke" (4 Baender/9 Stellplaetze/100 Wannen/Achse 5800mm/
  FlapCount 1/OperatorLanes 4/127.0.0.1:4840/SimMode f), 4x
  belt_slot_config FieldCount=4, 8 transfer_openings (x.1=F1, x.2=F4,
  per Foto+Zaehlung vor Ort). Konsistenzpruefung 5x OK, Dienst-Neustart
  mit Watchdog-Pause, Health gruen.
  CONNSTRING-LEKTION: operative Quelle ist C:\Botmatiq\.env
  (ConnectionStrings__Default) — appsettings-Klartexte sind Altbestand mit
  rotiertem Passwort; bei ENC: Vault POSTGRES_SUPER_MERSEBURG (Muster
  Set-BotmatiqPasswords.ps1/Backup-Botmatiq-DB.ps1). PS5.1: EAP=Stop +
  native stderr toetet Skripte — native Calls via cmd /c kapseln.
  COMMITS: 02e907c UI-Konsolidierung /plant-config (Tabs Stamm/Baender/
  Oeffnungen/Netzwerk/Konsistenz, Alt-Routen redirecten, Nav SYSTEM 6->1,
  Seed FlapCount:=1, Wizard StellplatzCount+Defaults), 2c289bd ToteCount-
  Grenze 500, dabb30c package-lock-Revert (Sandbox-Lockfile brach Runner-
  GLIBC; parallele Session pinnte rollup 4.46.4 in 16a5a39), <neu>
  fix(belt-config) FieldCount API/UI pflegbar (PUT nahm FieldCount nie an,
  Baender-Seite kannte es nicht — Mitursache leerer belt_slot_config).
  OFFEN: Bundle-Update auf IPC einspielen (Apply-Botmatiq-Update, neuester
  Run nach FieldCount-Fix); android-ui-test Runner braucht libX11
  (Emulator bootet nicht, unabhaengig von Commits); InstallationWizard-
  Datei-Store (PLC-Daten doppelt) konsolidieren nach IBN.
  NACHTRAG 23:10: Bundle 0.0.91 (Publish-Run 91/ef89d48, Ship-Run 8) via
  Invoke-BotmatiqAllInOne auf IPC eingespielt — Version verifiziert,
  Schutzdateien (.env/.lic/appsettings.merseburg) unveraendert, Backup
  botmatiq-pre-update-20260730-230815, AMOR-V6-Startsignal ok, CloudSync
  pushed 2/0 offen, Off-Site-Kette ok. Konsolidierte Anlagenkonfig-UI +
  FieldCount-Fix damit live in Merseburg. WARN: AllInOne-API-Login mit
  Seed service/botmatiq scheitert (Go-Review-Rotation 24.07.) -> Artikel-
  stamm-Import uebersprungen (Abschlusstext "importiert" irrefuehrend);
  pruefen ob 746 Artikel aus frueherem Lauf vorhanden, sonst Import mit
  rotiertem Login nachholen. AllInOne-Todo: Login konfigurierbar machen.
2026-08-01 (Session 2) BOTMATIQ SOFTWARE-SPUR:
  VISION-FREEZE (Andreas-Vorgabe, VERBINDLICH): Kein Umbau an Vision
  Backend/Frontend und keine Vision-Datenbereinigung, bis die Apotheke
  in KW32 ALLE Artikel eingelernt hat (Prozess: Mitarbeiter kontrollieren
  in der Artikeldatenbank haendisch Masse/Lagerort/Band+Oeffnung, dann
  Einlernen je Medikament -> Referenzfotos). Lactulose-Altwert erst danach.
  DATENGRUNDLAGE VERIFIZIERT: LearnSyncPusher schiebt learn_measurements
  (Masse) UND article_learn_images (Multipart) automatisch in die Cloud
  (/api/ingest/v1/learn-measurements, IncludeImages=true, 1000/Run);
  manuelle Masse via Provenienz amor>manual>vision geschuetzt (4d19436).
  -> AUFTRAG KW32 (cloud-seitig, ohne IPC-Eingriff): Mass-Extraktions-
  modell aus ~745 (Bild,Referenzmass)-Paaren; Regression/Bias je Form-
  klasse + LOO-Validierung, danach ML-Regressor; Hoehe bleibt schwach
  konditioniert -> Modell liefert Korrektur+Konfidenz auf Hull-Basis.
  Rollout erst NACH Einlernende als normales Bundle.
  BLOCK A MERSEBURG: Ops-Login in .env ergaenzt; Artikelstamm 819 gesamt/
  399 AmorNr/746 mit Uebergabe; KONSISTENZ 8/8 OK (alle TransferBelt.Slot
  == aktive transfer_openings 1.1-4.2); appsettings.merseburg aktuell==.bak
  (Merge hat nichts weiter beschaedigt; Pin-Ausfall kam von ersetzter
  Base-appsettings -> durch .env-Pin + [6b/9]-Verify abgedeckt).
  BARCODE FELDE (Ibuflam/34673): Code128 PZN 08533836 verarbeitbar
  (PznUtil.Canonical strippt fuehrende Nullen einheitlich); PDF-Textlayer
  taeuschte 'nicht gerendert' vor — Screenshot zeigt gerenderten Code,
  Draft korrigiert. Publish fuer 7eaf8da dispatcht (Login-Fix im Bundle);
  AllInOne-Laeufe erst nach Versionsmeldung.
  NACHTRAG PZN-BEFUND (01.08.): Felde-Testbarcode 08533836 = IBU 600
  1A Pharma 100 St (Web-verifiziert) — Stamm fuehrt fuer AMOR-Nr 34673
  die Lichtenstein-PZNs 06313409/06313415 (PZN2=Dublette von PZN),
  08533836 nirgends im Stamm. Ursache: Lieferantenwechsel ohne
  BARCODE.DAT-Nachpflege. Scan wuerde NotInAmor-Neuartikel anlegen
  (Design faengt das ab, naechster Import entflaggt). -> Mail an Felde:
  Zuordnung 34673<->08533836 in AMOR pflegen; generell vor Einlern-Start
  (KW32) die im Haus liegenden Packungs-PZNs je Artikel verknuepfen.
  Scan-Pfad verifiziert robust: ResolveArticleAsync matcht LookupForms
  gegen PZN/PZN2/PZN3/ScanBarcode. B64-Sicherung erzeugt (Vault-Upload
  durch Andreas: APPSETTINGS_MERSEBURG_B64). Bundle 0.0.98 (7eaf8da,
  Publish Run 98) in Arbeit — AllInOne freigegeben sobald Liste 0.0.98
  zeigt.
  ABNAHME 01.08. 17:4x: IPC laeuft bestaetigt auf 0.0.98.0 (FileVersion-
  Check). Ship-15-Log verifiziert Serverbestand 0.0.96/0.0.97/0.0.98
  (Retention ok); D2-Lauf nutzte die 0.0.98-Skripte ([6b/9] lief:
  TenantSlug merseburg, ServicePin, SyncToken OK). SOFTWARE-SPUR FUER
  KW32 ABGESCHLOSSEN: Anlagenkonfig konsistent, UI konsolidiert,
  Update-Pipeline gehaertet, AMOR-Nachtimport + Oeffnungs-Konsistenz
  verifiziert, Scan-Pfad einlern-robust, Learn-Sync (Masse+Bilder)
  aktiv. OFFEN BEI ANDREAS: Felde-Mail senden (34673<->08533836 vor
  Montag), Vault-Upload APPSETTINGS_MERSEBURG_B64. CLAUDE KW32:
  Cloud-seitiges Mass-Extraktionsmodell auf learn_measurements +
  article_learn_images (kein IPC-/Vision-Eingriff, Freeze gilt).
  LEARN-NIGHTLY EINGERICHTET (01.08. 18:30): Workflow learn-model-nightly
  (Cron 03:15 UTC + dispatch, Commit 32b2c5f) kopiert deploy/learn-model/
  nightly.sh auf den Cloud-Server und fuehrt aus: Discovery aller Learn-
  Tabellen (alle PG-Container) + Learn-Bildordner unter /mnt/data/botmatiq,
  Zaehlung gesamt/heute, Spaltenlisten, Report nach learn-model/reports/
  YYYY-MM-DD.md (+latest.md), Telegram-Kurzmeldung. ERSTLAUF GRUEN
  (Report 2026-08-01.md, Telegram gesendet). Claude-Sessions laufen NICHT
  selbsttaetig -> Automatik liegt bewusst im Cron; v2 (Bias-Fit + LOO auf
  den im Report sichtbaren Tabellen) wird per Commit nachgeschaerft, wenn
  Andreas die naechste Session startet. Kein IPC-/Vision-Eingriff.
  REMINDER EINGERICHTET: Workflow reminder-modellarbeit (Cron 13:00 UTC
  am 07.08., ubuntu-latest, Datums-Guard 2026) sendet Fr 07.08. ~15:00
  die Telegram-Erinnerung "Modellarbeit durchziehen" (v2 Bias-Fit+LOO).
  TODO nach 07.08.: Workflow-Datei entfernen (erledigt Claude in der
  Modellarbeits-Session).

## 2026-08-03 (Nachmittag) — v4.0.11: BARCODE.DAT-Härtung + Demo-Block raus aus Livebetrieb

**Kontext:** Produktiv-Export Felde 03.08. lief bis auf BARCODE.DAT durch (2× `[ERR] Stammdaten-Verarbeitung fehlgeschlagen: BARCODE.DAT`, 13:15:45 + 13:23:54, Ganzdatei nach `C:\Botmatiq\data\amor\error`). Ursache verifiziert: Barcode-Feld in BARCODE.DAT ist 30 Byte (HIBC/GTIN/Lieferanten-Nr.), `article_master.PZN2/PZN3` waren `varchar(20)` → DbUpdateException beim Sammel-Save → Datei-Level-Catch schob alles nach error/.

**v4.0.11 (Tag fddd838):**
- PZN2/PZN3 MaxLength 20→64 + additives Widening-DDL in Program.cs (läuft idempotent bei jedem Start)
- BARCODE.DAT-Branch zeilentolerant: Überlängen-Guard (`BarcodeColumnWidth=64`, internal const) je Zeile + DbUpdateException-Fallback rettet zeilenweise (Detach + Einzel-Save, defekte Entities benannt geloggt)
- OrdersPage: Demo-Auftrag-Block nur noch bei `system.simMode===true` (Merseburg mit echter SPS: weg; test.botmatiq.de: bleibt). Historie-Purge an eigenem `canPurge` (Rolle admin/service, auch live)
- Tests: AmorBarcodeToleranceTests (Spaltenbreiten-Kontrakt per Reflection + Datei-Durchstich mit 25/30-Zeichen-Barcodes) — Suite 1218/1218 grün
- update411-Block: wartet auf Bundle, prüft varchar(64) via information_schema, legt jüngste `*_BARCODE.DAT` aus error/ zurück in den Transfer, validiert pzn2/pzn3-Füllstand + `length()>20`-Beleg

**Stolperer beim Push:** Dependabot-Commit (rollup-Bump #62) kam zwischen Fetch und Push auf main → erster Push schob nur den Tag (auf den späteren Orphan a5745ae), main rejected. Rebase + `git push -f origin v4.0.11` → main und Tag konsistent auf fddd838. Zwei CI-Läufe für 4.0.11 möglich (Tag 2× gepusht) — letzter Bundle-Writer gewinnt, Inhalt identisch bis auf rollup-Version.

**Mengen-Check Auftrag 10000019:** 620 Schachteln = 20+500+100, Parser validiert Kopfsumme; 23 Behälter bei realen AMOR-Maßen plausibel (~27/Behälter); Mirta TAD 15mg Sollmenge 500 fachlich auffällig → Rückfrage an Felde empfohlen. EXCEEDS_STELLPLAETZE-Banner (23>9) korrekt.

**Offen:** produktiv-check-Block hat zwei Schönheitsfehler für künftige Kopien: `p."ItemsJson" LIKE` braucht `::text`-Cast (jsonb), und error/-Check muss auf `C:\Botmatiq\data\amor\error` zeigen (nicht `$drop\error`).

**Rollout-Ergebnis update411 (15:44–15:52):** v4.0.11 live, varchar(64) bestätigt. Re-Ingest der error/-BARCODE.DAT: 1.247 Zeilen gelesen, 700 Zusatz-Barcodes übernommen (PZN2 396→919, PZN3 137→314 — 523+177=700, exakt konsistent), error/ leer. Ursachen-Beleg: genau 1 Barcode >20 Zeichen im Bestand — diese eine Zeile riss vor dem Fix jedes Mal die ganze Datei. Kein Überlängen-Guard und kein Rescue-Fallback nötig (64 deckt alle 30-Byte-Barcodes).

## 2026-08-04 — Behälterprofil Merseburg: echte Bito-MB-Maße

Poppitz lieferte die Innenmaße der Mehrwegbehälter (Bito MB, konisch: unten 495×325, oben 540×365, befüllbare Höhe 245). Per API-Block (`behaelter-bito-block.ps1`, PUT container-profiles) ins Default-Versandprofil gesetzt: Rechenmaß Mittelwert 517,5×345×245 (Quader-Modell, Abw. zum exakten Konus-/Obeliskvolumen 0,08%), Füllgrad von 30% auf **22,633%** kalibriert, damit das bewährte BFL-Nutzvolumen exakt erhalten bleibt (Volume max 9.900,1 ccm, effektiv nutzbar 5.500,1 nach Fardelage 2×2.200). Verifiziert im Log 04.08. 16:37. Kein Verhaltenssprung, bestehende Behälterpläne gültig, keine Neuplanung. Repo-Default (BuildBflDefault) bewusst unverändert — Mandantendaten leben in der DB (Off-Site-Backup).

**Muster für alle künftigen Installationen (Nancy!):** echte Behältergeometrie erfassen → Mittelmaß bei konischen Kisten → Füllgrad gegen das operativ bewährte Nutzvolumen kalibrieren, nicht raten. Füllgrad-Erhöhung später als bewusste Optimierung übers UI (Behälter-Seite), kein Update nötig.
