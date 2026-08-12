# CLAUDE.md — Einstiegspunkt

Das Memory-Set liegt seit dem 12.08.2026 im **privaten** Repo `asawall/ops-docs`.
Dieses Repo hier ist öffentlich (die Reusable Workflows müssen es sein) und
enthält deshalb keine Betriebsdaten mehr.

Lade den echten Inhalt mit dem Loader in diesem Repo:

```bash
curl -s https://raw.githubusercontent.com/asawall/.github/main/bootstrap.sh | bash
```

Der Loader authentifiziert sich über die Vault-Credentials, die in den Custom
Instructions nach `/home/claude/vault_client_id` und `_secret` geschrieben
werden, und zieht damit CLAUDE.md, regeln.md, infra.md, gotchas.md,
runbooks.md und worklog.md aus `asawall/ops-docs`.

Ohne gültige Vault-Credentials bricht der Loader mit einer klaren Meldung ab —
er läuft nie stillschweigend leer.
