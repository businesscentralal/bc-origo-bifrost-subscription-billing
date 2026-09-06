#!/usr/bin/env bash
# Download the symbol packages both projects compile against, straight from the dev container.
# Credentials come from the environment: BC_USER / BC_PASSWORD.
#   BC_USER=gunnar BC_PASSWORD=... scripts/getsymbols.sh [app|test|both]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="${BC_SERVER:-https://cosmo-alpaca-enterprise.westeurope.cloudapp.azure.com}"
INSTANCE="${BC_INSTANCE:-f068155f0c39dev}"
TENANT="${BC_TENANT:-default}"
: "${BC_USER:?set BC_USER}"
: "${BC_PASSWORD:?set BC_PASSWORD}"

PY="$(command -v python3 || command -v python)"
urlenc() { "$PY" -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"; }

fetch() {
  local dest="$1" pub="$2" name="$3" out code size
  out="$dest/${pub}_${name}.app"
  code=$(curl -sS -u "$BC_USER:$BC_PASSWORD" --max-time 900 -o "$out" -w "%{http_code}" \
    "$SERVER/$INSTANCE/dev/packages?publisher=$(urlenc "$pub")&appName=$(urlenc "$name")&tenant=$TENANT")
  size=$(wc -c < "$out" 2>/dev/null | tr -d ' ')
  if [ "$code" != "200" ] || [ "${size:-0}" -lt 1000 ]; then
    echo "!! $pub / $name -> HTTP $code ($size bytes)"
    rm -f "$out"
    return 1
  fi
  echo "ok $pub / $name ($size bytes)"
}

# Symbols the app project needs.
app_symbols() {
  local d="$ROOT/app/.alpackages"; mkdir -p "$d"
  fetch "$d" Microsoft "System"
  fetch "$d" Microsoft "System Application"
  fetch "$d" Microsoft "Business Foundation"
  fetch "$d" Microsoft "Base Application"
  fetch "$d" Microsoft "Application"
  fetch "$d" Microsoft "Subscription Billing"
  fetch "$d" Origo     "Bifrost Foundation"
}

# The test project needs the above, the Microsoft test libraries, and this app itself.
test_symbols() {
  local d="$ROOT/test/.alpackages"; mkdir -p "$d"
  fetch "$d" Microsoft "System"
  fetch "$d" Microsoft "System Application"
  fetch "$d" Microsoft "Business Foundation"
  fetch "$d" Microsoft "Base Application"
  fetch "$d" Microsoft "Application"
  fetch "$d" Microsoft "Subscription Billing"
  fetch "$d" Microsoft "Tests-TestLibraries"
  fetch "$d" Microsoft "Library Assert"
  fetch "$d" Microsoft "Test Runner"
  fetch "$d" Microsoft "Any"
  fetch "$d" Microsoft "Library Variable Storage"
  fetch "$d" Microsoft "Application Test Library"
  fetch "$d" Microsoft "Business Foundation Test Libraries"
  fetch "$d" Microsoft "System Application Test Library"
  fetch "$d" Microsoft "Permissions Mock"
  fetch "$d" Origo     "Bifrost Foundation"
  fetch "$d" Origo     "Bifrost Subscription Billing"
}

TARGET="${1:-app}"
case "$TARGET" in
  app)  app_symbols ;;
  test) test_symbols ;;
  both) app_symbols; test_symbols ;;
  *)    echo "usage: $0 [app|test|both]"; exit 2 ;;
esac
