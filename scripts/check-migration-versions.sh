#!/usr/bin/env bash
set -euo pipefail

versions="$(find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print \
  | sed -E 's#.*/([0-9]+)_.*#\1#' \
  | sort)"

duplicates="$(printf '%s\n' "$versions" | uniq -d)"
if [[ -n "$duplicates" ]]; then
  echo "Duplicate migration versions:" >&2
  echo "$duplicates" >&2
  exit 1
fi

if rg -n 'Bearer eyJ|[a-z]{20}\.supabase\.co/functions' \
  supabase/migrations supabase/functions; then
  echo "Project-specific endpoint or JWT found in database/function source." >&2
  exit 1
fi

test -f supabase/config.toml
test -f supabase/seed.sql
echo "Migration versions and source configuration are deterministic."
