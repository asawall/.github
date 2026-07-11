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
