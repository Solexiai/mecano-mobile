#!/usr/bin/env bash
# Emit compact GitHub annotations for Jest failures (failing suites, failing
# test titles and the first error lines). Raw job logs are not always
# downloadable; annotations are readable through the Checks API.
log="$1"; label="${2:-Jest}"
[ -f "$log" ] || exit 0
grep -E '^FAIL ' "$log" | sort -u | head -n 20 | while IFS= read -r line; do
  echo "::error title=${label} suite failed::${line}"
done
grep -E '^\s+● ' "$log" | sed -E 's/^\s+//' | sort -u | head -n 30 | while IFS= read -r line; do
  echo "::error title=${label} test failed::${line}"
done
details="$(grep -A 25 -E '^\s+● ' "$log" | head -n 200 | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')"
[ -n "$details" ] && echo "::error title=${label} failure details::${details}"
exit 0
