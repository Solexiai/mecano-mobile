#!/usr/bin/env bash
# Emit compact GitHub annotations for Jest failures (failing suites, failing
# test titles and the first error lines). Raw job logs are not always
# downloadable; annotations are readable through the Checks API.
log="$1"; label="${2:-Jest}"
[ -f "$log" ] || exit 0
grep -E '^FAIL ' "$log" | sort -u | head -n 20 | while IFS= read -r line; do
  echo "::error title=${label} suite failed::${line}"
done
grep -E '^[[:space:]]+● ' "$log" | grep -v '● Console' | sed -E 's/^[[:space:]]+//' | sort -u | head -n 30 | while IFS= read -r line; do
  echo "::error title=${label} test failed::${line}"
done
# Error blocks only (skip "● Console" noise), ANSI colours stripped.
details="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | awk '/^[[:space:]]+● /{keep = ($0 !~ /● Console/); n=0} keep && n < 30 {print; n++}' | head -n 400 | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')"
[ -n "$details" ] && echo "::error title=${label} failure details::${details}"
exit 0
