#!/usr/bin/env bash
set -euo pipefail

# === ПЕРЕВІРКА ENV ===
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  echo "❌ .env не знайдено!"
  exit 1
fi

RESTORE_SOURCE_DIR=${RESTORE_SOURCE_DIR}
RESTORE_ES_DATA="${RESTORE_ES_DATA:-false}"

if [ ! -d "$RESTORE_SOURCE_DIR" ]; then
  echo "❌ Папка бекапу не існує: $RESTORE_SOURCE_DIR"
  exit 1
fi

echo "⚠️  УВАГА! Гібридне відновлення: Файли з архівів + База з SQL."
echo "📂 Джерело: $RESTORE_SOURCE_DIR"
echo "🧩 Режим Elasticsearch: RESTORE_ES_DATA=${RESTORE_ES_DATA}"
echo "⏳ 5 секунд на скасування..."
sleep 5

# === 0. Змінні ===
VOL_DB=${VOL_DB_PATH}
VOL_CONFIG=${VOL_KOHA_CONF}
VOL_DATA=${VOL_KOHA_DATA}
VOL_ES=${VOL_ES_PATH}
KOHA_CONF_UID="${KOHA_CONF_UID:-0}"
KOHA_CONF_GID="${KOHA_CONF_GID:-1000}"

# === 1. Зупинка ===
echo "🛑 [1/7] Зупиняю контейнери..."
docker compose down --remove-orphans

# === 2. Відновлення ФАЙЛІВ (Config + Data; ES за флагом) ===
# Функція для розпаковки і виправлення прав
restore_files() {
  local vol_path=$1
  local file_name=$2
  local uid=$3
  local gid=$4

  if [ -f "$RESTORE_SOURCE_DIR/$file_name" ]; then
    echo "📦 Відновлюю файли в $vol_path..."
    docker run --rm \
      -v "$vol_path":/target \
      -v "$RESTORE_SOURCE_DIR":/backup \
      alpine sh -c "
        find /target -mindepth 1 -maxdepth 1 -exec rm -rf {} + && \
        cd /target && \
        tar -xzf /backup/$file_name && \
        echo '🔧 Права доступу -> $uid:$gid' && \
        chown -R $uid:$gid /target
      "
    echo "   -> Готово."
  else
    echo "⚠️  Архів $file_name не знайдено (це ок, якщо ти так планував)."
  fi
}

normalize_koha_conf_memcached() {
  local memcached_servers="${MEMCACHED_SERVERS:-memcached:11211}"

  docker run --rm \
    -e KOHA_INSTANCE="${KOHA_INSTANCE:-library}" \
    -e MEMCACHED_SERVERS="${memcached_servers}" \
    -e KOHA_CONF_UID="${KOHA_CONF_UID}" \
    -e KOHA_CONF_GID="${KOHA_CONF_GID}" \
    -v "$VOL_CONFIG":/target \
    alpine sh -c '
      set -eu
      conf="/target/${KOHA_INSTANCE}/koha-conf.xml"
      if [ ! -f "$conf" ]; then
        conf="$(find /target -maxdepth 3 -type f -name koha-conf.xml | head -n1 || true)"
      fi
      if [ -z "${conf:-}" ] || [ ! -f "$conf" ]; then
        echo "⚠️  koha-conf.xml не знайдено у config volume, пропускаю нормалізацію memcached."
        exit 0
      fi

      esc_memcached="$(printf "%s" "$MEMCACHED_SERVERS" | sed "s/[\\/&]/\\\\&/g")"
      if grep -q "<memcached_servers>" "$conf"; then
        sed -Ei "s#(<memcached_servers>)[^<]*(</memcached_servers>)#\\1${esc_memcached}\\2#" "$conf"
        chown "${KOHA_CONF_UID}:${KOHA_CONF_GID}" "$conf" || true
        chmod 640 "$conf" || true
        echo "✅ Нормалізовано memcached_servers у $conf -> ${MEMCACHED_SERVERS}"
      else
        echo "⚠️  У $conf не знайдено тег <memcached_servers>, пропускаю."
      fi
    '
}

echo "♻️  [2/7] Відновлення файлових томів..."

# УВАГА: Ми НЕ відновлюємо mariadb_volume.tar.gz, щоб уникнути проблем з паролями.
# Базу створимо чистою і заллємо SQL.

# Config (root:koha-group) + нормалізація прав
restore_files "$VOL_CONFIG" "koha_config.tar.gz" "${KOHA_CONF_UID}" "${KOHA_CONF_GID}"
docker run --rm \
  -v "$VOL_CONFIG":/target \
  alpine sh -c "
    find /target -type d -exec chmod 2775 {} + && \
    find /target -type f -exec chmod 640 {} +
  "
