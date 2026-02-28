# Deploy Repo Architecture (Koha)

Дата: 2026-02-27

## 1) Призначення deploy-репо

Deploy-репо збирає готову систему з уже опублікованого образу Koha.
В цьому репо не повинно бути логіки збірки образу.

## 2) Головні правила

1. Тільки `image`, без `build`.
2. Жодних монтувань локальних runtime-скриптів у контейнер Koha.
3. SSOT для runtime-параметрів: `.env` + `docker-compose.yaml`.
4. Для продакшн бажано пінити образ по digest (`pinokew/koha@sha256:...`).
5. Секрети не комітити, зберігати в secret manager або окремому невідслідковуваному env-файлі.

## 3) Рекомендована структура репозиторію

```text
koha-deploy/
  docker-compose.yaml
  .env.example
  env/
    dev.env
    stage.env
    prod.env
  scripts/
    up.sh
    down.sh
    healthcheck.sh
    backup.sh
    restore.sh
    update-image.sh
  docs/
    RUNBOOK.md
    RELEASE.md
    BACKUP_RESTORE.md
```

## 4) Що зберігати в deploy-репо

1. Оркестрацію сервісів (`docker-compose.yaml`, профілі, мережі, томи).
2. Environment-конфіги для середовищ (`dev/stage/prod`).
3. Операційні скрипти: запуск, зупинка, backup/restore, smoke-check.
4. Release-процес: як оновлювати `KOHA_IMAGE` і як робити rollback.

## 5) Що не зберігати в deploy-репо

1. `Dockerfile` Koha і build-скрипти образу.
2. Runtime setup-пайплайн Koha (`scripts/koha-setup/*`) як source of truth.
3. Хардкод доменів, портів, шляхів, інстансів у скриптах.

## 6) Потік релізу

1. В image-репо публікується новий образ `pinokew/koha`.
2. В deploy-репо змінюється тільки `KOHA_IMAGE` (tag або digest).
3. Запускаються smoke-перевірки і healthchecks.
4. Деплой в потрібне середовище.
5. Rollback робиться поверненням попереднього `KOHA_IMAGE`.

## 7) Мінімальний набір env для deploy-репо

1. `KOHA_IMAGE` (`pinokew/koha:25.05` або `pinokew/koha@sha256:...`).
2. DB: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_ROOT_PASS`.
3. Koha: `KOHA_INSTANCE`, `KOHA_DOMAIN`, `KOHA_TIMEZONE`, `KOHA_OPAC_PORT`, `KOHA_INTRANET_PORT`.
4. RabbitMQ: `RABBITMQ_USER`, `RABBITMQ_PASS`.
5. Paths для томів: `VOL_DB_PATH`, `VOL_ES_PATH`, `VOL_KOHA_CONF`, `VOL_KOHA_DATA`, `VOL_KOHA_LOGS`.

## 8) Використання шаблону compose

У цьому репо підготовлено файл:
- `docker-compose.deploy.yaml`

Для deploy-репо:
1. Скопіювати його як `docker-compose.yaml`.
2. Створити `.env` на базі `.env.example`.
3. Запускати `docker compose --env-file env/prod.env up -d`.
