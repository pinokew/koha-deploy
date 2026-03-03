#!/usr/bin/env bash
# Script Purpose: Patch <timezone> in live koha-conf.xml from .env value KOHA_TIMEZONE.
# Usage: ./scripts/patch/patch-koha-conf-xml-timezone.sh [--env-file FILE] [--wait-timeout SEC] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_patch_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/patch/patch-koha-conf-xml-timezone.sh [options]

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

PATCH_TZ="${KOHA_TIMEZONE:-Europe/Kyiv}"
log "Patching timezone in ${KOHA_CONF_FILE} -> ${PATCH_TZ}"

if ! ${DRY_RUN}; then
  export PATCH_TZ
  perl -0777 -i -pe '
    sub esc {
      my ($v) = @_;
      $v = "" unless defined $v;
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      return $v;
    }
    my $tz = esc($ENV{"PATCH_TZ"});
    s{<timezone>.*?</timezone>}{<timezone>${tz}</timezone>}s or die "timezone block not found\n";
  ' "${KOHA_CONF_FILE}"
fi

if ! ${DRY_RUN}; then
  grep -q "<timezone>${PATCH_TZ}</timezone>" "${KOHA_CONF_FILE}" || die "timezone verify failed"
fi

log "Done: timezone"