normalize_koha_conf_memcached

# Data (koha:koha -> 1000:1000)
restore_files "$VOL_DATA" "koha_data.tar.gz" 1000 1000

# Elasticsearch:
# За замовчуванням НЕ відновлюємо сирі файли індексів, бо вони
# часто несумісні з новою версією/плагінами ES. Після цього робиться rebuild.
if [ "${RESTORE_ES_DATA}" = "true" ]; then
  echo "⚠️  RESTORE_ES_DATA=true: відновлюю es_data.tar.gz (ризик несумісності мапінгів)."
  restore_files "$VOL_ES" "es_data.tar.gz" 1000 1000
else
  echo "🧹 Очищаю том Elasticsearch ($VOL_ES) для чистого старту індексу."
  docker run --rm \
    -v "$VOL_ES":/target \
    alpine sh -c "
      find /target -mindepth 1 -maxdepth 1 -exec rm -rf {} + && \
      chown -R 1000:1000 /target
    "
fi

echo "✅ Файли відновлено."

# === 3. Старт чистої бази ===
echo "🚀 [3/7] Запускаю чисту базу даних..."
# Оскільки папка mysql_data пуста, Docker створить нову базу
# і встановить паролі, які прописані в .env!
docker compose up -d db

echo "⏳ Чекаю ініціалізації бази (30 сек)..."
# Треба дати час на перше створення системних таблиць
sleep 30

until docker compose exec -T db mariadb-admin -u"${DB_USER}" -p"${DB_PASS}" ping >/dev/null 2>&1; do
  echo -n "."
  sleep 3
done
echo " База готова до прийому даних!"

wait_service_healthy() {
  local service="$1"
  local timeout="${2:-180}"
  local elapsed=0
  local cid=""
  local status=""

  cid="$(docker compose ps -q "${service}")"
  if [ -z "${cid}" ]; then
    echo "❌ Сервіс '${service}' не знайдено."
    return 1
  fi

  while [ "${elapsed}" -lt "${timeout}" ]; do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${cid}" 2>/dev/null || true)"

    case "${status}" in
      healthy|running)
        echo "✅ ${service}: ${status}"
        return 0
        ;;
      unhealthy|exited|dead)
        echo "❌ ${service}: ${status}"
        docker compose logs "${service}" --tail=120 || true
        return 1
        ;;
    esac

    sleep 3
    elapsed=$((elapsed + 3))
  done

  echo "❌ Таймаут очікування ${service} (${timeout}s), поточний статус: ${status}"
  docker compose logs "${service}" --tail=120 || true
  return 1
}

# === 4. Заливка SQL (Найважливіший крок) ===
SQL_FILE="$RESTORE_SOURCE_DIR/${DB_NAME}.sql"

if [ -f "$SQL_FILE" ]; then
  echo "📥 [4/7] Імпортую SQL дамп ($SQL_FILE)..."
  
  # Оскільки база свіжа (створена з .env), пароль root з .env точно підійде!
  # Спочатку дропаємо пусту базу, яку створив докер, щоб залити твою.
  docker compose exec -T db mariadb -u root -p"${DB_ROOT_PASS}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};"
  
  # Заливаємо дані
  cat "$SQL_FILE" | docker compose exec -T db mariadb -u root -p"${DB_ROOT_PASS}" "${DB_NAME}"
  
  echo "✅ SQL успішно імпортовано."
else
  echo "❌ КРИТИЧНО: SQL файл не знайдено! База буде пустою."
  exit 1
fi

# === 5. Запуск інфраструктури + перевірка ES ===
echo "🚀 [5/7] Запускаю інфраструктуру (es, rabbitmq, memcached)..."
docker compose up -d es rabbitmq memcached
wait_service_healthy es 240

# === 6. Запуск Koha ===
echo "🚀 [6/7] Запускаю Koha..."
docker compose up -d koha
wait_service_healthy koha 300
# У старих image koha-create може перезаписати memcached_servers на 127.0.0.1.
# Повторно нормалізуємо вже після старту Koha.
normalize_koha_conf_memcached

# === 7. Індексація ===
echo "⏳ Чекаємо 20 сек перед індексацією..."
sleep 20

TARGET_INSTANCE="${KOHA_INSTANCE:-library}"
echo "🔍 [7/7] Переіндексація..."
# Тепер таблиці точно є, помилки не буде
docker compose exec -T koha koha-elasticsearch --rebuild -d -v "$TARGET_INSTANCE"

echo "🎉 ВІДНОВЛЕННЯ УСПІШНЕ!"
