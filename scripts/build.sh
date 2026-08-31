#!/usr/bin/env bash
# Local AL compile for the app (and optionally test) project.
# Usage: scripts/build.sh [app|test|both]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALEXT="$HOME/.vscode/extensions/ms-dynamics-smb.al-17.0.2273547"
ALC="$ALEXT/bin/darwin/alc"
OUTDIR="$ROOT/.out"
mkdir -p "$OUTDIR"
[ -x "$ALC" ] || chmod +x "$ALC"

compile() {
  local proj="$1"
  local name
  name="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['publisher']+'_'+d['name']+'_'+d['version'])" "$ROOT/$proj/app.json")"
  echo "==> compiling $proj -> $name.app"
  "$ALC" \
    /project:"$ROOT/$proj" \
    /packagecachepath:"$ROOT/$proj/.alpackages" \
    /out:"$OUTDIR/$name.app" \
    /analyzer:"$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.CodeCop.dll" \
    /analyzer:"$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.UICop.dll" \
    /analyzer:"$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.AppSourceCop.dll" \
    /loglevel:Warning
  return $?
}

TARGET="${1:-app}"
rc=0
case "$TARGET" in
  app)  compile app  || rc=$? ;;
  test) compile test || rc=$? ;;
  both) compile app || rc=$?; [ $rc -eq 0 ] && { compile test || rc=$?; } ;;
esac
exit $rc
