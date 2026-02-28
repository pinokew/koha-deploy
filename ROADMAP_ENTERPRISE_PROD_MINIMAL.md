Roadmap: Koha Production Go-Live (Minimal Must-Have)

Дата оновлення: 2026-02-28

Ціль: вивести сервіс у production без критичних ризиків безпеки, недоступності та невідновлюваності.

# 1) Обов'язковий мінімум до запуску (blocking)

# 1.1 Секрети та базова безпека

Є реєстр секретів (DB, RabbitMQ, Cloudflare, SMTP, API keys) з owner та періодом ротації.

Секрети відсутні в git-tracked файлах, .env не комітиться і не потрапляє в build context.

Усі потенційно скомпрометовані секрети ротовані, старі токени анульовані.

У CI увімкнений mandatory secret scan (PR/merge блокується при витоках).

DoD:

Немає нових витоків секретів у репозиторії.

Ротація завершена, runbook ротації задокументовано.

# 1.2 SDLC та захищений CI/CD

Для main увімкнені branch protection, required checks, заборона direct push.

Є CODEOWNERS для критичних зон (.github/workflows/*, Dockerfile, setup-скрипти).

Required checks: hadolint, shellcheck, trivy config, trivy image, secret scan.

GitHub Actions pinned по commit SHA для критичних uses:.

Мінімальні permissions у workflow/job та concurrency захист.

Прод деплой лише з immutable tag/digest (sha-*), без latest.

DoD:

Жоден PR не мержиться без review та повного набору security checks.

Публікуються лише перевірені immutable артефакти.

## 1.3 Supply-chain довіра артефактів

Для кожного прод-образу генерується SBOM.

Генерується provenance attestation.

Образ підписаний (наприклад, cosign), перевірка підпису є частиною деплою.
(Прагматична примітка: якщо впровадження Cosign затримує перший реліз, наявність SBOM та успішного Trivy сканування образу може бути тимчасово достатнім мінімумом, з обов'язковим додаванням підпису в найближчому спринті).

DoD:

Кожен deployable image має SBOM + provenance + валідний підпис.

## 1.4 Runtime hardening і мережеве ізолювання

Внутрішні сервіси (DB/ES/Memcached/RabbitMQ) не мають зовнішніх published ports.

Для контейнерів увімкнено щонайменше: no-new-privileges, cap_drop, обмеження ресурсів, restart policy, log rotation.

Гарантовано стабільні UID/GID для Persistent Volumes. Автоматизоване вирівнювання прав (chown) на koha_data, es_data, mysql_data при старті контейнерів.

Налаштовані healthchecks на всі критичні сервіси.

Трафік ззовні входить тільки через edge/proxy з TLS termination.

DoD:

Немає відкритих внутрішніх портів назовні.

Всі критичні сервіси мають робочі healthchecks і resource limits.

Права доступу на томах (volumes) залишаються консистентними після перезапуску/відновлення.

## 1.5 Спостережуваність (мінімум для прод) 

Є централізований збір логів.

Є базові метрики хоста/контейнерів/БД.

Є алерти на: падіння healthchecks, сплеск 5xx, low disk, провал backup/restore test.

Є короткі runbooks для P1/P2: DB down, queue backlog, disk full.

DoD:

Оператор отримує алерт до звернення користувачів у типових аварійних сценаріях.

## 1.6 DR/Backup + PITR (обов'язково)

Зафіксовані RPO/RTO.

Backup стратегія 3-2-1 з offsite та шифруванням.

Бекап включає не лише MariaDB, а й файлові томи (наприклад, завантажені документи/обкладинки/плагіни у koha_data).

Для MariaDB увімкнений binlog та реалізовано PITR до timestamp.

restore процес підтримує full restore + PITR + verify/dry-run.

Скрипт відновлення автоматично ініціює повну переіндексацію Elasticsearch (koha-es-indexer --rebuild) після restore бази (оскільки сам ES індекс не бекапиться).

Restore test проводиться регулярно (мінімум щомісяця) з фіксацією фактичного RTO/RPO.

DoD:

PITR перевірено практично, не лише декларативно.

Є підтверджений регулярний успішний restore-test, який відновлює і базу, і файли, і пошуковий індекс.

## 1.7 Управління доступом та Identity (SSO/OIDC Lockdown)

Єдиним джерелом правди (SSOT) для ідентифікації користувачів є Microsoft Entra ID (або інший OIDC провайдер).

Системні налаштування Koha для відновлення та зміни пароля (OpacResetPassword, OpacPasswordChange) примусово вимкнені.

Стандартна форма логіна прихована/заблокована, залишено лише backdoor-посилання для екстреного входу локального адміністратора на випадок падіння SSO.

DoD:

Користувач фізично не може змінити пароль в обхід SSO. Локальна реєстрація/логін для звичайних ролей повністю вимкнена.

## 2) Фінальний go-live gate

Прод запуск дозволений лише якщо одночасно виконані умови:

Identity: локальні бекдори закриті, OIDC є єдиним периметром автентифікації.

Security: секрети керуються централізовано, secret scan і ротація працюють.

Delivery: branch protection + required checks + immutable артефакти.

Supply-chain: SBOM/provenance/signing на прод-образи.

Runtime: ізоляція мережі, hardening, healthchecks, limits, permission align на томах.

Recovery: робочий backup/restore (DB + Files + ES index) та протестований PITR в межах RPO/RTO.

## 3) Додаткове після запуску (можна робити в production)

Performance tuning (MariaDB, Memcached, Plack), регулярні навантажувальні профілі.

Розширений SRE-шар: формальні SLI/SLO/error budget, постмортеми, глибша аналітика інцидентів.

SMTP hardening/polish (retry policy, розширений моніторинг доставки).

GA4/аналітика лише після затвердження privacy/consent політик.

Автоматизація release notes і додаткові процесні шаблони (RFC/issue templates), якщо ще не впроваджено.