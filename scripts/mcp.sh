#!/usr/bin/env bash
# Call the local Origo BC MCP bridge (which is wired to the dev container).
#   scripts/mcp.sh tools/list
#   scripts/mcp.sh tools/call '{"name":"list_domains","arguments":{"session_id":"cli"}}'
set -uo pipefail
URL="${MCP_URL:-http://localhost:3000/mcp?connection=bc28-is}"
: "${MCP_AUTH:?set MCP_AUTH to the Basic auth header value}"
METHOD="$1"; PARAMS="${2:-{}}"
curl -sS --max-time 120 -X POST "$URL" \
  -H "Authorization: $MCP_AUTH" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$METHOD\",\"params\":$PARAMS}" \
  | tr -d '\r' | sed -n 's/^data: //p'
