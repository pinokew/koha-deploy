#!/usr/bin/env bash
# Shared helpers for live Koha config patch modules.
# Usage: source this file from scripts under scripts/patch.

set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${PATCH_DIR}/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/.env}"
WAIT_TIMEOUT=300
DRY_RUN=false
NO_WAIT=false

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

parse_common_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --env-file)
        shift
        [ "$#" -gt 0 ] || die "--env-file requires value"
        ENV_FILE="$1"
        ;;
      --wait-timeout)
        shift
        [ "$#" -gt 0 ] || die "--wait-timeout requires value"
        WAIT_TIMEOUT="$1"
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --no-wait)
        NO_WAIT=true
        ;;
      --help|-h)
        return 2
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  [[ "${WAIT_TIMEOUT}" =~ ^[0-9]+$ ]] || die "--wait-timeout must be numeric"
  return 0
}

load_env_file() {
  [ -f "${ENV_FILE}" ] || die ".env file not found: ${ENV_FILE}"

  local line key value
  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%$'\r'}"
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ ! "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      die "Invalid dotenv line in ${ENV_FILE}: ${line}"
    fi

    key="${line%%=*}"
    value="${line#*=}"

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "${key}=${value}"
  done < "${ENV_FILE}"
}

wait_for_file() {
  local file="$1"
  local timeout="$2"
  local elapsed=0

  while [ "${elapsed}" -lt "${timeout}" ]; do
    [ -f "${file}" ] && return 0
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

prepare_live_context() {
  load_env_file

  KOHA_INSTANCE="${KOHA_INSTANCE:-library}"
  VOL_KOHA_CONF="${VOL_KOHA_CONF:-}"
  [ -n "${VOL_KOHA_CONF}" ] || die "VOL_KOHA_CONF is required in ${ENV_FILE}"

  KOHA_CONF_FILE="${VOL_KOHA_CONF}/${KOHA_INSTANCE}/koha-conf.xml"
  KOHA_CONF_BACKUP_FILE="${KOHA_CONF_FILE}.bak.bootstrap"

  if ! ${NO_WAIT}; then
    log "Waiting for live config: ${KOHA_CONF_FILE} (timeout=${WAIT_TIMEOUT}s)"
    wait_for_file "${KOHA_CONF_FILE}" "${WAIT_TIMEOUT}" || die "koha-conf.xml not found in volume within timeout"
  fi

  if ! ${DRY_RUN}; then
    if [ ! -f "${KOHA_CONF_BACKUP_FILE}" ]; then
      cp -a "${KOHA_CONF_FILE}" "${KOHA_CONF_BACKUP_FILE}"
      log "Backup created: ${KOHA_CONF_BACKUP_FILE}"
    fi
  fi
}

xml_escape() {
  local v="$1"
  v="${v//&/&amp;}"
  v="${v//</&lt;}"
  v="${v//>/&gt;}"
  printf '%s' "${v}"
}

run_perl_patch() {
  local description="$1"
  local perl_code="$2"

  log "Patching ${description} in ${KOHA_CONF_FILE}"
  if ${DRY_RUN}; then
    log "DRY-RUN: skipped ${description} patch"
    return 0
  fi

  perl -0777 -i -pe "${perl_code}" "${KOHA_CONF_FILE}"
}
