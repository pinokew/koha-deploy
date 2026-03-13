#!/usr/bin/env bash
# Script Purpose: Set Koha domain system preferences (OPACBaseURL, staffClientBaseURL) from .env.
# Usage: ./scripts/patch/patch-koha-sysprefs-domain.sh [--env-file FILE] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_patch_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/patch/patch-koha-sysprefs-domain.sh [options]

Options:
  --env-file FILE     Path to env file (default: ./.env)
  --dry-run           Print actions only
  --help              Show help
USAGE
}

if ! parse_common_args "$@"; then
  usage
  exit 0
fi

load_env_file

OPAC_HOST="${KOHA_OPAC_SERVERNAME:-}"
STAFF_HOST="${KOHA_INTRANET_SERVERNAME:-}"

[ -n "${OPAC_HOST}" ] || die "KOHA_OPAC_SERVERNAME must be set"
[ -n "${STAFF_HOST}" ] || die "KOHA_INTRANET_SERVERNAME must be set"

OPAC_URL="https://${OPAC_HOST}/"
STAFF_URL="https://${STAFF_HOST}/"

log "Patching systempreferences: OPACBaseURL=${OPAC_URL}, staffClientBaseURL=${STAFF_URL}"

if ${DRY_RUN}; then
  log "DRY-RUN: skip DB update"
  exit 0
fi

SQL="
UPDATE systempreferences SET value='${OPAC_URL}' WHERE variable='OPACBaseURL';
UPDATE systempreferences SET value='${STAFF_URL}' WHERE variable='staffClientBaseURL';
SELECT variable, value FROM systempreferences
WHERE variable IN ('OPACBaseURL','staffClientBaseURL')
ORDER BY variable;
"

docker compose --env-file "${ENV_FILE}" -f "${PROJECT_ROOT}/docker-compose.yaml" exec -T \
  db mariadb -uroot "-p${DB_ROOT_PASS}" -D "${DB_NAME}" -e "${SQL}"

log "Done: domain system preferences"
