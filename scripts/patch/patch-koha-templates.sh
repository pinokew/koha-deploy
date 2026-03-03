#!/usr/bin/env bash
# Script Purpose: Backward-compatible wrapper; template patch flow is deprecated in this repo.
# Usage: ./scripts/patch/patch-koha-templates.sh [bootstrap-live-configs options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "WARNING: template patch flow is deprecated; running live bootstrap modules instead." >&2
exec "${PROJECT_ROOT}/scripts/bootstrap-live-configs.sh" --all "$@"
