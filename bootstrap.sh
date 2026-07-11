#!/usr/bin/env bash
# asawall/.github — session bootstrap for Claude.
# Loads Andreas's durable memory into the session in one shot, then runs a
# secrets-free auth health check.
#
# Usage inside a Claude session:
#   curl -s https://raw.githubusercontent.com/asawall/.github/main/bootstrap.sh | bash
#
# The FILES list below is the SINGLE machine-readable declaration of the memory
# set. Mirror it in the layout table in CLAUDE.md when you add/remove a file.

set -u
BASE="https://raw.githubusercontent.com/asawall/.github/main"
FILES="CLAUDE regeln infra gotchas runbooks worklog"

for f in $FILES; do
  echo "===== $f.md ====="
  if ! curl -fsS "$BASE/$f.md"; then
    echo "(!! could not load $f.md — check network / repo)"
  fi
  echo
done

# --- auth health check (prints only the GitHub login, never any secret) ---
echo "===== auth health ====="
CID=/home/claude/vault_client_id
CSEC=/home/claude/vault_client_secret
if [ ! -f "$CID" ] || [ ! -f "$CSEC" ]; then
  echo "vault: creds not written yet — set them from Custom Instructions, then re-run"
else
  TOKEN=$(curl -fsS -X POST "https://vault.tecmatiq.de/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\":\"$(cat $CID)\",\"clientSecret\":\"$(cat $CSEC)\"}" 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['accessToken'])" 2>/dev/null) || TOKEN=""
  if [ -z "$TOKEN" ]; then
    echo "vault: login FAILED (creds invalid or Vault down)"
  else
    PAT=$(curl -fsS "https://vault.tecmatiq.de/api/v3/secrets/raw/GIT_PAT?workspaceSlug=tecmatiq&environment=prod&secretPath=%2Fproviders" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['secret']['secretValue'])" 2>/dev/null) || PAT=""
    if [ -z "$PAT" ]; then
      echo "vault: OK — GIT_PAT read FAILED"
    else
      LOGIN=$(curl -fsS -H "Authorization: Bearer $PAT" "https://api.github.com/user" 2>/dev/null \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['login'])" 2>/dev/null) || LOGIN=""
      if [ -n "$LOGIN" ]; then
        echo "vault + github: OK ($LOGIN)"
      else
        echo "vault: OK — github auth FAILED"
      fi
    fi
  fi
fi
