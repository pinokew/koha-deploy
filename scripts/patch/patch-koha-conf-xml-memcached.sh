#!/usr/bin/env bash
# Script Purpose: Patch <memcached_servers> in live koha-conf.xml from .env value MEMCACHED_SERVERS.
# Usage: ./scripts/patch/patch-koha-conf-xml-memcached.sh [--env-file FILE] [--wait-timeout SEC] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_patch_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/patch/patch-koha-conf-xml-memcached.sh [options]

Options:
  --env-file FILE     Path to env file (default: ./.env)
  --wait-timeout SEC  Wait timeout for koha-conf.xml (default: 300)
  --dry-run           Print actions only
  --no-wait           Do not wait for file creation
  --help              Show help
USAGE
}

if ! parse_common_args "$@"; then
  usage
  exit 0
fi

prepare_live_context

PATCH_MEMCACHED="${MEMCACHED_SERVERS:-memcached:11211}"
log "Patching memcached_servers in ${KOHA_CONF_FILE} -> ${PATCH_MEMCACHED}"

if ! ${DRY_RUN}; then
  export PATCH_MEMCACHED
  perl -0777 -i -pe '
    sub esc {
      my ($v) = @_;
      $v = "" unless defined $v;
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      return $v;
    }
    my $mem = esc($ENV{"PATCH_MEMCACHED"});
    s{(<memcached_servers>).*?(</memcached_servers>)}{$1${mem}$2}s or die "memcached_servers block not found\n";
  ' "${KOHA_CONF_FILE}"
fi

if ! ${DRY_RUN}; then
  grep -q "<memcached_servers>${PATCH_MEMCACHED}</memcached_servers>" "${KOHA_CONF_FILE}" || die "memcached verify failed"
fi

log "Done: memcached_servers"
