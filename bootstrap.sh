#!/usr/bin/env bash
# asawall/.github — schlanker Loader (oeffentlich, enthaelt bewusst KEINE
# Betriebsdaten). Holt das eigentliche Memory-Set aus dem PRIVATEN Repo
# asawall/ops-docs ueber Vault -> GIT_PAT -> GitHub Contents-API.
#
# Diese Datei existiert nur, damit der historische Aufruf
#   curl -s https://raw.githubusercontent.com/asawall/.github/main/bootstrap.sh | bash
# unveraendert weiterfunktioniert. Inhaltliche Aenderungen gehoeren nach
# asawall/ops-docs/bootstrap.sh.

set -u
CID=/home/claude/vault_client_id
CSEC=/home/claude/vault_client_secret

if [ ! -f "$CID" ] || [ ! -f "$CSEC" ]; then
  echo "!! Vault-Credentials fehlen ($CID / $CSEC)."
  echo "!! Erst den Bootstrap-Block aus den Custom Instructions ausfuehren."
  exit 1
fi

TOKEN=$(curl -fsS -X POST "https://vault.tecmatiq.de/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"$(cat $CID)\",\"clientSecret\":\"$(cat $CSEC)\"}" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])" 2>/dev/null) || TOKEN=""
[ -z "$TOKEN" ] && { echo "!! Vault-Login fehlgeschlagen (Creds ungueltig oder Vault nicht erreichbar)."; exit 1; }

PAT=$(curl -fsS "https://vault.tecmatiq.de/api/v3/secrets/raw/GIT_PAT?workspaceSlug=tecmatiq&environment=prod&secretPath=%2Fproviders" \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['secret']['secretValue'])" 2>/dev/null) || PAT=""
[ -z "$PAT" ] && { echo "!! GIT_PAT nicht lesbar."; exit 1; }

curl -fsSL -H "Authorization: Bearer $PAT" -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/asawall/ops-docs/contents/bootstrap.sh" 2>/dev/null | bash \
  || { echo "!! Loader konnte asawall/ops-docs/bootstrap.sh nicht laden."; exit 1; }
