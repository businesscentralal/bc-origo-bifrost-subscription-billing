#!/usr/bin/env bash
# Publish a built .app to the COSMO Alpaca development container.
# Credentials come from the environment: BC_USER / BC_PASSWORD.
#   BC_USER=gunnar BC_PASSWORD=... scripts/deploy.sh [app|test|both]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="${BC_SERVER:-https://cosmo-alpaca-enterprise.westeurope.cloudapp.azure.com}"
INSTANCE="${BC_INSTANCE:-f068155f0c39dev}"
TENANT="${BC_TENANT:-default}"
: "${BC_USER:?set BC_USER}"
: "${BC_PASSWORD:?set BC_PASSWORD}"

PY="$(command -v python3 || command -v python)"
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

# Git Bash hands curl.exe a POSIX path it cannot open, so hand it a native one where we can.
nativepath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

publish() {
  local proj="$1" name appfile code
  name="$("$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(d['publisher']+'_'+d['name']+'_'+d['version'])" "$ROOT/$proj/app.json")"
  appfile="$ROOT/.out/$name.app"
  [ -f "$appfile" ] || { echo "!! $appfile not built"; return 1; }
  echo "==> publishing $name.app to $INSTANCE"
  code=$(curl -sS -u "$BC_USER:$BC_PASSWORD" -w '%{http_code}' -o "$OUT" \
      -X POST "$SERVER/$INSTANCE/dev/apps?SchemaUpdateMode=synchronize&tenant=$TENANT" \
      -F "payload=@\"$(nativepath "$appfile")\";type=application/octet-stream" --max-time 1200)
  echo "   HTTP $code"
  if [ "$code" != "200" ] && [ "$code" != "204" ]; then
    head -c 4000 "$OUT"; echo
    return 1
  fi
}

TARGET="${1:-app}"
rc=0
case "$TARGET" in
  app)  publish app  || rc=$? ;;
  test) publish test || rc=$? ;;
  both) publish app || rc=$?; [ $rc -eq 0 ] && { publish test || rc=$?; } ;;
  *)    echo "usage: $0 [app|test|both]"; exit 2 ;;
esac
exit $rc
