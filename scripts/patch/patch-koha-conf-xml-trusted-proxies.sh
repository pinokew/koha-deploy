#!/usr/bin/env bash
# Script Purpose: Patch <koha_trusted_proxies> in live koha-conf.xml from .env value KOHA_TRUSTED_PROXIES.
# Usage: ./scripts/patch/patch-koha-conf-xml-trusted-proxies.sh [--env-file FILE] [--wait-timeout SEC] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_patch_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/patch/patch-koha-conf-xml-trusted-proxies.sh [options]

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

PATCH_TRUSTED_PROXIES="${KOHA_TRUSTED_PROXIES:-127.0.0.1 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
[ -n "${PATCH_TRUSTED_PROXIES}" ] || die "KOHA_TRUSTED_PROXIES must not be empty"

log "Patching koha_trusted_proxies in ${KOHA_CONF_FILE} -> ${PATCH_TRUSTED_PROXIES}"

if ! ${DRY_RUN}; then
  export PATCH_TRUSTED_PROXIES
  perl -0777 -i -pe '
    sub esc {
      my ($v) = @_;
      $v = "" unless defined $v;
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      return $v;
    }

    my $tp = esc($ENV{"PATCH_TRUSTED_PROXIES"});
    my $line = " <koha_trusted_proxies>${tp}</koha_trusted_proxies>";

    if (s{<koha_trusted_proxies>.*?</koha_trusted_proxies>}{$line}s) {
      # replaced existing
    } else {
      s{<!-- Elasticsearch Configuration -->}{$line\n\n <!-- Elasticsearch Configuration -->}s
        or die "insertion point for koha_trusted_proxies not found\n";
    }
  ' "${KOHA_CONF_FILE}"
fi

if ! ${DRY_RUN}; then
  grep -q "<koha_trusted_proxies>${PATCH_TRUSTED_PROXIES}</koha_trusted_proxies>" "${KOHA_CONF_FILE}" || die "koha_trusted_proxies verify failed"
fi

log "Done: koha_trusted_proxies"
