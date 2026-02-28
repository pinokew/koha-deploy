#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=${KOHA_USER}/" /etc/apache2/envvars
sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=${KOHA_USER}/" /etc/apache2/envvars

# Normalise ports.conf (some image builds may contain a literal "\n" on one line).
printf "Listen 8081\nListen 8080\n" >/etc/apache2/ports.conf

if [ -f "/etc/apache2/sites-available/${KOHA_INSTANCE}.conf" ]; then
  sed -i '/^[[:space:]]*AssignUserID[[:space:]].*$/d' "/etc/apache2/sites-available/${KOHA_INSTANCE}.conf" || true
  ln -sf "../sites-available/${KOHA_INSTANCE}.conf" "/etc/apache2/sites-enabled/${KOHA_INSTANCE}.conf"
fi
