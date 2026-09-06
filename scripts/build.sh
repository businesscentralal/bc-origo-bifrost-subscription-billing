#!/usr/bin/env bash
# Local AL compile for the app (and optionally test) project, with the full analyzer set.
# Runs on macOS, Linux and Windows (Git Bash) - the AL extension ships one alc per platform.
# Usage: scripts/build.sh [app|test|both]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$ROOT/.out"
mkdir -p "$OUTDIR"

ALEXT="${AL_EXTENSION_PATH:-}"
if [ -z "$ALEXT" ]; then
  for base in "$HOME/.vscode/extensions" "$HOME/.vscode-server/extensions" "${USERPROFILE:-}/.vscode/extensions"; do
    [ -d "$base" ] || continue
    candidate="$(ls -d "$base"/ms-dynamics-smb.al-* 2>/dev/null | sort -V | tail -1)"
    [ -n "$candidate" ] && { ALEXT="$candidate"; break; }
  done
fi
[ -n "$ALEXT" ] || { echo "!! AL extension not found. Set AL_EXTENSION_PATH."; exit 1; }

ALC=""
for rel in bin/win32/alc.exe bin/darwin/alc bin/linux/alc bin/alc; do
  [ -f "$ALEXT/$rel" ] && { ALC="$ALEXT/$rel"; break; }
done
[ -n "$ALC" ] || { echo "!! no alc binary under $ALEXT/bin"; exit 1; }
[ -x "$ALC" ] || chmod +x "$ALC" 2>/dev/null || true

# alc.exe under Git Bash needs Windows paths; everywhere else the path is already right.
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

PY="$(command -v python3 || command -v python)"
appname() { "$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(d['publisher']+'_'+d['name']+'_'+d['version'])" "$1"; }

compile() {
  local proj="$1" name
  name="$(appname "$ROOT/$proj/app.json")"
  echo "==> compiling $proj -> $name.app"
  "$ALC" \
    /project:"$(winpath "$ROOT/$proj")" \
    /packagecachepath:"$(winpath "$ROOT/$proj/.alpackages")" \
    /out:"$(winpath "$OUTDIR/$name.app")" \
    /analyzer:"$(winpath "$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.CodeCop.dll")" \
    /analyzer:"$(winpath "$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.UICop.dll")" \
    /analyzer:"$(winpath "$ALEXT/bin/Analyzers/Microsoft.Dynamics.Nav.AppSourceCop.dll")" \
    /loglevel:Warning
}

TARGET="${1:-app}"
rc=0
case "$TARGET" in
  app)  compile app  || rc=$? ;;
  test) compile test || rc=$? ;;
  both) compile app || rc=$?; [ $rc -eq 0 ] && { compile test || rc=$?; } ;;
  *)    echo "usage: $0 [app|test|both]"; exit 2 ;;
esac
exit $rc
