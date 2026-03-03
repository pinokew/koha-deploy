# CHANGELOG Volume 04 (2026)

Анотація:
- Контекст: новий активний том після досягнення hard limit у `CHANGELOG_2026_VOL_03.md`.
- Зміст: продовження робіт по CI/CD, CD-deploy та операційній стабілізації прод-оточення.

---

## 2026-03-03

### 1) Ротація changelog-томів (`VOL_03` -> archived, `VOL_04` -> active)

- Виконано ротацію за політикою лімітів:
  - `CHANGELOG_2026_VOL_03.md` досяг `363` рядків (вище `hard limit: 350`);
  - створено новий активний том:
    - [CHANGELOG_2026_VOL_04.md](/home/pinokew/Koha/koha-deploy/CHANGELOGS/CHANGELOG_2026_VOL_04.md)

- Оновлено індекс томів:
  - [CHANGELOG.md](/home/pinokew/Koha/koha-deploy/CHANGELOG.md)
  - `VOL_04` позначено як `active`;
  - попередній `VOL_03` переведено у статус `archived`.

### 2) Спрощення `.github/workflows/ci-cd-checks.yml` (fast core checks)

- Мета:
  - скоротити тривалість CI та зменшити складність workflow;
  - залишити тільки базові критичні перевірки + CD-деплой.

- Оновлено:
  - [.github/workflows/ci-cd-checks.yml](/home/pinokew/Koha/koha-deploy/.github/workflows/ci-cd-checks.yml)

- Зміни:
  - workflow скорочено з ~`438` до `178` рядків;
  - прибрано важкий job `build-and-publish` (buildx/trivy image scan/sbom/push);
  - `ci-checks` залишено у fast-core наборі:
    - `hadolint`
    - `shellcheck`
    - `docker compose config -q` (`.env.example`)
    - `verify-env --example-only`
    - `check-secrets-hygiene.sh`
    - `check-internal-ports-policy.sh`
    - `gitleaks`
  - `cd-deploy` збережено, але тепер залежить тільки від `ci-checks`;
  - deploy-поведінка лишилась стабільною:
    - pull для registry-сервісів;
    - build для локальних `koha-local-*` сервісів;
    - `up -d --remove-orphans` + bootstrap + health-check.

- Перевірено:
  - `actionlint .github/workflows/ci-cd-checks.yml` (через `rhysd/actionlint:1.7.8`) — OK.

### 3) Повернено `Trivy Config Scan` у fast-core CI

- За результатами ревізії спрощеного workflow повернуто базовий security gate:
  - `Trivy config` (тільки config scan, без image scan).

- Оновлено:
  - [.github/workflows/ci-cd-checks.yml](/home/pinokew/Koha/koha-deploy/.github/workflows/ci-cd-checks.yml)
  - додано:
    - env `TRIVY_IMAGE` (pinned digest);
    - крок `Trivy config scan` у `ci-checks`:
      - `trivy config --skip-check-update --exit-code 1 --severity HIGH,CRITICAL /work`

- Перевірено:
  - `actionlint .github/workflows/ci-cd-checks.yml` (через `rhysd/actionlint:1.7.8`) — OK.

### 4) Tailscale warning fix: перехід на OAuth client (з fallback на authkey)

- Передумова:
  - у `cd-deploy` з'являлось попередження:
    - input `authkey` deprecated, рекомендовано OAuth client.

- Оновлено:
  - [.github/workflows/ci-cd-checks.yml](/home/pinokew/Koha/koha-deploy/.github/workflows/ci-cd-checks.yml)
  - додано підтримку OAuth client у Tailscale step:
    - `oauth-client-id` з `secrets.TS_OAUTH_CLIENT_ID`
    - `oauth-secret` з `secrets.TS_OAUTH_SECRET`
    - `tags: tag:ci`
  - залишено backward-compatible fallback:
    - якщо OAuth secrets не задані, використовується існуючий `TAILSCALE_AUTHKEY`.

- Результат:
  - workflow готовий до безпечної міграції на OAuth без ломання поточного деплою.

- Перевірено:
  - `actionlint .github/workflows/ci-cd-checks.yml` (через `rhysd/actionlint:1.7.8`) — OK.

### 5) CD hardening: fallback на `authkey` при runtime-failure OAuth

- Проблема:
  - у `cd-deploy` OAuth-підключення до Tailscale могло падати runtime-помилкою (`tailscale up`, `sudo failed`),
    що блокувало весь деплой навіть за наявного робочого `TAILSCALE_AUTHKEY`.

- Виправлено:
  - у [.github/workflows/ci-cd-checks.yml](/home/pinokew/Koha/koha-deploy/.github/workflows/ci-cd-checks.yml):
    - крок `Connect to Tailscale (OAuth client)` отримав `id: tailscale_oauth` + `continue-on-error: true`;
    - крок `Connect to Tailscale (authkey fallback)` тепер запускається також коли
      `steps.tailscale_oauth.outcome == 'failure'`.

- Результат:
  - деплой не блокується через тимчасово некоректний OAuth-конфіг;
  - за наявності `TAILSCALE_AUTHKEY` виконується автоматичний fallback.

- Перевірено:
  - `actionlint .github/workflows/ci-cd-checks.yml` (через `rhysd/actionlint:1.7.8`) — OK.
