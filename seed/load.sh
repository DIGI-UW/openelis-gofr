#!/bin/sh
# Loads every Organization in seed/organizations into GOFR, one PUT per file
# (GOFR takes one resource per request and only application/json bodies).
# Waits up to 10 minutes for GOFR to issue a token first.
# Settings: GOFR_URL, GOFR_USER, GOFR_PASSWORD; SEED_DIR (default: this folder).
set -u
url="${GOFR_URL:-http://localhost:4000}"
user="${GOFR_USER:-root@gofr.org}"
pass="${GOFR_PASSWORD:-gofr}"
dir="${SEED_DIR:-$(dirname "$0")}/organizations"

token=""
tries=0
while [ -z "$token" ]; do
  token=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "{\"username\":\"${user}\",\"password\":\"${pass}\"}" "${url}/auth/token" \
    | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
  if [ -z "$token" ]; then
    tries=$((tries + 1))
    [ "$tries" -ge 60 ] && { echo "GOFR at ${url} gave no token after 10 minutes" >&2; exit 1; }
    sleep 10
  fi
done

failed=0
for f in "$dir"/*.json; do
  id=$(basename "$f" .json)
  code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: Bearer ${token}" \
    -H 'Content-Type: application/json' --data-binary "@${f}" "${url}/fhir/DEFAULT/Organization/${id}")
  echo "PUT Organization/${id}: HTTP ${code}"
  case "$code" in 200|201) ;; *) failed=1 ;; esac
done
curl -s -H "Authorization: Bearer ${token}" "${url}/fhir/DEFAULT/Organization?_summary=count" \
  | sed -n 's/.*"total" *: *\([0-9]*\).*/Organizations in GOFR: \1/p'
exit "$failed"
