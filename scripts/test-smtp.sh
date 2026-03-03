#!/usr/bin/env bash
# Script Purpose: Send a direct test email via Koha SMTP settings from koha-conf.xml.
# Usage: ./scripts/test-smtp.sh [--to EMAIL] [--from EMAIL] [--subject TEXT] [--env-file FILE]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/.env}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: ./scripts/test-smtp.sh [options]

Options:
  --to EMAIL       Recipient for test email (default: SMTP_TEST_TO)
  --from EMAIL     Sender for test email (default: SMTP_TEST_FROM or noreply@KOHA_DOMAIN)
  --subject TEXT   Subject for test email
  --env-file FILE  Path to env file (default: ./.env)
  --help           Show help
USAGE
}

TO_ADDR=""
FROM_ADDR=""
SUBJECT_OVERRIDE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --to)
      shift
      [ "$#" -gt 0 ] || die "--to requires value"
      TO_ADDR="$1"
      ;;
    --from)
      shift
      [ "$#" -gt 0 ] || die "--from requires value"
      FROM_ADDR="$1"
      ;;
    --subject)
      shift
      [ "$#" -gt 0 ] || die "--subject requires value"
      SUBJECT_OVERRIDE="$1"
      ;;
    --env-file)
      shift
      [ "$#" -gt 0 ] || die "--env-file requires value"
      ENV_FILE="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

[ -f "${ENV_FILE}" ] || die ".env file not found: ${ENV_FILE}"

set -a
# shellcheck disable=SC1090
. "${ENV_FILE}"
set +a

TO_ADDR="${TO_ADDR:-${SMTP_TEST_TO:-}}"
FROM_ADDR="${FROM_ADDR:-${SMTP_TEST_FROM:-noreply@${KOHA_DOMAIN:-example.local}}}"

[ -n "${TO_ADDR}" ] || die "Recipient is empty. Set SMTP_TEST_TO in .env or pass --to"

TS_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
SUBJECT="${SUBJECT_OVERRIDE:-Koha SMTP test ${TS_UTC}}"
BODY="Koha SMTP test from koha-deploy at ${TS_UTC}"

log "Sending SMTP test email"
log "From: ${FROM_ADDR}"
log "To:   ${TO_ADDR}"
log "Subject: ${SUBJECT}"

PERL_SEND='my $cfg=C4::Context->config("smtp_server"); my %opts=(host=>$cfg->{host},port=>0+($cfg->{port}||25),timeout=>0+($cfg->{timeout}||120)); if (($cfg->{ssl_mode}||"disabled") eq "ssl"){$opts{ssl}=1;} elsif (($cfg->{ssl_mode}||"disabled") eq "starttls"){$opts{ssl}="starttls";} if (($cfg->{user_name}||"") ne ""){$opts{sasl_username}=$cfg->{user_name};$opts{sasl_password}=$cfg->{password};} my $transport=Email::Sender::Transport::SMTP->new(\%opts); my $email=Email::Simple->create(header=>[To=>$ENV{SMTP_TO},From=>$ENV{SMTP_FROM},Subject=>$ENV{SMTP_SUBJECT}],body=>$ENV{SMTP_BODY}); eval { sendmail($email,{transport=>$transport}); 1 } or die "SMTP send failed: $@"; print "SMTP send OK\n";'

docker compose exec -T \
  -e SMTP_TO="${TO_ADDR}" \
  -e SMTP_FROM="${FROM_ADDR}" \
  -e SMTP_SUBJECT="${SUBJECT}" \
  -e SMTP_BODY="${BODY}" \
  koha sh -lc "perl -I/usr/share/koha/lib -MC4::Context -MEmail::Sender::Simple=sendmail -MEmail::Simple -MEmail::Simple::Creator -MEmail::Sender::Transport::SMTP -e '${PERL_SEND}'"

log "SMTP test passed"
