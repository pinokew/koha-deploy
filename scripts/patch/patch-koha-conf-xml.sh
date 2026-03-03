#!/usr/bin/env bash
# Script Purpose: Convenience wrapper to run all live koha-conf.xml patch modules.
# Usage: ./scripts/patch/patch-koha-conf-xml.sh [bootstrap-live-configs options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

exec "${PROJECT_ROOT}/scripts/bootstrap-live-configs.sh" \
  --modules timezone,memcached,message-broker,smtp,verify \
  "$@"
