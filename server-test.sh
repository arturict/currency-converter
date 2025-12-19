#!/usr/bin/env bash

# System tests for src/server.ts
# Uses: bash, curl, jq
# Exit 0 if all tests pass, otherwise exit 1.

failures=0

ok() { echo "OK:   $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing command: $1" >&2
    exit 1
  fi
}

require_cmd deno
require_cmd curl
require_cmd jq

if [ ! -f "src/server.ts" ]; then
  echo "missing src/server.ts" >&2
  exit 1
fi

base_url="http://localhost:8000"
auth="banker:iLikeMoney"

server_log="$(mktemp)"

deno run --allow-net src/server.ts >"$server_log" 2>&1 &
server_pid=$!

cleanup() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$server_log" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait until server responds (max ~5s)
ready=0
for _ in $(seq 1 50); do
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "$base_url/rate/usd/chf" || true)"
  if [ "$code" != "000" ]; then
    ready=1
    break
  fi
  sleep 0.1
done

if [ "$ready" -ne 1 ]; then
  echo "server did not start" >&2
  echo "--- server log ---" >&2
  cat "$server_log" >&2 || true
  exit 1
fi

request() {
  # usage: request METHOD URL [AUTH]
  local method="$1" url="$2" use_auth="${3:-no}"
  local body_file
  body_file="$(mktemp)"

  if [ "$use_auth" = "auth" ]; then
    HTTP_STATUS="$(curl -sS -u "$auth" -X "$method" -o "$body_file" -w "%{http_code}" "$url" || true)"
  else
    HTTP_STATUS="$(curl -sS -X "$method" -o "$body_file" -w "%{http_code}" "$url" || true)"
  fi

  HTTP_BODY="$(cat "$body_file")"
  rm -f "$body_file"
}

# 1) Hinterlegen eines neuen Wechselkurses
request PUT "$base_url/rate/usd/chf/0.81" auth
if [ "$HTTP_STATUS" = "201" ]; then
  ok "PUT /rate/usd/chf/0.81 -> 201"
else
  fail "PUT expected 201, got $HTTP_STATUS (body='$HTTP_BODY')"
fi

# 2) Abrufen eines bekannten Wechselkurses
request GET "$base_url/rate/usd/chf"
rate="$(printf "%s" "$HTTP_BODY" | jq -r '.rate' 2>/dev/null || true)"
if [ "$HTTP_STATUS" = "200" ] && [ "$rate" = "0.81" ]; then
  ok "GET /rate/usd/chf -> rate 0.81"
else
  fail "GET known rate expected 200 and 0.81, got $HTTP_STATUS and '$rate' (body='$HTTP_BODY')"
fi

# 3) Abrufen eines unbekannten Wechselkurses (Negativtest)
request GET "$base_url/rate/aaa/bbb"
if [ "$HTTP_STATUS" = "404" ]; then
  ok "GET /rate/aaa/bbb -> 404"
else
  fail "GET unknown rate expected 404, got $HTTP_STATUS (body='$HTTP_BODY')"
fi

# 4) Konversion mit einer bekannten Währung
request GET "$base_url/conversion/usd/chf/100"
result="$(printf "%s" "$HTTP_BODY" | jq -r '.result' 2>/dev/null || true)"
if [ "$HTTP_STATUS" = "200" ] && [ "$result" = "81" ]; then
  ok "GET /conversion/usd/chf/100 -> 81"
else
  fail "conversion expected 200 and 81, got $HTTP_STATUS and '$result' (body='$HTTP_BODY')"
fi

# 5) Konversion in die umgekehrte Richtung
request GET "$base_url/conversion/chf/usd/1900"
result="$(printf "%s" "$HTTP_BODY" | jq -r '.result' 2>/dev/null || true)"
if [ "$HTTP_STATUS" = "200" ] && [ "$result" = "2345.679012345679" ]; then
  ok "GET /conversion/chf/usd/1900 -> 2345.679012345679"
else
  fail "reverse conversion expected 200 and 2345.679012345679, got $HTTP_STATUS and '$result' (body='$HTTP_BODY')"
fi

# 6) Entfernen eines Wechselkurses
request DELETE "$base_url/rate/usd/chf" auth
if [ "$HTTP_STATUS" = "204" ]; then
  ok "DELETE /rate/usd/chf -> 204"
else
  fail "DELETE expected 204, got $HTTP_STATUS (body='$HTTP_BODY')"
fi

# 7) Konversion für entfernte Währung (Negativtest)
request GET "$base_url/conversion/usd/chf/100"
if [ "$HTTP_STATUS" = "500" ]; then
  ok "conversion after delete fails (500)"
else
  fail "conversion after delete expected 500, got $HTTP_STATUS (body='$HTTP_BODY')"
fi

if [ "$failures" -eq 0 ]; then
  echo "All server tests passed."
  exit 0
else
  echo "$failures server test(s) failed." >&2
  exit 1
fi
