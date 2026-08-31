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

publish() {
  local proj="$1" name appfile code
  name="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['publisher']+'_'+d['name']+'_'+d['version'])" "$ROOT/$proj/app.json")"
  appfile="$ROOT/.out/$name.app"
  [ -f "$appfile" ] || { echo "!! $appfile not built"; return 1; }
  echo "==> publishing $name.app to $INSTANCE"
  code=$(curl -sS -u "$BC_USER:$BC_PASSWORD" -w '%{http_code}' -o /tmp/bc-publish-out.txt \
      -X POST "$SERVER/$INSTANCE/dev/apps?SchemaUpdateMode=synchronize&tenant=$TENANT" \
      -F "payload=@$appfile;type=application/octet-stream" --max-time 900)
  echo "   HTTP $code"
  if [ "$code" != "200" ] && [ "$code" != "204" ]; then
    head -c 2000 /tmp/bc-publish-out.txt; echo
    return 1
  fi
}

TARGET="${1:-app}"
rc=0
case "$TARGET" in
  app)  publish app  || rc=$? ;;
  test) publish test || rc=$? ;;
  both) publish app || rc=$?; [ $rc -eq 0 ] && { publish test || rc=$?; } ;;
esac
exit $rc
