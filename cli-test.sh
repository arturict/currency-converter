#!/usr/bin/env bash

failures=0 #anzahl fails
rates_file="exchange-rates.json"
cli_file="src/cli.ts"

ok() { echo "OK:   $1"; }
bad() { echo "FAIL: $1"; failures=$((failures + 1)); }

if ! command -v deno >/dev/null 2>&1; then
  echo "deno not found" >&2
  exit 1
fi

if [ ! -f "$rates_file" ] || [ ! -f "$cli_file" ]; then
  echo "missing $rates_file or $cli_file" >&2
  exit 1
fi

# 1) Konversion mit bekannten Währung (usd -> chf)
out="$(deno run --allow-read "$cli_file" --rates "$rates_file" --from usd --to chf --amount 100 2>/dev/null)"
status=$?
if [ "$status" -eq 0 ] && [ "$out" = "81" ]; then
  ok "usd -> chf (100) = 81"
else
  bad "usd -> chf (100) expected 81, got '$out' (exit $status)"
fi

# 2) Konversion mit anderen bekannten Währung (eur -> chf)
out="$(deno run --allow-read "$cli_file" --rates "$rates_file" --from eur --to chf --amount 100 2>/dev/null)"
status=$?
if [ "$status" -eq 0 ] && [ "$out" = "94" ]; then
  ok "eur -> chf (100) = 94"
else
  bad "eur -> chf (100) expected 94, got '$out' (exit $status)"
fi

# 3) Konversion in die umgekehrte Richtung (chf -> usd)
out="$(deno run --allow-read "$cli_file" --rates "$rates_file" --from chf --to usd --amount 1900 2>/dev/null)"
status=$?
if [ "$status" -eq 0 ] && [ "$out" = "2345.679012345679" ]; then
  ok "chf -> usd (1900) = 2345.679012345679"
else
  bad "chf -> usd (1900) expected 2345.679012345679, got '$out' (exit $status)"
fi

# 4) Konversion mit unbekannten Währung (soll fehlschlagen)
deno run --allow-read "$cli_file" --rates "$rates_file" --from usd --to zzz --amount 100 >/dev/null 2>/dev/null
status=$?
if [ "$status" -ne 0 ]; then
  ok "unknown currency usd -> zzz fails"
else
  bad "unknown currency usd -> zzz should fail (exit $status)"
fi

if [ "$failures" -eq 0 ]; then #wenn keine fails, ok
  echo "All CLI tests passed."
  exit 0
else # wenn fails, fehler ausgeben
  echo "$failures CLI test(s) failed." >&2
  exit 1
fi
