#!/bin/sh
# Loads the sample facilities (seed/organizations) into a GOFR. The stack does
# this on its own at start (service gofr-seed); use this for another GOFR.
# Usage: scripts/load-sample-facilities.sh [gofr-url] [user] [password]
cd "$(dirname "$0")/.." || exit 1
GOFR_URL="${1:-http://localhost:${GOFR_HTTP_PORT:-4000}}" GOFR_USER="${2:-root@gofr.org}" GOFR_PASSWORD="${3:-gofr}" \
  SEED_DIR=seed exec sh seed/load.sh
