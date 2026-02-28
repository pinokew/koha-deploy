# CHANGELOG

## 2026-02-28

### 1) Оновлення образів і compose (production runtime)

- Оновлено `KOHA_IMAGE` на новий digest з фіксом `MEMCACHED_SERVERS`:
  - `pinokew/koha@sha256:ca281dc3eabcb371ebb067e3e4120b9cc7850535196ce295f12c10334f808900`
  - Файл: [.env](/home/pinokew/Koha/koha-deploy/.env:95)

- `docker-compose.yaml` переведено на кастомну збірку сервісів `es`, `rabbitmq`, `memcached`:
  - `rabbitmq`: `build` з `RABBITMQ_VERSION`, image `koha-local-rabbitmq:*`
  - `es`: `build` з `ES_VERSION`, image `koha-local-es:*`
  - `memcached`: `build` з `MEMCACHED_VERSION`, image `koha-local-memcached:*`
  - Файл: [docker-compose.yaml](/home/pinokew/Koha/koha-deploy/docker-compose.yaml:91)

- Залишено env-параметризацію портів і healthcheck для `koha`:
  - порти беруться з `KOHA_OPAC_PORT` / `KOHA_INTRANET_PORT`
  - healthcheck: `wget localhost:${KOHA_INTRANET_PORT}`
  - Файл: [docker-compose.yaml](/home/pinokew/Koha/koha-deploy/docker-compose.yaml:5)

### 2) Dockerfile зміни під плагіни та версіонування з env

- Elasticsearch:
  - додано `ARG ES_VERSION`
  - `FROM docker.io/elasticsearch:${ES_VERSION}`
  - встановлення `analysis-icu` через `--batch`
  - Файл: [elasticsearch/Dockerfile](/home/pinokew/Koha/koha-deploy/elasticsearch/Dockerfile:1)

- RabbitMQ:
  - додано `ARG RABBITMQ_VERSION`
  - `FROM docker.io/rabbitmq:${RABBITMQ_VERSION}`
  - офлайн-увімкнення `rabbitmq_stomp` і `rabbitmq_web_stomp`
  - Файл: [rabbitmq/Dockerfile](/home/pinokew/Koha/koha-deploy/rabbitmq/Dockerfile:1)

- Memcached:
  - додано окремий Dockerfile
  - `ARG MEMCACHED_VERSION`
  - `FROM docker.io/memcached:${MEMCACHED_VERSION}`
  - Файл: [memcached/Dockerfile](/home/pinokew/Koha/koha-deploy/memcached/Dockerfile:1)

### 3) Env-модель для side-сервісів

- У `.env` додано/оновлено:
  - `ES_VERSION`, `RABBITMQ_VERSION`, `MEMCACHED_VERSION`
  - `ES_IMAGE=koha-local-es:8.19.6`
  - `RABBITMQ_IMAGE=koha-local-rabbitmq:3-management`
  - `MEMCACHED_IMAGE=koha-local-memcached:1.6`
  - Файл: [.env](/home/pinokew/Koha/koha-deploy/.env:97)

- У `.env.example` синхронізовано приклади:
  - додано `*_VERSION` та локальні `*_IMAGE` для built-образів
  - Файл: [.env.example](/home/pinokew/Koha/koha-deploy/.env.example:45)

### 4) Restore-пайплайн (стабілізація після інцидентів)

- Оновлено `restore.sh`:
  - введено `RESTORE_ES_DATA` (дефолт `false`)
  - за замовчуванням **не** відновлюється сирий `es_data.tar.gz`, ES-том очищується і далі робиться rebuild
  - додано `wait_service_healthy()` для контрольованого старту `es` і `koha`
  - виправлено очистку томів на безпечний `find ... -mindepth 1`
  - права для `koha_config`: `root:${KOHA_CONF_GID}`, dirs `2775`, files `640`
  - додано `normalize_koha_conf_memcached()` для нормалізації `memcached_servers` у `koha-conf.xml`
  - повторна нормалізація `memcached_servers` після старту `koha` (щоб перекривати можливий перезапис під час `koha-create`)
  - Файл: [restore.sh](/home/pinokew/Koha/koha-deploy/restore.sh:14)

### 5) Перевірки після розгортання (факт)

- Після rebuild/перезапуску:
  - `koha` image: новий digest `ca281d...`
  - `es` image: `koha-local-es:8.19.6`
  - `rabbitmq` image: `koha-local-rabbitmq:3-management`
  - `memcached` image: `koha-local-memcached:1.6`

- Runtime верифікація:
  - ES plugin list: `analysis-icu` присутній
  - RabbitMQ plugins: `rabbitmq_stomp`, `rabbitmq_web_stomp` увімкнені
  - `koha-conf.xml`: `<memcached_servers>memcached:11211</memcached_servers>`
  - `koha-elasticsearch --rebuild -v library` відпрацював
  - індекси ES після rebuild:
    - `koha_library_biblios`: `count=14`
    - `koha_library_authorities`: `count=0` (у БД `auth_header=0`)

### 6) Поетапне відновлення, що було протестовано

- Прогнано шарове відновлення:
  - `DB only` (`koha_library.sql`) -> `koha healthy`
  - `DB + koha_config` -> `koha healthy`
  - окремо `koha_data.tar.gz` -> `koha healthy`

- Висновки:
  - проблема відсутності записів у каталозі була не у втраті DB-даних, а у зламаному ES-шарі (плагіни/індекси).
  - проблема memcached warning була у runtime-конфігу `koha-conf.xml` з `127.0.0.1:11211`.
