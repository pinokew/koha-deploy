#!/usr/bin/env bash
# Script Purpose: Patch <message_broker> block in live koha-conf.xml from .env values.
# Usage: ./scripts/patch/patch-koha-conf-xml-message-broker.sh [--env-file FILE] [--wait-timeout SEC] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/_patch_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/patch/patch-koha-conf-xml-message-broker.sh [options]

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

PATCH_MB_HOST="${MB_HOST:-rabbitmq}"
PATCH_MB_PORT="${MB_PORT:-61613}"
PATCH_MB_USER="${RABBITMQ_USER:-guest}"
PATCH_MB_PASS="${RABBITMQ_PASS:-guest}"

[[ "${PATCH_MB_PORT}" =~ ^[0-9]+$ ]] || die "MB_PORT must be numeric"

log "Patching message_broker in ${KOHA_CONF_FILE} -> ${PATCH_MB_HOST}:${PATCH_MB_PORT}"

if ! ${DRY_RUN}; then
  export PATCH_MB_HOST PATCH_MB_PORT PATCH_MB_USER PATCH_MB_PASS
  perl -0777 -i -pe '
    sub esc {
      my ($v) = @_;
      $v = "" unless defined $v;
      $v =~ s/&/&amp;/g;
      $v =~ s/</&lt;/g;
      $v =~ s/>/&gt;/g;
      return $v;
    }
    my $h = esc($ENV{"PATCH_MB_HOST"});
    my $p = esc($ENV{"PATCH_MB_PORT"});
    my $u = esc($ENV{"PATCH_MB_USER"});
    my $w = esc($ENV{"PATCH_MB_PASS"});

    my $block = " <message_broker>\n"
      . "   <hostname>${h}</hostname>\n"
      . "   <port>${p}</port>\n"
      . "   <username>${u}</username>\n"
      . "   <password>${w}</password>\n"
      . "   <vhost></vhost>\n"
      . " </message_broker>";

    s{<message_broker>.*?</message_broker>}{$block}s or die "message_broker block not found\n";
  ' "${KOHA_CONF_FILE}"
fi

if ! ${DRY_RUN}; then
  grep -q "<hostname>${PATCH_MB_HOST}</hostname>" "${KOHA_CONF_FILE}" || die "message_broker host verify failed"
  grep -q "<port>${PATCH_MB_PORT}</port>" "${KOHA_CONF_FILE}" || die "message_broker port verify failed"
  grep -q "<username>${PATCH_MB_USER}</username>" "${KOHA_CONF_FILE}" || die "message_broker user verify failed"
fi

log "Done: message_broker"
