# worklog.md — last ~30 sessions in keywords

> Newest on top. One line per session: `YYYY-MM-DD — what changed`. Keep it terse.
> When it grows past ~30 lines, trim the oldest — this is a rolling window, not an
> archive. Deeper detail lives in the per-area files, not here.

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
