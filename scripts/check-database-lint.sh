#!/usr/bin/env bash
set -euo pipefail

lint_json="$(supabase db lint --local --level warning --fail-on none --output json)"
echo "$lint_json" | jq .

# plpgsql_check cannot model a transaction-local table created earlier inside
# the same routine. The function is covered by 09_notification_v2.test.sql;
# allow only that exact static-analysis false positive.
unexpected="$(echo "$lint_json" | jq '[
  (if type == "array" then . else .results end)[] as $result
  | $result.issues[]
  | select((
      $result.function == "public.expand_notification_outbox_v2"
      and .sqlState == "42P01"
      and (.query.text | startswith("insert into pg_temp.notification_v2_batch"))
    ) | not)
] | length')"

if [[ "$unexpected" != "0" ]]; then
  echo "Unexpected database lint findings: $unexpected" >&2
  exit 1
fi
