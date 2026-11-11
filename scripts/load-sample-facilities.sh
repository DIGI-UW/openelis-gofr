#!/usr/bin/env bash
# Loads seed/sample-facilities.json (FHIR transaction Bundle of Organizations) into GOFR.
# Usage: scripts/load-sample-facilities.sh [gofr-url] [user] [password]
set -euo pipefail
cd "$(dirname "$0")/.."
url="${1:-http://localhost:4000}"; user="${2:-root@gofr.org}"; pass="${3:-gofr}"
token=$(curl -sf -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"${user}\",\"password\":\"${pass}\"}" "${url}/auth/token" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
# GOFR accepts one resource per request (no transaction at the base URL) and only application/json bodies.
python3 - "$url" "$token" <<'PY'
import json, sys, urllib.request
url, token = sys.argv[1], sys.argv[2]
for e in json.load(open("seed/sample-facilities.json"))["entry"]:
    r = e["resource"]
    req = urllib.request.Request(f"{url}/fhir/DEFAULT/Organization/{r['id']}", data=json.dumps(r).encode(), method="PUT",
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as res:
        print(f"PUT Organization {r['name']}: HTTP {res.status}")
PY
curl -sf -H "Authorization: Bearer ${token}" "${url}/fhir/DEFAULT/Organization?_summary=count" \
  | python3 -c 'import sys,json;print("Organizations in GOFR:", json.load(sys.stdin).get("total"))'
