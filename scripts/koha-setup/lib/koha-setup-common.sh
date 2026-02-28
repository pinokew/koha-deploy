#!/usr/bin/env bash
# Спільні змінні середовища та допоміжні функції для runtime-кроків Koha.

init_koha_setup_env() {
  export MYSQL_SERVER="${MYSQL_SERVER:-${DB_HOST:-db}}"
  export MYSQL_USER="${MYSQL_USER:-${DB_USER:-koha_db}}"
  export MYSQL_PASSWORD="${MYSQL_PASSWORD:-${DB_PASS:-password}}"
  export DB_NAME="${DB_NAME:-koha_library}"

  : "${MB_HOST:=rabbitmq}"
  : "${MB_PORT:=61613}"
  : "${MB_USER:=${RABBITMQ_USER:-guest}}"
  : "${MB_PASS:=${RABBITMQ_PASS:-guest}}"
  export MB_HOST MB_PORT MB_USER MB_PASS

  : "${KOHA_INSTANCE:=library}"
  export KOHA_INSTANCE
  export KOHA_USER="${KOHA_INSTANCE}-koha"

  : "${TZ:=${KOHA_TIMEZONE:-Europe/Kyiv}}"
  export TZ

  : "${USE_MEMCACHED:=yes}"
  : "${MEMCACHED_SERVERS:=memcached:11211}"
  export USE_MEMCACHED MEMCACHED_SERVERS

  : "${USE_ELASTICSEARCH:=false}"
  : "${ELASTICSEARCH_HOST:=elasticsearch}"
  export USE_ELASTICSEARCH ELASTICSEARCH_HOST
}

require_db_env() {
  if [ -z "${MYSQL_SERVER}" ] || [ -z "${DB_NAME}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ]; then
    echo "ERROR: Database environment variables missing!"
    return 1
  fi
}

source_koha_functions_if_present() {
  if [ -f /usr/share/koha/bin/koha-functions.sh ]; then
    # shellcheck source=/usr/share/koha/bin/koha-functions.sh
    source /usr/share/koha/bin/koha-functions.sh
    return 0
  fi

  echo "WARNING: /usr/share/koha/bin/koha-functions.sh not found, continuing."
  return 0
}
