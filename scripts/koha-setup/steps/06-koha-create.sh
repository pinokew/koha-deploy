#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env
source_koha_functions_if_present

echo "Running koha-create logic..."

ES_PARAMS=()
if [ "${USE_ELASTICSEARCH}" = "true" ]; then
  ES_PARAMS+=(--elasticsearch-server "${ELASTICSEARCH_HOST}")
fi

set +e
koha-create --timezone "${TZ}" --use-db "${KOHA_INSTANCE}" "${ES_PARAMS[@]}" \
  --mb-host "${MB_HOST}" --mb-port "${MB_PORT}" --mb-user "${MB_USER}" --mb-pass "${MB_PASS}"
KOHA_CREATE_RC=$?
set -e

if [ "${KOHA_CREATE_RC}" -ne 0 ]; then
  echo "WARNING: koha-create failed with code ${KOHA_CREATE_RC}"
  exit "${KOHA_CREATE_RC}"
fi

# Keep s6 envdir aligned with the active instance config path.
echo "${KOHA_INSTANCE}" >/etc/koha-envvars/INSTANCE_NAME
echo "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml" >/etc/koha-envvars/KOHA_CONF

KOHA_CONF_PATH="/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
if [ "${USE_MEMCACHED}" != "no" ] && [ -f "${KOHA_CONF_PATH}" ]; then
  esc_memcached_servers="$(printf '%s' "${MEMCACHED_SERVERS}" | sed 's/[\\/&]/\\\\&/g')"
  sed -Ei "s#(<memcached_servers>).*?(</memcached_servers>)#\\1${esc_memcached_servers}\\2#" "${KOHA_CONF_PATH}" || true
fi
