# mind_at_play MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Превратить `nback` в `mind_at_play`: короткие тесты, отметка состояния перед ними, описательная инфографика «я против меня», шаблонное добавление игр.

**Architecture:** Стандартный Rails 8.1 монолит. Игра это стратегия + партиал + Stimulus-контроллер + тест, реестр строится по файлам. Язык в URL-префиксе, темы через токены Tailwind, почта хранится как HMAC.

**Tech Stack:** Ruby 3.4.4, Rails 8.1, PostgreSQL (jsonb), Stimulus + importmap, Tailwind 4, Minitest, solid_queue. Новые зависимости: `commonmarker` (статьи), позже `rails-i18n`.

**Spec:** `/home/denio/my_prj/self_test/nback/docs/superpowers/specs/2026-11-22-self-observation-mvp-design.md`

## Теги сложности

- **[CHEAP]**: исполнитель выполняет по тексту, решений не принимает. Один файл или одна фича.
- **[EXPENSIVE]**: безопасность, сложная логика или рефакторинг. Выполнять сильной моделью или звать автора плана.
- Каждая задача заканчивается зелёным `bin/rails test` и коммитом. Если тест красный, исполнитель останавливается и не чинит чужое.

## Global Constraints

- Ruby 3.4.4, Rails 8.1. Стиль кода как в репозитории, `bin/rubocop` проходит.
- Разработка через TDD: сначала падающий тест, затем минимальный код, затем рефакторинг. Тесты Minitest, фикстуры в `test/fixtures`, команда `bin/rails test`.
- Везде PostgreSQL (development, test, production). SQLite не используется. Сервер на 127.0.0.1:5432 запущен.
- Секреты только в `.env` (в git не попадает, см. `/.env*` в `.gitignore`). В git лежит `.env.example` без значений. Код читает их через `ENV`.
- Комментарии в коде на английском. Документация (README, `docs/`) на русском. Стиль Ruby и Rails по `bin/rubocop` и конвенциям Rails.
- Ветка `add-psycophis-test`. Пользователь разрешил менять и коммитить свои несохранённые файлы (`db/seeds.rb`, `docs/plan_cline.md`, файлы adaptive-теста). Коммитить по путям (`git add <путь>`), не `git add -A`.
- Журнал: после каждого готового коммита в `work_log.md` добавляется строка `- <дата время коммита> <одно предложение>`. Строка попадает в следующий коммит.
- Выполнение: этапы запускаются по одному, начало каждого этапа согласуется с пользователем. Одновременно работает не больше одного субагента, параллельный запуск нескольких согласуется отдельно.
- Никаких оценочных слов в интерфейсе («хуже», «лучше», «норма», «усталость»), порогов, норм, сравнения с другими, общего балла.
- Строк на естественном языке нет в `.erb`, `.rb` (кроме `config/locales`) и JS. Всё через I18n.
- Игры и шаблоны используют только токены цвета (`bg-surface`, `text-ink`, `bg-accent`, `bg-danger`, `text-stimulus-red`), не палитровые классы и не hex.
- Почта в БД только как `email_digest`. Письма только `deliver_now`.
- Таблицу `sessions` и `rolify` не трогать.
- Порог медианы на графике: 5 точек. Попыток не больше 500. Удаление аккаунта стирает прохождения и отметки.
- Пользовательский ввод не попадает в `constantize`, `send`, `html_safe`, сырой SQL.

## Review Focus

- Чужой или повторный `submit_result` отклоняется (владелец и однократность).
- Чужая страница `/:locale/game_sessions/:id` даёт 404.
- `/xx/games` даёт 404, ссылки в письмах содержат `locale`.
- После удаления аккаунта нет строк в `game_sessions` и `check_ins`.
- `trials` от клиента: лишние ключи отброшены, больше 500 попыток отклонено, метрики считает сервер.
- Админский Markdown с `<script>` и `javascript:` не выполняется.
- Форма обратной связи: лимит запросов, поле-ловушка, длина.

## Каркас проекта

### Схема БД (итог после всех миграций)

| Таблица | Поля |
|---|---|
| `users` | `nickname` string not null, уникальный индекс по `lower(nickname)`; `email_digest` string not null, unique; `password_digest`; `gender` string null; `age_decade` integer null; `confirmed_at` datetime null; `active` (есть); timestamps. Колонка `email_address` удаляется. |
| `games` | есть `name`, `description`, `system_name` (unique), `active`. Добавить `category` string not null, индекс. |
| `game_sessions` | есть `game_id`, `user_id`, `played_at`, `result` jsonb, `setup_game` jsonb. Добавить `check_in_id` references null FK, `metric` float null, `metric_secondary` float null. |
| `check_ins` | `user_id` references not null FK; `sleep_hours` decimal(3,1) null; `day_phase` string null; `flags` jsonb not null default `{}`; timestamps. |
| `feedback_messages` | `body` text not null; `kind` string not null; `locale` string not null; `created_at`. Без `user_id` и IP. |
| `articles` | `slug` string not null unique; `kind` string not null default `article`, индекс; `published_at` datetime null; timestamps. |
| `article_translations` | `article_id` references not null FK; `locale` string not null; `title` string not null; `body` text not null; unique `(article_id, locale)`; timestamps. |

### Модели

AR: `User`, `Game`, `GameSession`, `CheckIn`, `FeedbackMessage`, `Article`, `ArticleTranslation` (плюс существующие `Session`, `Role`, `Current`). Не AR: `Games::BaseStrategy` и 4 стратегии, `Games::Registry`, `Games::Blocks` (блоки разбора), `Insights::Series` (данные графика).

### Роуты

```ruby
root "root#show"                                   # редирект по Accept-Language, вне scope
get "up" => "rails/health#show"
scope "/:locale", locale: /#{I18n.available_locales.join("|")}/ do
  resource :session
  resources :registrations, only: %i[new create]
  resources :email_confirmations, only: :show, param: :token
  resources :passwords, param: :token
  resources :users, only: %i[show edit update destroy]
  resources :games, only: %i[index show] do
    resources :game_sessions, only: %i[new create] do
      member { get :play; post :submit_result }
    end
  end
  resources :game_sessions, only: :show
  resources :insights, only: %i[index show]        # show: :id это game id
  get "news", to: "articles#index", defaults: { kind: "news" }
  resources :articles, only: %i[index show], param: :slug
  resources :feedback_messages, only: %i[new create], path: "feedback"
  get "about", to: "pages#about"
  namespace :admin do
    resources :users
    resources :articles, except: :show
    resources :feedback_messages, only: %i[index destroy]
  end
end
```

### Контроллеры

Новые: `RootController`, `EmailConfirmationsController`, `InsightsController`, `PagesController`, `FeedbackMessagesController`, `ArticlesController`, `Admin::ArticlesController`, `Admin::FeedbackMessagesController`. Меняются: `ApplicationController`, `SessionsController`, `RegistrationsController`, `PasswordsController`, `UsersController`, `GamesController`, `GameSessionsController`.

### Вьюхи

`layouts/application` (lang, тема, шапка с переключателями языка и темы), `games/index` (секции по категориям), `games/show`, `game_sessions/new` (форма отметки), `game_sessions/show` (разбор), 4 партиала `games/_<name>`, `insights/index|show`, `registrations/new`, `sessions/new`, `passwords/*`, `users/show`, `feedback_messages/new`, `pages/about`, `articles/index|show`, `admin/articles/*`, `admin/feedback_messages/index`.

## Этапы

0. Подготовка и переименование
1. Контракт игр, реестр, генератор, защита `submit_result`
2. Локализация и языковой префикс
3. Темы оформления
4. Аккаунты
5. Отметка состояния
6. Попытки (`trials`) и разбор прохождения
7. Инфографика
8. Обратная связь, About, фоновые задачи
9. Статьи и админка


---

## Этап 0. Подготовка и переименование

### Task 0.1 [CHEAP]: переименовать проект в `mind_at_play`

**Files:** `config/application.rb`, `config/database.yml`, `config/deploy.yml`, `Dockerfile`, `app/views/layouts/application.html.erb`, `app/views/pwa/manifest.json.erb`

Не менять: `app/models/games/nback_strategy.rb`, `app/views/games/_nback.html.erb`, `games/nback.svg`, `@keyframes nbackPop`, `db/seeds.rb`. Это игра n-back, а не проект.

- [ ] **Step 1:** `bin/rails test` проходит (20 прогонов, 0 ошибок). Если нет, остановиться.
- [ ] **Step 2:** В `config/application.rb` заменить `module Nback` на `module MindAtPlay`.
- [ ] **Step 3:** В `config/database.yml` заменить `nback_dev` на `mind_at_play_dev`, `nback_test` на `mind_at_play_test`.
- [ ] **Step 4:** В `config/deploy.yml` заменить `service` и `image` на `mind-at-play`, том `nback_storage` на `mind_at_play_storage`, комментарий `nback-db` на `mind-at-play-db`. В `Dockerfile` заменить `nback` на `mind-at-play` в комментариях.
- [ ] **Step 5:** В `layouts/application.html.erb` заменить `"Nback"` на `"MindAtPlay"` (title и `application-name`). В `pwa/manifest.json.erb` поле `name` на `"MindAtPlay"`, `description` на `"MindAtPlay."`.
- [ ] **Step 6:** `grep -rniE 'nback' config Dockerfile app/views/layouts app/views/pwa` ничего не выводит.
- [ ] **Step 7:** `bin/rails db:create db:schema:load` и `RAILS_ENV=test bin/rails db:create db:schema:load`. Старые базы `nback_dev` и `nback_test` остаются в PostgreSQL, удаляет их владелец.
- [ ] **Step 8:** `bin/rails test` проходит. Коммит: `git add config Dockerfile app/views/layouts app/views/pwa && git commit -m "Rename project to MindAtPlay"`.

### Task 0.2 [CHEAP]: секреты в `.env`, PostgreSQL во всех окружениях

**Files:** `Gemfile`, `Gemfile.lock`, `config/database.yml`, `.env.example`, `README.md`

Пароль к dev-базе лежит в git с первого коммита. Правка файла историю не чистит. Смену самого пароля делает владелец, это вне плана.

- [ ] **Step 1:** В `Gemfile` в группу `:development, :test` добавить `gem "dotenv-rails"` (в `Gemfile.lock` уже есть `dotenv` как зависимость kamal, `dotenv-rails` нет). `bundle install`.
- [ ] **Step 2:** В `config/database.yml` значения `host`, `port`, `username`, `password` и имя базы читать через `ENV.fetch` (`DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, имена баз `mind_at_play_dev`, `mind_at_play_test`). Для production заменить все четыре SQLite-базы (`primary`, `cache`, `queue`, `cable`) на PostgreSQL: адрес и данные через `DATABASE_URL`, отдельные базы `mind_at_play_production_cache`, `_queue`, `_cable` с теми же `migrations_paths`.
- [ ] **Step 3:** Создать `.env.example` (имена переменных без значений: `DATABASE_*`, `EMAIL_PEPPER`, `RAILS_MASTER_KEY`) и локальный `.env` с реальными значениями. `.env` уже закрыт в `.gitignore` (`/.env*`), поэтому в `.gitignore` добавить исключение `!/.env.example`.
- [ ] **Step 4:** В `README.md` раздел на русском: как заполнить `.env`, что потеря `EMAIL_PEPPER` ломает сброс пароля.
- [ ] **Step 5:** `git check-ignore .env` выводит `.env`, `git status` не показывает `.env`. `bin/rails db:prepare` и `bin/rails test` проходят. Коммит: `git add Gemfile Gemfile.lock config/database.yml .env.example .gitignore README.md && git commit -m "Read secrets from .env and use PostgreSQL everywhere"`.


---

## Этап 1. Контракт игр, реестр, генератор, защита `submit_result`

Идея: новая игра это новые файлы, существующие не правятся. Контракт совпадает с разделом «Добавление игры по шаблону» спецификации.

Уточнения к спецификации, принятые планом:
- Ключи попытки: базовые `rt_ms`, `correct`, `phase` плюс `extra_trial_keys` стратегии (по умолчанию пусто).
- Каждая стратегия реализует `sample_payload(setup)`: корректный клиентский результат для тестов. Контрактный тест берёт его.
- На этапе 1 стратегии работают с текущими форматами результата (итоги, а не попытки). Метрики, которым нужны попытки (`stroop_test`, `adaptive_reaction_test`), пока возвращают `nil`. Переход на `trials` это этап 6.

### Task 1.1 [EXPENSIVE]: `Games::BaseStrategy` и `Games::CATEGORIES`

**Files:**
- Create: `/home/denio/my_prj/self_test/nback/app/models/games/categories.rb`
- Rewrite: `/home/denio/my_prj/self_test/nback/app/models/games/base_strategy.rb`
- Create: `/home/denio/my_prj/self_test/nback/test/models/games/base_strategy_test.rb`

**Interfaces:**
```ruby
module Games
  CATEGORIES = %w[perception executive memory metacognition vigilance].freeze
end

class Games::BaseStrategy
  class InvalidResult < StandardError; end
  MAX_TRIALS = 500
  BASE_TRIAL_KEYS = %i[rt_ms correct phase].freeze

  # Метаданные. В базовом классе: raise NotImplementedError.
  def category; end          # ключ из Games::CATEGORIES
  def spec_version; end      # "<system_name>@<n>"
  def setup_game; end        # Hash
  def permitted_result_keys; end   # Array<Symbol>, скалярные ключи верхнего уровня
  def primary_unit; end      # "ms" | "%" | "count"
  def sample_payload(setup); end   # корректный результат для тестов

  # Значения по умолчанию.
  def article_slug = nil
  def extra_trial_keys = []
  def phases = []
  def validate_result(setup, payload) = true
  def score(setup, payload) = {}
  def primary_metric(result) = nil
  def secondary_metric(result) = nil
  def secondary_unit = nil
  def system_name = self.class.name.demodulize.delete_suffix("Strategy").underscore

  def permit(raw)                   # -> Hash со строковыми ключами
  def handle_result(setup, raw)     # permit -> проверка числа попыток -> validate_result -> score; бросает InvalidResult
end
```

- [ ] **Step 1:** Написать `base_strategy_test.rb` с `FakeStrategy < Games::BaseStrategy` внутри файла. Тесты: `permit drops unknown keys`, `permit drops unknown trial keys`, `permit keeps extra_trial_keys`, `permit returns empty hash for non-hash input`, `handle_result raises InvalidResult when validate_result is false`, `handle_result raises InvalidResult for more than 500 trials`, `handle_result merges score into permitted payload`, `system_name is derived from class name`, `base class raises NotImplementedError for category, spec_version, setup_game, permitted_result_keys, primary_unit, sample_payload`.
- [ ] **Step 2:** `bin/rails test test/models/games/base_strategy_test.rb` падает.
- [ ] **Step 3:** Реализовать. `permit` принимает `ActionController::Parameters` или `Hash`. Для `Parameters` использовать `permit(*scalar_keys, trials: trial_keys).to_h`. Остальные типы дают `{}`. `handle_result` возвращает Hash со строковыми ключами.
- [ ] **Step 4:** `bin/rails test` целиком зелёный. Коммит: `git add app/models/games test/models/games && git commit -m "Add game strategy contract"`.


### Task 1.2 [CHEAP]: колонки `games.category` и метрики в `game_sessions`

**Files:**
- Create: `db/migrate/<timestamp>_add_category_to_games.rb`, `db/migrate/<timestamp>_add_metrics_to_game_sessions.rb`
- Modify: `app/models/game.rb`, `app/models/game_session.rb`, `test/fixtures/games.yml`, `test/models/game_test.rb`

**Interfaces:**
- `games.category` string, `null: false`, индекс. В миграции колонка добавляется с `default: "executive"`, затем default снимается (`change_column_default :games, :category, from: "executive", to: nil`), так как в таблице уже есть строки.
- `game_sessions.metric` float, `metric_secondary` float, оба null.
- `Game` валидирует `category` по `Games::CATEGORIES`.

- [ ] **Step 1:** В `test/models/game_test.rb` написать тесты `valid with known category` и `invalid with unknown category`. В `test/fixtures/games.yml` добавить `category: vigilance` обеим записям.
- [ ] **Step 2:** Тесты падают. Создать миграции, `bin/rails db:migrate`, `RAILS_ENV=test bin/rails db:migrate`.
- [ ] **Step 3:** Добавить в `Game` `validates :category, inclusion: { in: Games::CATEGORIES }`.
- [ ] **Step 4:** `bin/rails test` зелёный. Проверить, что `db/schema.rb` изменился только этими колонками. Коммит: `git add db app/models test && git commit -m "Add game category and session metric columns"`.

### Task 1.3 [EXPENSIVE]: `Games::Registry`

**Files:**
- Create: `app/models/games/registry.rb`, `test/models/games/registry_test.rb`

**Interfaces:**
```ruby
module Games::Registry
  def self.system_names -> Array<String>    # из имён файлов app/models/games/*_strategy.rb, кроме base_strategy
  def self.strategy_for(system_name) -> Games::BaseStrategy   # ArgumentError, если имени нет в system_names
  def self.sync! -> void   # создаёт или обновляет Game по system_name
end
```

- `strategy_for` сверяет имя со списком из `system_names` до `constantize`. Строка пользователя в `constantize` не попадает.
- `sync!` для каждой стратегии: `Game.find_or_initialize_by(system_name:)`, обновляет `category` и `name`/`description` (на этапе 1 берутся из `system_name.humanize` и текста по умолчанию, на этапе 2 заменяются переводами `default_locale`). `active` у существующих записей не меняет, у новых `true`.

- Метод `sync!` реализуется здесь, но его тесты пишутся в Task 1.4, когда у стратегий появится `category`. Моки не используются, тесты работают на реальных четырёх стратегиях.

- [ ] **Step 1:** Тесты: `system_names includes existing games and excludes base`, `strategy_for returns instance`, `strategy_for raises ArgumentError for unknown name`, `strategy_for raises ArgumentError for "../../etc"`.
- [ ] **Step 2:** Тесты падают. Реализовать `system_names`, `strategy_for`, `sync!`.
- [ ] **Step 3:** `bin/rails test` зелёный. Коммит: `git add app/models/games test/models/games && git commit -m "Add game registry"`.

### Task 1.4 [EXPENSIVE]: перевод четырёх стратегий на контракт

**Files:** `app/models/games/{reaction_time,nback,stroop_test,adaptive_reaction_test}_strategy.rb`, `app/models/game.rb`, `test/models/games/<name>_strategy_test.rb` (4 файла)

Значения по стратегиям:

| Игра | `category` | `spec_version` | `permitted_result_keys` | `primary_unit` | `primary_metric` | `secondary_metric` |
|---|---|---|---|---|---|---|
| reaction_time | vigilance | `reaction_time@1` | `reactions`, `trials`, `false_starts`, `mean_rt`, `min_rt`, `max_rt` | `ms` | медиана ненулевых `reactions` | число `nil` в `reactions` (`count`) |
| nback | memory | `nback@1` | `correct`, `errors`, `total_trials` | `%` | `correct / total_trials * 100` | `errors` (`count`) |
| stroop_test | executive | `stroop_test@1` | `correct`, `errors`, `total_trials` | `ms` | `nil` (до этапа 6) | `errors` (`count`) |
| adaptive_reaction_test | executive | `adaptive_reaction_test@1` | как у reaction_time | `ms` | как у reaction_time | как у reaction_time |

- `Game#game_strategy` использует `Games::Registry.strategy_for(system_name)`. Делегирование: `delegate :setup_game, to: :game_strategy`. Метод `handle_result` в `Game` больше не делегируется: `GameSession` вызывает стратегию сам (Task 1.5).
- `validate_result`: числа в диапазоне (`correct`, `errors` от 0 до `total_trials`, `total_trials` равен длине сохранённой последовательности из `setup`; `reactions` длиной не больше 500, значения `nil` или от 0 до 60000). Для `nback` и `stroop_test` сервер считает `correct`/`errors` заново только после этапа 6, на этапе 1 проверяются диапазоны.
- Из `setup_game` убрать `locales:` (`ReactionTimeStrategy` сейчас кладёт туда «translation missing»). Партиал и JS это пока не читают, поэтому изменение безопасно. Проверить: `grep -rn "locales" app`.
- `sample_payload(setup)`: по одному корректному результату на игру.

- [ ] **Step 1:** Для каждой игры тест: `primary_metric` и `secondary_metric` на `sample_payload`, `validate_result` true на нём и false на мусоре (отрицательное число, строка вместо числа, `correct > total_trials`), `permit` отбрасывает лишний ключ. В `registry_test.rb` добавить тесты `sync! creates missing games`, `sync! is idempotent`, `sync! does not change active on existing game`.
- [ ] **Step 2:** Тесты падают. Перевести стратегии.
- [ ] **Step 3:** `bin/rails test` зелёный. Коммит: `git add app test && git commit -m "Move strategies to the new contract"` (файлы adaptive-теста тоже добавляются в коммит, владелец разрешил).


### Task 1.5 [EXPENSIVE]: защита `submit_result`

**Files:** `app/controllers/game_sessions_controller.rb`, `app/models/game_session.rb`, `test/controllers/game_sessions_controller_test.rb`, `test/fixtures/game_sessions.yml`

Поведение:
- `create`: игра ищется через `Game.where(active: true).find(params[:game_id])`. Сессия принадлежит `Current.user` (если он есть).
- `play` и `submit_result` находят сессию только через `GameSession.find(params[:id])` с проверкой `session.game_id == params[:game_id].to_i`, иначе 404.
- Если у сессии есть `user_id`, действовать может только этот пользователь, иначе 404. Анонимная сессия (`user_id` nil) доступна по id всем, как сейчас (id не секрет, но это сессия без аккаунта и без истории).
- Повторная отправка: если `played_at` уже стоит, ответ 409 с телом `{error: "already_submitted"}`.
- `submit_result` вызывает `strategy.handle_result(session.setup_game, params[:result])`. `InvalidResult` даёт 422. Затем в одной записи сохраняются `played_at`, `result`, `metric = primary_metric(result)`, `metric_secondary = secondary_metric(result)`.
- Метод `get_game_session_with_game` становится `private`.

- [ ] **Step 1:** Тесты: `owner can submit once`, `second submit returns 409 and keeps first result`, `other user gets 404`, `anonymous cannot submit to a session that has a user`, `unknown keys are dropped from stored result`, `invalid result returns 422 and stores nothing`, `game_id mismatch returns 404`, `metric and metric_secondary are stored`, `inactive game cannot be started`. Тест CSRF не нужен, он включён по умолчанию.
- [ ] **Step 2:** Тесты падают. Реализовать.
- [ ] **Step 3:** `bin/rails test` зелёный. Коммит: `git add app test && git commit -m "Protect submit_result"`.

### Task 1.6 [CHEAP]: общий контрактный тест

**Files:** Create: `test/models/games/strategy_contract_test.rb`

Для каждого `system_name` из `Games::Registry.system_names` проверяется:
- `category` входит в `Games::CATEGORIES`;
- `spec_version` совпадает с `/\A#{system_name}@\d+\z/`;
- `primary_unit` из `%w[ms % count]`;
- `setup_game` возвращает Hash;
- `validate_result(setup, sample_payload(setup))` true, `primary_metric(sample)` число, при ненулевом `secondary_unit` `secondary_metric(sample)` тоже число;
- `handle_result(setup, { "bogus" => 1 })` бросает `InvalidResult` или возвращает Hash без ключа `bogus`;
- на этапе 2 добавляется проверка ключей `games.<name>.title`, `.description`, `.ui` во всех языках, на этапе 3 нет дополнительных проверок (тему проверяет `theme_lint_test`).

- [ ] **Step 1:** Написать тест по списку выше. `bin/rails test test/models/games/strategy_contract_test.rb` зелёный (4 стратегии).
- [ ] **Step 2:** Коммит: `git add test/models/games && git commit -m "Add strategy contract test"`.

### Task 1.7 [CHEAP]: seeds и список игр

**Files:** `db/seeds.rb`, `app/controllers/games_controller.rb`, `test/controllers/games_controller_test.rb`

`db/seeds.rb` содержит несохранённую правку владельца (запись adaptive_reaction_test). Владелец разрешил менять файл, правка заменяется вызовом реестра, запись adaptive появляется через `Games::Registry.sync!`.

- [ ] **Step 1:** Тест: `index lists only active games`. Тест падает.
- [ ] **Step 2:** В `GamesController#index` заменить `Game.all` на `Game.where(active: true).order(:category, :system_name)`. `show` ищет через `Game.where(active: true).find`.
- [ ] **Step 3:** В `db/seeds.rb` оставить одну строку `Games::Registry.sync!`. Проверить: `bin/rails db:seed` дважды подряд, затем `Game.count` равен 4.
- [ ] **Step 4:** `bin/rails test` зелёный. Коммит: `git add db/seeds.rb app/controllers/games_controller.rb test && git commit -m "Sync games from registry in seeds"`.

### Task 1.8 [EXPENSIVE]: генератор `bin/rails g game <name> --category=<ключ>`

**Files:**
- Create: `lib/generators/game/game_generator.rb`, `lib/generators/game/templates/strategy.rb.tt`, `partial.html.erb.tt`, `controller.js.tt`, `strategy_test.rb.tt`, `test/generators/game_generator_test.rb`

Что создаёт генератор для `<name>`: `app/models/games/<name>_strategy.rb`, `app/views/games/_<name>.html.erb`, `app/javascript/controllers/games/<name>_controller.js`, `test/models/games/<name>_strategy_test.rb`. Заготовка стратегии содержит все методы контракта с `category` из опции, `spec_version "<name>@1"`, `article_slug = nil`, `primary_unit "ms"`, `sample_payload` с пустым результатом и комментарием `# TODO`. Файл переводов добавляется на этапе 2 (Task 2.9), в этом задании его нет.

- [ ] **Step 1:** Тест через `Rails::Generators::TestCase` (`require "rails/generators/test_case"`): `creates four files`, `rejects name that is not snake_case`, `rejects unknown category`, `does not overwrite existing strategy` (повторный запуск не затирает файл).
- [ ] **Step 2:** Реализовать. Имя валидируется регэкспом `/\A[a-z][a-z0-9_]*\z/`, категория по `Games::CATEGORIES`.
- [ ] **Step 3:** Ручная проверка: `bin/rails g game demo_game --category=perception`, затем `bin/rails test test/models/games` (заготовка проходит контрактный тест после правки `sample_payload` на корректный), затем `bin/rails d game demo_game` убирает файлы. Коммит только после `d`.
- [ ] **Step 4:** `bin/rails test` зелёный. Коммит: `git add lib test/generators && git commit -m "Add game generator"`.


---

## Этап 2. Локализация и языковой префикс

Порядок важен: сначала маршруты и конфигурация (2.1), потом вынос строк по областям (2.2 до 2.8), потом инструменты проверки (2.9 до 2.11).

### Task 2.1 [EXPENSIVE]: i18n-конфиг, префикс `/:locale`, корневой редирект

**Files:** `config/application.rb`, `config/environments/{development,test}.rb`, `config/routes.rb`, `app/controllers/application_controller.rb`, `app/controllers/root_controller.rb`, `config/locales/en.yml` (удалить пример `hello`), `test/controllers/locale_routing_test.rb`

Поведение:
- `config.i18n.available_locales = %i[en ru]`, `default_locale = :en`, `fallbacks = [:en]`, `load_path += Dir[Rails.root.join("config/locales/**/*.yml")]`. В development и test `config.i18n.raise_on_missing_translations = true`.
- Маршруты как в разделе «Роуты» каркаса. Вне scope только `GET /` (`root#show`) и `GET /up`.
- `ApplicationController`: `around_action :switch_locale` (`I18n.with_locale(params[:locale] || I18n.default_locale)`), `default_url_options` возвращает `{ locale: I18n.locale }`.
- `RootController#show` разбирает `request.env["HTTP_ACCEPT_LANGUAGE"]`: берёт первый тег до `-` или `;`, сверяет с `I18n.available_locales.map(&:to_s)`, иначе `default_locale`. `redirect_to games_path(locale: выбранный)`. Строку в `I18n.locale` напрямую не ставить.
- Админ-контроллеры, `RegistrationsController` и остальные получают префикс автоматически. Хелперы `*_path` в шаблонах не меняются.

- [ ] **Step 1:** Тесты: `root redirects by Accept-Language ru`, `root redirects to en for unknown language`, `root redirects to en without header`, `/xx/games returns 404`, `/ru/games sets I18n.locale to ru` (проверка через `<html lang>` после Task 2.2 или через `assert_equal :ru` в `around`-тесте), `/up works without prefix`, `Accept-Language with garbage "'; DROP"` даёт редирект на `/en`.
- [ ] **Step 2:** Тесты падают. Реализовать. Существующие контроллерные тесты обновить: `games_url` теперь требует `locale` и подставляется автоматически через `default_url_options` только внутри запроса, поэтому в тестах использовать `games_url(locale: :en)` или добавить в `ActionDispatch::IntegrationTest` `setup { default_url_options[:locale] = :en }` в `test_helper.rb`.
- [ ] **Step 3:** `bin/rails test` зелёный. Коммит: `git add config app test && git commit -m "Add locale URL prefix"`.

### Task 2.2 [CHEAP]: `lang` в layout, переключатель языка, названия языков

**Files:** `app/views/layouts/application.html.erb`, `app/views/layouts/_nav_header.html.erb`, `config/locales/languages.en.yml`, `languages.ru.yml`, `test/controllers/locale_routing_test.rb`

- В `<html>` добавить `lang="<%= I18n.locale %>"`.
- В `_nav_header` ссылки переключателя: `I18n.available_locales.each`, `link_to t("languages.#{loc}"), url_for(locale: loc)`. Названия в `languages.<locale>.yml`: ключи `languages.en: English`, `languages.ru: Русский` в обоих файлах (названия языков собственные).
- [ ] **Step 1:** Тест: на `/ru/games` ответ содержит `lang="ru"` и ссылку на `/en/games`. Падает, реализовать, `bin/rails test` зелёный.
- [ ] **Step 2:** Коммит: `git add app/views/layouts config/locales test && git commit -m "Add lang attribute and language switcher"`.

### Task 2.3 [CHEAP]: шапка, список игр, страница игры

**Files:** `app/views/layouts/_nav_header.html.erb`, `app/views/games/index.html.erb`, `app/views/games/show.html.erb`, `config/locales/layout.{en,ru}.yml`, `config/locales/games_ui.{en,ru}.yml`

- Все русские и английские строки заменить на `t(...)`. В `index` и `show` ленивые ключи `t(".start")`. Для шапки `layout.nav.games`, `layout.nav.profile`, `layout.nav.sign_out`, `layout.nav.sign_in`, `layout.nav.sign_up`.
- Текущий «Уровень 1» в карточке игры убрать, это заглушка без смысла.
- Название и описание игры показывает `game.title`/`game.description` после Task 2.9. До этого оставить `game.name`.
- [ ] **Step 1:** `grep -nP '[А-Яа-я]' app/views/layouts app/views/games/index.html.erb app/views/games/show.html.erb` ничего не выводит.
- [ ] **Step 2:** `bin/rails test` зелёный. Коммит: `git add app config && git commit -m "Localize layout and games index"`.

### Task 2.4 [CHEAP]: формы входа, регистрации, паролей, профиля и админ-сообщение

**Files:** `app/views/{sessions,registrations,passwords,passwords_mailer,users}/*`, `app/controllers/{sessions,registrations,passwords}_controller.rb`, `app/controllers/admin/application_controller.rb`, `config/locales/{sessions,registrations,passwords,users,mailers,admin}.{en,ru}.yml`

- Каждое `notice`/`alert` в контроллерах заменить на `t("sessions.create.invalid")` и подобные. «Доступ запрещён» в `Admin::ApplicationController` перевести ключом `admin.forbidden`.
- Тексты писем (`passwords_mailer/reset.*`) в `mailers.passwords.reset.*`.
- Форма регистрации: пояснение «не используйте настоящее имя в нике» в `registrations.form.nickname_hint`.
- [ ] **Step 1:** `grep -rnP '[А-Яа-я]' app` не находит ничего, кроме JS-контроллеров игр (их Task 2.5 и далее). Строки в английских шаблонах входа и паролей заменены.
- [ ] **Step 2:** `bin/rails test` зелёный. Коммит: `git add app config && git commit -m "Localize auth screens"`.


### Task 2.5 [EXPENSIVE]: общий клиентский каркас `games/base.js`

**Files:** Create: `app/javascript/controllers/games/base.js`. Modify: `app/javascript/controllers/index.js` только если `eagerLoadControllersFrom` подхватывает `base.js` как контроллер (проверить, что имя без `_controller` его не регистрирует).

**Interfaces (экспорт `base.js`):**
```js
export function t(messages, key, vars = {})      // messages: объект из data-*-messages-value; подставляет %{name}; нет ключа: возвращает key
export function formatNumber(n)                  // Intl.NumberFormat(document.documentElement.lang).format(n)
export function createTimers()                   // { set(fn, ms) -> id, clear(id), clearAll() }; clearAll вызывается в disconnect()
export async function submitResult(url, result)  // POST JSON с X-CSRF-Token; возвращает { ok, status, body }
```

- `submitResult` берёт токен из `meta[name='csrf-token']`, тело `{ result }`, заголовок `Content-Type: application/json`. Путь приходит аргументом, в модуле нет строк с `/games/`.
- Через `importmap` модуль подключается как `controllers/games/base`. Проверить, что `config/importmap.rb` содержит `pin_all_from "app/javascript/controllers", under: "controllers"`.
- [ ] **Step 1:** Вручную в консоли браузера или в `bin/rails runner` проверить нельзя, поэтому добавить системный тест не требуется. Проверка: `grep -n "base" app/javascript/controllers/index.js config/importmap.rb` и `bin/rails test` зелёный.
- [ ] **Step 2:** Коммит: `git add app/javascript && git commit -m "Add shared game client helpers"`.

### Task 2.6 [CHEAP], четыре подзадачи: перевод игр на i18n и `submit-url`

Для каждой игры по шаблону. Игры независимы, делать по одной, после каждой `bin/rails test` и коммит.

Шаблон подзадачи (`<name>` это `reaction_time`, `nback`, `stroop_test`, `adaptive_reaction_test`):
- **Files:** `config/locales/games/<name>.en.yml`, `config/locales/games/<name>.ru.yml`, `app/views/games/_<name>.html.erb`, `app/javascript/controllers/games/<name>_controller.js`.
- В `.yml` ключи `games.<name>.title`, `games.<name>.description`, `games.<name>.ui.*` (каждая строка экрана и каждое сообщение из JS, включая единицы `ms`). Русские значения взять из текущих шаблонов и контроллеров, английские написать.
- В партиале: убрать `data-...-game-id-value` и `game-session-id-value`, добавить `data-games--<name>-submit-url-value="<%= submit_result_game_game_session_path(@game, @game_session) %>"` и `data-games--<name>-messages-value="<%= t("games.<name>.ui").to_json %>"`. Видимые строки заменить на `t("games.<name>.ui.<ключ>")`.
- В контроллере: `static values` убрать `gameId` и `gameSessionId`, добавить `submitUrl: String, messages: Object`. Все строки через `t(this.messagesValue, "<ключ>", vars)` из `base.js`. `fetch(...)` заменить на `submitResult(this.submitUrlValue, {...})`. `setTimeout` заменить на `this.timers.set(...)` и в `disconnect()` вызвать `this.timers.clearAll()`.
- В `reaction_time_controller.js` дополнительно исправить `Math.min(...validResults)` на пустом массиве: при пустом массиве `min_rt` и `max_rt` равны `null`.
- В стратегии убрать `locales: add_games_locales` и метод `add_games_locales` (для `reaction_time`).
- Проверка: `grep -nP '[А-Яа-я]' app/views/games/_<name>.html.erb app/javascript/controllers/games/<name>_controller.js` пусто; `grep -n "setTimeout\|fetch(" app/javascript/controllers/games/<name>_controller.js` пусто.
- Коммит: `git add app config/locales/games && git commit -m "Localize <name> game"`.

- [ ] **2.6a** reaction_time
- [ ] **2.6b** nback (заголовок `N-Back (N=2)` берёт `n` из `data-games--nback-n-value`, в строке `%{n}`)
- [ ] **2.6c** stroop_test (названия цветов на кнопках тоже через `games.stroop_test.ui.colors.<red|green|blue|yellow>`, атрибут `data-color` остаётся английским ключом)
- [ ] **2.6d** adaptive_reaction_test (файлы ещё не в git, добавляются в коммит, владелец разрешил)

### Task 2.7 [CHEAP]: `Game#title`, `Game#description`, `Registry.sync!` берёт переводы

**Files:** `app/models/game.rb`, `app/models/games/registry.rb`, `test/models/game_test.rb`, `test/models/games/registry_test.rb`

- `Game#title = I18n.t("games.#{system_name}.title")`, `Game#description = I18n.t("games.#{system_name}.description")`.
- `Registry.sync!` записывает в `name` и `description` значения на `I18n.default_locale` (`I18n.t(key, locale: I18n.default_locale)`).
- Шаблоны `games/index` и `games/show` переключить с `game.name` на `game.title`.
- [ ] **Step 1:** Тесты: `title follows current locale`, `sync! stores default-locale name`. Падают, реализовать, зелёные.
- [ ] **Step 2:** Коммит: `git add app test && git commit -m "Read game titles from I18n"`.


### Task 2.8 [CHEAP]: язык в ссылках писем

**Files:** `app/mailers/application_mailer.rb`, `test/mailers/passwords_mailer_test.rb`

- В `ApplicationMailer` задать `default_url_options`, дополняющий настройки окружения: `Rails.application.config.action_mailer.default_url_options.to_h.merge(locale: I18n.locale)`. Метод вычисляется в момент отправки.
- [ ] **Step 1:** Тест: письмо сброса пароля, собранное внутри `I18n.with_locale(:ru)`, содержит ссылку с `/ru/passwords/`. Падает, реализовать, зелёный.
- [ ] **Step 2:** Коммит: `git add app/mailers test && git commit -m "Add locale to mailer links"`.

### Task 2.9 [EXPENSIVE]: проверка переводов и контракт

**Files:** Create: `test/i18n_test.rb`. Modify: `test/models/games/strategy_contract_test.rb`, `lib/generators/game/game_generator.rb`, `lib/generators/game/templates/locale.en.yml.tt`

- `test/i18n_test.rb` читает все `config/locales/**/*.<locale>.yml` через `YAML.safe_load_file`. Для каждого языка из `available_locales`, кроме `en`: набор плоских ключей совпадает с `en`; множество плейсхолдеров `%{...}` в каждой строке совпадает с английской; пустых значений нет. Сообщение об ошибке перечисляет ключи. Новых гемов нет.
- Контрактный тест добавляет: у каждой стратегии в каждом языке есть `games.<name>.title`, `.description`, `.ui` (непустой Hash).
- Генератор создаёт пятый файл `config/locales/games/<name>.en.yml` с ключами `title`, `description`, `ui`. Тест генератора проверяет пять файлов.
- [ ] **Step 1:** Тесты первыми. В `i18n_test` добавить самопроверку на искусственных данных: функция сравнения находит расхождение плейсхолдера (`%{n}` против `%{count}`).
- [ ] **Step 2:** `bin/rails test` зелёный. Коммит: `git add test lib && git commit -m "Add i18n structure tests"`.

### Task 2.10 [CHEAP]: обход основных страниц на каждом языке

**Files:** Create: `test/integration/locale_smoke_test.rb`

Для каждого языка из `available_locales` и каждой страницы (`games_path`, страница игры, `new_session_path`, `new_registration_path`, `new_password_path`) выполнить GET, проверить `200` и отсутствие текста `translation missing` в теле. Страницы, требующие входа, добавляются в список теми задачами, которые их создают.

- [ ] **Step 1:** Написать тест, он зелёный.
- [ ] **Step 2:** `grep -rnE '"/(games|users|session)' app` ничего не выводит. Коммит: `git add test && git commit -m "Add locale smoke test"`.


---

## Этап 3. Темы оформления

### Task 3.1 [EXPENSIVE]: токены темы и переключатель

**Files:** `app/assets/tailwind/application.css`, `app/helpers/application_helper.rb`, `app/javascript/controllers/theme_controller.js`, `app/views/layouts/application.html.erb`, `app/views/layouts/_nav_header.html.erb`, `config/locales/themes.{en,ru}.yml`, `test/helpers/application_helper_test.rb`

- В `application.css` после `@import "tailwindcss"` блок `@theme inline` с переменными `--color-surface: var(--surface)` и так далее для ролей: `surface`, `surface-raised`, `ink`, `ink-muted`, `line`, `accent`, `accent-ink`, `danger`, `success`, `stimulus-red`, `stimulus-green`, `stimulus-blue`, `stimulus-yellow`. Значения лежат в блоках `[data-theme="light"] { ... }` и `[data-theme="dark"] { ... }`. Оттенок `--stimulus-*` одинаков в обеих темах, меняется только светлота.
- `ApplicationHelper::THEMES = %w[light dark].freeze`.
- В `<head>` layout inline-скрипт до отрисовки: читает `localStorage.getItem("theme")`, иначе `matchMedia("(prefers-color-scheme: dark)")`, ставит `document.documentElement.dataset.theme`. Значение сверяется со списком `THEMES`, который Rails подставляет через `<%= THEMES.to_json %>`.
- `theme_controller.js` ставит `localStorage.setItem("theme", value)` и `dataset.theme`. Названия кнопок из `themes.<key>`.
- Turbo: проверить вручную, что `data-theme` на `<html>` сохраняется при переходах. Если сбрасывается, переустанавливать атрибут в `turbo:load`.
- [ ] **Step 1:** Тест хелпера: `THEMES` содержит `light` и `dark`, ключи `themes.<key>` есть во всех языках.
- [ ] **Step 2:** Реализовать, `bin/rails tailwindcss:build`. Открыть страницу, убедиться, что переключатель меняет цвета и выбор переживает перезагрузку.
- [ ] **Step 3:** Коммит: `git add app config test && git commit -m "Add theme tokens and switcher"`.

### Task 3.2 [CHEAP]: линтер тем

**Files:** Create: `test/theme_lint_test.rb`

Обходит `app/views/**/*.erb` и `app/javascript/controllers/**/*.js`. Падает на классах `(bg|text|border|ring|fill|stroke|from|via|to|divide|outline)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|white|black)` (с необязательными `!` и числом), на hex `#[0-9a-fA-F]{3,8}\b` и на `rgb(`, `hsl(`. Исключение: `app/views/pwa/**`.

- [ ] **Step 1:** Написать тест и самопроверку на строках: `bg-blue-600` падает, `bg-surface` нет, `text-stimulus-red` нет, `#fff` падает.
- [ ] **Step 2:** На реальных файлах тест красный, шаблоны ещё не переведены. Поставить `skip "enabled after Task 3.6"`.
- [ ] **Step 3:** Коммит: `git add test && git commit -m "Add theme lint test"`.

### Task 3.3 до 3.6 [CHEAP]: перевод шаблонов на токены

После каждой подзадачи `bin/rails test` и коммит. Таблица замен:

| Было | Стало |
|---|---|
| `bg-white`, `bg-gray-50`, `bg-gray-100` | `bg-surface` или `bg-surface-raised` (карточка) |
| `text-gray-900`, `text-gray-600`, `text-zinc-400` | `text-ink`, `text-ink-muted` |
| `border-gray-*` | `border-line` |
| `bg-blue-*`, `bg-violet-*`, `bg-emerald-600/700`, `bg-indigo-600` | `bg-accent`, текст `text-accent-ink` |
| `bg-red-*`, `text-red-*`, `border-red-*` | `bg-danger`, `text-danger`, `border-danger` |
| `bg-green-*`, `bg-emerald-500`, `text-green-500` | `bg-success`, `text-success` |
| градиент шапки `from-indigo-600 to-violet-600` | `bg-accent` |
| `!bg-red-500`, `!bg-emerald-500` в JS | `!bg-danger`, `!bg-success` |
| `getHexColor` в Stroop | классы `text-stimulus-red|green|blue|yellow` по `dataset.color` |

- [ ] **3.3** Layout, шапка, список игр, страница игры.
- [ ] **3.4** Формы входа, регистрации, паролей, профиль, админка пользователей.
- [ ] **3.5** Партиалы и контроллеры `reaction_time`, `nback`, `adaptive_reaction_test`. Круг `bg-gray-700` на `bg-ink-muted`, зелёный `#22c55e` на `bg-success`.
- [ ] **3.6** `stroop_test`: убрать `getHexColor`, снять `skip` в `theme_lint_test`, `bin/rails test` зелёный. Глазами проверить читаемость слов Stroop на обеих темах.


---

## Этап 4. Аккаунты

Вход по нику, почта только как HMAC, подтверждение регистрации, сброс пароля, удаление аккаунта. Сайт не опубликован, поэтому существующие dev-пользователи переносятся миграцией, а не вручную.

### Task 4.1 [EXPENSIVE]: pepper и миграция `users`

**Files:** Create: `config/initializers/email_pepper.rb`, `db/migrate/<timestamp>_prepare_users_for_hashed_email.rb`. Modify: `README.md`

- Инициализатор задаёт `Rails.configuration.x.email_pepper` из `ENV["EMAIL_PEPPER"]` (значение лежит в `.env`, в `.env.example` только имя). В production при пустом значении поднимается исключение при старте. В development и test допустим фиксированный запасной вариант `"dev-pepper"`.
- Миграция: добавить `email_digest` (string, сначала null), `gender` (string), `age_decade` (integer), `confirmed_at` (datetime). Заполнить `email_digest` из `email_address` (`OpenSSL::HMAC.hexdigest("SHA256", pepper, email.strip.downcase)`), `confirmed_at` существующим пользователям поставить `Time.current`. Затем `email_digest` делается `null: false` с уникальным индексом, `email_address` и его индекс удаляются. Старый уникальный индекс по `nickname` заменить на уникальный индекс по `lower(nickname)`. Метод `down` кидает `ActiveRecord::IrreversibleMigration`: почту из хэша не восстановить.
- В `README.md` строка: потеря `pepper` делает сброс пароля невозможным, хранить его отдельно от резервных копий базы.
- [ ] **Step 1:** Сделать копию dev-базы: `pg_dump mind_at_play_dev > /tmp/mind_at_play_dev_before_users.sql`.
- [ ] **Step 2:** `bin/rails db:migrate` и `RAILS_ENV=test bin/rails db:migrate`. Проверить, что `db/schema.rb` содержит `email_digest`, `confirmed_at` и не содержит `email_address`.
- [ ] **Step 3:** Коммит `git add config db README.md && git commit -m "Hash user email and add confirmation columns"` после Task 4.2 (до него тесты красные из-за фикстур, поэтому 4.1 и 4.2 коммитятся вместе, если так проще).

### Task 4.2 [EXPENSIVE]: модель `User`

**Files:** `app/models/user.rb`, `test/fixtures/users.yml`, `test/test_helper.rb`, `test/models/user_test.rb`

Интерфейс:
```ruby
User.email_digest_for(email) -> String        # HMAC от email.to_s.strip.downcase
User.find_by_email(email)    -> User | nil    # по email_digest
user.email = "a@b.c"                          # виртуальный атрибут: ставит email_digest, сам адрес не сохраняется
user.email_valid? / validation                # формат URI::MailTo::EMAIL_REGEXP проверяется на виртуальном атрибуте
NICKNAME_FORMAT = /\A[A-Za-z0-9_.\-]{3,20}\z/
generates_token_for :email_confirmation, expires_in: 24.hours
user.confirmed? -> Boolean
```

- Ник: формат `NICKNAME_FORMAT`, уникальность без учёта регистра (`validates :nickname, uniqueness: { case_sensitive: false }`), после создания не меняется (`attr_readonly :nickname`).
- `gender` из `%w[female male other]` или `nil`. `age_decade` из `(10..90).step(10)` или `nil`.
- `has_many :game_sessions, dependent: :destroy` и `has_many :check_ins, dependent: :destroy` (`check_ins` появится на этапе 5, до тех пор строку не добавлять).
- Валидация `email_digest` на уникальность, обязательное наличие.
- Фикстуры: вместо `email_address` писать `email_digest: <%= User.email_digest_for("one@example.com") %>`, `confirmed_at: <%= Time.current %>`. `sign_in` в `test_helper.rb` отправляет `nickname:` и `password:`.
- [ ] **Step 1:** Тесты: `digest ignores case and spaces`, `digest differs with another pepper`, `email is not stored as plain text` (в `user.attributes` нет значения адреса), `nickname 3-20 chars only allowed symbols`, `nickname unique ignoring case`, `nickname cannot change after create`, `bad email format is invalid`, `token for confirmation expires after 24 hours` (`travel 25.hours`), `destroy removes game sessions`.
- [ ] **Step 2:** Тесты падают, реализовать, `bin/rails test test/models` зелёный.
- [ ] **Step 3:** Коммит: `git add app test && git commit -m "Hash user email in model"` (вместе с 4.1).

### Task 4.3 [EXPENSIVE]: вход по нику

**Files:** `app/controllers/sessions_controller.rb`, `app/views/sessions/new.html.erb`, `test/controllers/sessions_controller_test.rb`

- `User.authenticate_by(nickname: params[:nickname].to_s.strip, password: params[:password])`. Поиск по нику должен быть без учёта регистра: перед вызовом заменить ник на сохранённый (`User.where("lower(nickname) = ?", nick.downcase).pick(:nickname)`), иначе `authenticate_by` не найдёт запись.
- Неверный ник и неверный пароль дают одно и то же сообщение `sessions.create.invalid`. Если пароль верный, но `confirmed_at` пуст: сообщение `sessions.create.unconfirmed`, сессия не создаётся.
- Форма: поле `nickname`, а не почта.
- [ ] **Step 1:** Тесты: `signs in by nickname`, `nickname lookup ignores case`, `wrong nickname and wrong password give identical redirect and message`, `unconfirmed user cannot sign in`, `rate limit blocks the 11th attempt in 3 minutes` (проверить, что кэш в test не `:null_store`).
- [ ] **Step 2:** Реализовать, `bin/rails test` зелёный. Коммит: `git add app test && git commit -m "Sign in by nickname"`.


### Task 4.4 [EXPENSIVE]: регистрация и подтверждение почты

**Files:** `app/controllers/registrations_controller.rb`, `app/controllers/email_confirmations_controller.rb`, `app/mailers/registrations_mailer.rb`, `app/views/registrations/{new,_form}.html.erb`, `app/views/registrations_mailer/confirm.{html,text}.erb`, `config/locales/{registrations,mailers}.{en,ru}.yml`, `test/controllers/registrations_controller_test.rb`, `test/controllers/email_confirmations_controller_test.rb`, `test/mailers/registrations_mailer_test.rb`

Поведение:
- Форма: `nickname`, `email`, `email_confirmation` (повторный ввод, сравнение до записи), `password`, `password_confirmation`, необязательные `gender` и `age_decade` (`<select>` с пустым вариантом). Под ником просьба не использовать настоящее имя.
- `create`: если есть неподтверждённый пользователь с тем же `email_digest`, он удаляется и заменяется новым. Если занят подтверждённый, показывается ошибка (допущение 6). После сохранения `RegistrationsMailer.confirm(user, email).deliver_now`. Адрес передаётся аргументом и нигде не сохраняется. Сессия не создаётся, человека перенаправляют на страницу «проверьте почту».
- `RegistrationsMailer.confirm(user, email)`: ссылка `email_confirmation_url(token: user.generate_token_for(:email_confirmation))`, письмо на `email`.
- `EmailConfirmationsController#show`: `User.find_by_token_for(:email_confirmation, params[:token])`. Найден: `update!(confirmed_at: Time.current)`, вход (`start_new_session_for`), редирект на корень. Не найден или просрочен: страница с сообщением и редирект на регистрацию, статус 404 не нужен. Повторный переход по той же ссылке безопасен.
- Токен подписан, `generates_token_for` делает его недействительным при смене `password_digest`.
- Параметры `email`, `password` попадают в `filter_parameters` (проверить `config/initializers/filter_parameter_logging.rb`, `:email` и `:passw` там уже есть, `:email_confirmation` покрывается частичным совпадением).
- [ ] **Step 1:** Тесты: `creates unconfirmed user and sends mail with token link`, `link in mail has locale prefix`, `mail goes to typed address and address is not stored in any users column`, `mismatching email confirmation does not create user`, `unconfirmed duplicate is replaced`, `confirmed duplicate shows error`, `confirmation link confirms and signs in`, `expired token (25 hours) does not confirm`, `tampered token does not confirm`, `nickname 2 chars is rejected`, `deliver_now used: no row in solid_queue_jobs` (проверка `SolidQueue::Job.count` либо `assert_emails 1` без очереди).
- [ ] **Step 2:** Тесты падают, реализовать, `bin/rails test` зелёный. Коммит: `git add app config test && git commit -m "Add email-confirmed registration"`.

### Task 4.5 [EXPENSIVE]: сброс пароля по хэшу почты

**Files:** `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`, `app/views/passwords/*`, `app/views/passwords_mailer/reset.*`, `test/controllers/passwords_controller_test.rb`, `test/mailers/passwords_mailer_test.rb`

- `create`: `User.find_by_email(params[:email])`. Если пользователь найден и подтверждён: `PasswordsMailer.reset(user, params[:email].to_s.strip).deliver_now`. Ответ всегда один и тот же: редирект на вход с `passwords.create.sent`, независимо от наличия адреса.
- `PasswordsMailer.reset(user, email)`: адрес получателя приходит аргументом, `mail to: email`. Ссылка на `edit_password_url(user.password_reset_token)`.
- Остальное в `PasswordsController` (`edit`, `update`, токены) как сейчас.
- [ ] **Step 1:** Тесты: `known and unknown email give identical response`, `mail is sent to typed address only for known user`, `unconfirmed user gets no mail`, `reset link has locale prefix`, `password update with valid token works`, `invalid token redirects`.
- [ ] **Step 2:** Реализовать, `bin/rails test` зелёный. Коммит: `git add app test && git commit -m "Reset password by hashed email lookup"`.

### Task 4.6 [EXPENSIVE]: удаление аккаунта

**Files:** `config/routes.rb` (маршрут уже есть в каркасе), `app/controllers/users_controller.rb`, `app/views/users/show.html.erb`, `config/locales/users.{en,ru}.yml`, `test/controllers/users_controller_test.rb`

- `UsersController` требует вход и работает только с `Current.user`: `set_user` возвращает `Current.user`, параметр `:id` другого пользователя даёт 404.
- `destroy` требует пароль в параметре `password`, проверка через `Current.user.authenticate`. Неверный пароль: возврат на профиль с сообщением, ничего не удалено. Верный: `terminate_session`, `destroy!`, редирект на корень.
- `update` разрешает только `gender` и `age_decade`. Ник и почта не меняются через эту форму.
- Профиль показывает кнопку «Удалить аккаунт» с полем пароля и описанием, что удаляются все прохождения и отметки.
- [ ] **Step 1:** Тесты: `user can delete own account with password`, `wrong password keeps account`, `deleting removes game_sessions` (создать две сессии, проверить `GameSession.count`), `cannot delete another user (404)`, `update ignores nickname param`, `anonymous gets redirected to sign in`.
- [ ] **Step 2:** Реализовать, зелёный. Коммит: `git add app config test && git commit -m "Add account deletion"`.

### Task 4.7 [CHEAP]: админка пользователей без почты

**Files:** `app/views/admin/users/*`, `app/controllers/admin/users_controller.rb`, `test/controllers/admin/users_controller_test.rb`

- Убрать из форм и списков поля `email_address`. Параметры `permit` — `nickname`, `active`, роли (как сейчас), без почты.
- `sign_in_as_admin` в `test_helper.rb` использовать в тестах как раньше.
- [ ] **Step 1:** Тест: страница `admin/users` не содержит значения `email_digest` (создать пользователя и проверить, что его digest не выводится). Падает, исправить шаблоны.
- [ ] **Step 2:** `grep -rn "email_address" app test config` ничего не выводит. `bin/rails test` зелёный. Коммит: `git add app test && git commit -m "Remove email from admin users"`.


---

## Этап 5. Отметка состояния

### Task 5.1 [EXPENSIVE]: модель `CheckIn`

**Files:** Create: `db/migrate/<timestamp>_create_check_ins.rb`, `db/migrate/<timestamp>_add_check_in_to_game_sessions.rb`, `app/models/check_in.rb`, `test/models/check_in_test.rb`, `test/fixtures/check_ins.yml`. Modify: `app/models/user.rb`, `app/models/game_session.rb`

Интерфейс:
```ruby
CheckIn::FLAGS = %w[alcohol meds illness hungry rested].freeze
CheckIn::DAY_PHASES = %w[morning day evening night].freeze
check_in.flag?(key) -> Boolean
check_in.flag_keys   -> Array<String>   # ключи со значением true
```
- Таблица как в каркасе. `flags` jsonb `null: false, default: {}`.
- Валидации: `sleep_hours` от 0 до 24 (необязательно), `day_phase` из `DAY_PHASES` или nil, `flags` это Hash, ключи только из `FLAGS`, значения только `true` или `false`.
- `before_validation` приводит значения флагов к boolean (форма присылает `"1"` и `"0"`).
- `User has_many :check_ins, dependent: :destroy`. `GameSession belongs_to :check_in, optional: true`. FK `game_sessions.check_in_id` с `on_delete: :nullify`: если отметку удалят отдельно, прохождение остаётся.
- [ ] **Step 1:** Тесты: `valid with only day_phase`, `invalid with unknown flag key`, `invalid with non-boolean flag value`, `sleep_hours above 24 invalid`, `flag_keys lists only true flags`, `destroying user destroys check_ins`.
- [ ] **Step 2:** Тесты падают, реализовать, `bin/rails db:migrate` (dev и test), `bin/rails test` зелёный.
- [ ] **Step 3:** Коммит: `git add db app test && git commit -m "Add CheckIn model"`.

### Task 5.2 [EXPENSIVE]: форма отметки перед тестом

**Files:** `app/controllers/game_sessions_controller.rb`, `app/views/game_sessions/new.html.erb`, `app/views/games/show.html.erb`, `config/locales/check_ins.{en,ru}.yml`, `test/controllers/game_sessions_controller_test.rb`

- Кнопка «Играть» на странице игры ведёт на `new_game_game_session_path(@game)`.
- `new` для вошедшего пользователя показывает форму: `sleep_hours` (число с шагом 0.5), `day_phase` (радиокнопки, по умолчанию ничего не выбрано), флаги чекбоксами из `CheckIn::FLAGS`. Две кнопки: «Начать с отметкой» и «Пропустить». Рядом нейтральный текст `check_ins.form.why`: отметка делает графики осмысленнее, форму можно пропустить.
- Для анонима форма не показывается: `new` сразу создаёт сессию без отметки.
- `create`: `params.fetch(:check_in, {}).permit(:sleep_hours, :day_phase, flags: CheckIn::FLAGS)`. «Пропустить» (`params[:skip]`) или пустые поля: отметка не создаётся. Иначе `Current.user.check_ins.create!(...)` и `game_session.check_in = check_in`.
- Невалидная отметка (например `sleep_hours: 99`): форма показывается снова с ошибками, сессия игры не создаётся.
- [ ] **Step 1:** Тесты: `new shows form for signed in user`, `anonymous skips form`, `skip creates session without check_in`, `submitted form creates check_in and links it`, `unknown flag key is rejected`, `invalid sleep_hours re-renders form`, `check_in belongs to current user`.
- [ ] **Step 2:** Реализовать, `bin/rails test` зелёный. Добавить `new_game_game_session_path` в `locale_smoke_test`. Коммит: `git add app config test && git commit -m "Add optional check-in form before a game"`.


---

## Этап 6. Попытки (`trials`) и разбор прохождения

Формат попыток из спецификации: `result["trials"]` массив хэшей `{rt_ms, correct, phase}` и ключ `result["format"] = 1`. Чтение попыток идёт через один метод базового класса, чтобы формат можно было сменить в одном месте.

### Task 6.1 [EXPENSIVE]: `trials` в `BaseStrategy` и `Games::Blocks`

**Files:** Modify: `app/models/games/base_strategy.rb`. Create: `app/models/games/blocks.rb`, `test/models/games/blocks_test.rb`

Интерфейс:
```ruby
Games::BaseStrategy#trials(result) -> Array<Hash>   # единственное место, читающее result["trials"]; [] если нет
Games::BaseStrategy::FORMAT = 1                     # handle_result добавляет "format" => 1

Games::Blocks.call(trials, phases: []) -> Array<Block>
Block = Struct.new(:label, :count, :median_rt_ms, :error_rate, keyword_init: true)
```
- Если `phases` непусты: один блок на часть, `label` это значение части.
- Если `phases` пусты и попыток не меньше 10: пять блоков по порядку, размеры отличаются не больше чем на 1.
- Если попыток меньше 10 и частей нет: пустой массив.
- `median_rt_ms` считается по верным ответам с числовым `rt_ms`, иначе `nil`. `error_rate` это доля попыток с `correct == false`, число от 0 до 1.
- [ ] **Step 1:** Тесты: `5 blocks for 100 trials`, `block sizes differ by at most one for 23 trials`, `empty for 9 trials`, `phases produce one block per phase in order`, `median ignores nil rt and wrong answers`, `error_rate counts wrong answers including ones without rt`, `all wrong gives nil median`, `trials returns empty array when missing`.
- [ ] **Step 2:** Тесты падают, реализовать, зелёный. Коммит: `git add app test && git commit -m "Add trials accessor and blocks"`.

### Task 6.2 до 6.5 [EXPENSIVE]: игры отправляют `trials`

Для каждой игры партиал и контроллер переводятся на отправку `trials`, а стратегия получает серверный подсчёт.

| Игра | `trials[i]` | `phases` | `score` (сервер) | `primary_metric` | `secondary_metric` |
|---|---|---|---|---|---|
| reaction_time | `rt_ms` число или `nil` (пропуск), `correct` true при числе, `phase` nil | `[]` | счётчики пропусков | медиана `rt_ms` верных, `ms` | число неверных, `count` |
| nback | `rt_ms` nil, `correct` по известному ответу, `phase` nil | `[]` | `correct` и `errors` по `setup["sequence"]` и `n`, клиентские итоги не берутся | доля верных, `%` | число ошибок |
| stroop_test | `rt_ms` или nil, добавочный ключ `answer` (нажатый цвет или nil), `correct` сервер сравнивает с `setup["sequence"][i][1]` | `[]` | `correct` пересчитывается по `answer` | медиана `rt_ms` верных, `ms` | число ошибок |
| adaptive_reaction_test | `rt_ms`, `correct`, `phase` от 1 до 3, добавочные `shown`, `pressed` | `[1, 2, 3]` | `correct` пересчитывается из `shown`, `pressed` и правила части | медиана `rt_ms` верных по всем частям, `ms` | число ошибок |

Общие правила: `validate_result` проверяет длину `trials` (для `nback` и `stroop_test` равна длине последовательности из `setup`) и `rt_ms` nil или от 0 до 60000. Старые итоговые ключи убираются из `permitted_result_keys`. `sample_payload` возвращает корректный набор попыток.

- [ ] **6.2** reaction_time. `rt_ms` меряет `performance.now()`, как сейчас.
- [ ] **6.3** nback. Контроллер записывает попытку на каждый стимул, включая пропуск. Ответ считает сервер.
- [ ] **6.4** stroop_test. Добавить `answer`.
- [ ] **6.5** adaptive_reaction_test. Реализовать две кнопки A и Б. Часть 1: A это красный, Б зелёный. Часть 2 наоборот. Часть 3 как часть 1. Число попыток и интервалы выбираются по правилу «Проектирование игры» (на одном экране: что измеряем, главный и второстепенный показатель, что показываем, чего не говорим) и согласуются с владельцем. Файл в рабочем каталоге это черновик владельца.

Для каждой подзадачи: тесты стратегии (метрики на `sample_payload`; изменённый клиентский `correct` не влияет на серверный пересчёт; `validate_result` false при неверной длине `trials`), `bin/rails test` зелёный, коммит `Send trials from <name>`.


### Task 6.6 [EXPENSIVE]: страница прохождения

**Files:** `app/controllers/game_sessions_controller.rb` (действие `show`), `app/views/game_sessions/show.html.erb`, `_trial_strip.html.erb`, `_blocks.html.erb`, `config/locales/game_sessions.{en,ru}.yml`, `test/controllers/game_sessions_show_test.rb`

- `show`: `Current.user.game_sessions.find(params[:id])`. Чужой или несуществующий id даёт 404. Сессия без `played_at` тоже 404. Аноним перенаправляется на вход.
- Показывает главный показатель (`metric`, `primary_unit`) и второстепенный в скобках по `insights.primary_with_secondary`, блоки (`Games::Blocks`) и полосу попыток. Если есть отметка, выводятся её значения текстом (часы сна, стадия дня, флаги).
- Полоса попыток: ряд SVG-фигур по порядку, верный ответ круг, неверный квадрат, пропуск тире. Цвета только токены (`fill-success`, `fill-danger`, `fill-ink-muted`).
- Для адаптивного теста подпись `games.adaptive_reaction_test.ui.switch_cost`: разность медиан частей, без оценки.
- Тексты вида «Блок 3: медиана 340 мс, ошибок 20%». Слов «усталость», «хуже» нет.
- [ ] **Step 1:** Тесты: `owner sees session`, `other user gets 404`, `anonymous redirected to sign in`, `unfinished session returns 404`, `session without trials shows only the main metric`, `100 trials show 5 blocks`, `page has no evaluative words` (в обоих языках `refute_match(/worse|better|tired|хуже|лучше|усталость/i, body)`).
- [ ] **Step 2:** Реализовать, добавить страницу в `locale_smoke_test`. `bin/rails test` зелёный. Коммит: `git add app config test && git commit -m "Add game session breakdown page"`.

---

## Этап 7. Инфографика «Моя динамика»

### Task 7.1 [EXPENSIVE]: `Insights::Series`

**Files:** Create: `app/models/insights/series.rb`, `test/models/insights/series_test.rb`

Интерфейс:
```ruby
Insights::MIN_POINTS = 5
Insights::Series.new(user:, game:)
  #points      -> Array<Point>   # прохождения с metric, по played_at
  #groups_for_flag(key) -> { with: Group, without: Group }
  #groups_by_day_phase  -> { "night" => Group, ... }   # только фазы, у которых есть точки
Point = Struct.new(:session_id, :played_on, :metric, :metric_secondary, :sleep_hours, :flags, :day_phase)
Group = Struct.new(:points, :count, :median, :min, :max)   # median, min, max равны nil, если count < MIN_POINTS
```
- Берутся только прохождения этого пользователя этой игры с `metric` не nil. `played_on` это дата без времени.
- `median` для чётного числа точек среднее двух средних. Для `count < 5` `median` nil, `min` и `max` тоже nil (показываем только точки).
- Прохождения без отметки входят в `points`, в группы флагов не входят.
- Один запрос с `includes(:check_in)`, без N+1.
- [ ] **Step 1:** Тесты: `points only for the user and the game`, `median for odd and even counts`, `no median below 5 points`, `min and max from 5 points`, `sessions without check_in excluded from flag groups`, `group by rested flag`, `no data returns empty groups`, `query count is constant` (`assert_queries_count 2` или подобное).
- [ ] **Step 2:** Реализовать, зелёный. Коммит: `git add app test && git commit -m "Add insights series"`.

### Task 7.2 [EXPENSIVE]: страницы «Моя динамика»

**Files:** `app/controllers/insights_controller.rb`, `app/views/insights/{index,show}.html.erb`, `app/views/insights/_chart.html.erb`, `app/helpers/insights_helper.rb`, `config/locales/insights.{en,ru}.yml`, `test/controllers/insights_controller_test.rb`, `test/helpers/insights_helper_test.rb`

- `index`: список активных игр, сгруппированных по `category` (секции с названием из `games.categories.<key>`), у каждой число прохождений пользователя и ссылка. Для игр без прохождений строка «Пока нет прохождений».
- `show` (`:id` это id игры): график точек по датам, и по каждому флагу из `CheckIn::FLAGS` блок «с флагом / без флага»: число точек, медиана и размах (если точек хватает), точки. Для сна ось «часы сна».
- Главный показатель на графике, второстепенный в подписи точки в скобках (`insights.primary_with_secondary`). Каждая точка это ссылка на `game_session_path(point.session_id)`.
- SVG строится серверным ERB. Помощник `chart_scale(values, size)` возвращает позиции, тестируется отдельно (пустой массив, одно значение, равные значения не дают деления на ноль).
- Различие групп формой точки (круг с флагом, ромб без флага), а не только цветом. Цвета токены.
- Подпись под графиком: `insights.same_device_note` («Сравнивайте прохождения на одном и том же устройстве»).
- Только вошедший пользователь. Аноним перенаправляется на вход. Тексты описательные: «5 прохождений, медиана 312 мс».
- [ ] **Step 1:** Тесты: `index groups games by category`, `show lists a link to every point`, `show hides median under 5 points`, `show displays median at 5 points`, `other users data never appears`, `anonymous redirected to sign in`, `page has no evaluative words in both languages`, `chart_scale handles empty and constant input`.
- [ ] **Step 2:** Реализовать, добавить в `locale_smoke_test`, ссылку в шапку (`layout.nav.insights`). Коммит: `git add app config test && git commit -m "Add insights pages"`.


---

## Этап 8. Обратная связь, About, фоновые задачи

### Task 8.1 [EXPENSIVE]: анонимная обратная связь

**Files:** Create: `db/migrate/<timestamp>_create_feedback_messages.rb`, `app/models/feedback_message.rb`, `app/controllers/feedback_messages_controller.rb`, `app/views/feedback_messages/new.html.erb`, `config/locales/feedback.{en,ru}.yml`, `test/models/feedback_message_test.rb`, `test/controllers/feedback_messages_controller_test.rb`

Поведение:
- Модель: `kind` из `%w[bug idea other]`, `body` 1 до 2000 символов, `locale` из `I18n.available_locales`. Поле `user_id` и IP в таблице отсутствуют.
- Контроллер: `allow_unauthenticated_access`, `rate_limit to: 5, within: 1.hour, only: :create` (счётчик в кэше по IP; в test-окружении проверить, что `config.cache_store` не `:null_store`, иначе в тесте задать `ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new`).
- Поле-ловушка `website` (скрыто через CSS, `tabindex=-1`, `autocomplete=off`). Непустое значение: ответ выглядит как успех, запись не создаётся.
- `params.expect(feedback_message: [:body, :kind])`. Язык берётся из `I18n.locale`, не из параметров.
- Текст над полем: не пишите личные данные. Вывод только через ERB без `html_safe`.
- [ ] **Step 1:** Тесты: `creates message with locale from URL`, `rejects body over 2000`, `rejects empty body`, `rejects unknown kind`, `honeypot silently drops message`, `6th request in an hour is throttled`, `no user_id or ip stored` (список колонок таблицы), `body with <script> is escaped in admin list` (после 8.2).
- [ ] **Step 2:** Реализовать, добавить `new_feedback_message_path` в `locale_smoke_test`. Коммит: `git add db app config test && git commit -m "Add anonymous feedback form"`.

### Task 8.2 [CHEAP]: админский список сообщений

**Files:** `app/controllers/admin/feedback_messages_controller.rb`, `app/views/admin/feedback_messages/index.html.erb`, `config/locales/admin.{en,ru}.yml`, `test/controllers/admin/feedback_messages_controller_test.rb`

- `index` (последние сверху, `limit(200)`) и `destroy`. Наследует `Admin::ApplicationController`.
- [ ] **Step 1:** Тесты: `admin sees list`, `player gets redirected`, `anonymous gets redirected`, `admin deletes message`. Реализовать, зелёный.
- [ ] **Step 2:** Коммит: `git add app config test && git commit -m "Add admin feedback list"`.

### Task 8.3 [CHEAP]: страница About

**Files:** `app/controllers/pages_controller.rb`, `app/views/pages/about.html.erb`, `config/locales/pages.{en,ru}.yml`, `test/controllers/pages_controller_test.rb`

Текст из `pages.about.*`, обязательные положения (по смыслу, формулировку пишет исполнитель):
- проект `mind_at_play`;
- результаты не медицинские и не научные, выводов и оценок сайт не делает;
- время реакции зависит от экрана, мыши, клавиатуры и браузера, сравнивайте прохождения на одном устройстве;
- тесты не собирают данные об устройстве; при входе в аккаунт сервер хранит технические данные сессии (IP и браузер), они удаляются вместе с аккаунтом;
- почта хранится только как хэш и нужна для подтверждения и сброса пароля;
- аккаунт можно удалить в любой момент, это стирает все данные.
- [ ] **Step 1:** Тест: `/en/about` и `/ru/about` отвечают 200 и содержат слова из каждого положения (по ключам, не по тексту). Добавить в `locale_smoke_test`, ссылку в подвал или шапку.
- [ ] **Step 2:** Коммит: `git add app config test && git commit -m "Add About page"`.

### Task 8.4 [EXPENSIVE]: фоновые очистки

**Files:** Create: `app/jobs/purge_stale_records_job.rb`, `test/jobs/purge_stale_records_job_test.rb`. Modify: `config/recurring.yml`

`PurgeStaleRecordsJob#perform` удаляет:
- прохождения без аккаунта (`game_sessions.user_id IS NULL`) старше 24 часов по `created_at`;
- неподтверждённых пользователей (`confirmed_at IS NULL`) старше 24 часов по `created_at`;
- сообщения обратной связи старше 90 дней.
- Прохождения с аккаунтом, подтверждённые пользователи и свежие записи не трогаются.
- В `config/recurring.yml` в секцию `production` добавить задачу `class: PurgeStaleRecordsJob`, `schedule: every hour`. Блок `production` уже существует, добавить рядом с `clear_solid_queue_finished_jobs`.
- [ ] **Step 1:** Тесты по каждому из пунктов выше (запись старше порога удаляется, запись моложе остаётся, прохождение с аккаунтом остаётся даже старое).
- [ ] **Step 2:** Реализовать, зелёный. Коммит: `git add app config test && git commit -m "Add periodic cleanup job"`.


---

## Этап 9. Статьи и админка

### Task 9.1 [EXPENSIVE]: модели статей и безопасный Markdown

**Files:** Create: `db/migrate/<timestamp>_create_articles.rb`, `db/migrate/<timestamp>_create_article_translations.rb`, `app/models/article.rb`, `app/models/article_translation.rb`, `app/helpers/markdown_helper.rb`, `test/models/article_test.rb`, `test/helpers/markdown_helper_test.rb`, `test/fixtures/articles.yml`, `test/fixtures/article_translations.yml`. Modify: `Gemfile`

- Добавить `gem "commonmarker"` с закреплённой точной версией, выполнить `bundle install`, затем `bin/bundler-audit`. Версию назвать в сообщении коммита.
- Таблицы по каркасу. `Article`: `has_many :translations, class_name: "ArticleTranslation", dependent: :destroy`, `accepts_nested_attributes_for :translations, reject_if: ->(a) { a[:title].blank? && a[:body].blank? }`. Валидации: `slug` по `/\A[a-z0-9-]+\z/`, `kind` из `%w[article news]`, обязательный перевод на `default_locale`. Scope `published` (`published_at <= Time.current`). `translation_for(locale)` отдаёт перевод на язык или на `default_locale`.
- `ArticleTranslation`: `locale` из `I18n.available_locales`, `title` и `body` обязательны.
- `render_markdown(text)`: commonmarker с отключённым сырым HTML (`render: { unsafe: false }`), затем `sanitize` с белым списком тегов (`p h2 h3 ul ol li strong em a blockquote code pre br`), атрибут только `href`, схемы только `http` и `https`.
- [ ] **Step 1:** Тесты модели: `slug format`, `requires default locale translation`, `published scope hides drafts and future dates`, `translation_for falls back to en`, `blank translation section is not created`. Тесты рендера: `script tag is removed`, `javascript: link is neutralized`, `raw html img onerror is dropped`, `plain markdown becomes html`.
- [ ] **Step 2:** Тесты падают, реализовать, зелёный. Коммит: `git add Gemfile Gemfile.lock db app test && git commit -m "Add articles with safe markdown"`.

### Task 9.2 [CHEAP]: публичные страницы статей и новостей

**Files:** `app/controllers/articles_controller.rb`, `app/views/articles/{index,show}.html.erb`, `config/locales/articles.{en,ru}.yml`, `test/controllers/articles_controller_test.rb`

- `index`: для `/news` kind `news` (через `defaults`), для `/articles` kind `article`. Значение `kind` сверяется со списком, иначе 404. Сортировка по `published_at desc`.
- `show`: `Article.published.find_by!(slug: params[:slug])`, нет или черновик: 404. Если перевода на язык нет, показывается английский и пометка `articles.fallback_notice`.
- Страницы публичные (`allow_unauthenticated_access`). Ссылки «Новости» и «Статьи» в шапке (`layout.nav.news`, `layout.nav.articles`).
- [ ] **Step 1:** Тесты: `draft returns 404`, `news and articles are separate lists`, `fallback notice appears for missing ru translation`, `unknown kind returns 404`, `body is rendered through markdown`. Добавить страницы в `locale_smoke_test`.
- [ ] **Step 2:** Реализовать, зелёный. Коммит: `git add app config test && git commit -m "Add public articles and news"`.


### Task 9.3 [EXPENSIVE]: админка статей

**Files:** `app/controllers/admin/articles_controller.rb`, `app/views/admin/articles/{index,new,edit,_form}.html.erb`, `config/locales/admin.{en,ru}.yml`, `test/controllers/admin/articles_controller_test.rb`

- Наследует `Admin::ApplicationController`. Действия `index new create edit update destroy`.
- Форма: `slug`, `kind`, чекбокс «опубликовать» (виртуальный атрибут `publish`: при `1` и пустом `published_at` ставит `Time.current`, при `0` обнуляет), секция на каждый язык из `available_locales` (`title`, `body`). `params.expect(article: [:slug, :kind, :publish, translations_attributes: [[:id, :locale, :title, :body]]])`. Пустая секция языка перевод не создаёт.
- Строки интерфейса из `admin.articles.*`.
- Первый админ: выяснить, как выдаётся роль, и записать команду в `README.md`, например `bin/rails runner "User.find_by(nickname: 'x').add_role(:admin)"`.
- [ ] **Step 1:** Тесты: `admin creates article with en and ru`, `empty ru section is not saved`, `publish checkbox sets published_at`, `player cannot access`, `anonymous cannot access`, `bad slug re-renders form`, `admin deletes article with translations`.
- [ ] **Step 2:** Реализовать, зелёный. Коммит: `git add app config test README.md && git commit -m "Add admin articles"`.

### Task 9.4 [CHEAP]: ссылка «Подробнее» на странице игры

**Files:** `app/views/games/show.html.erb`, `config/locales/articles.{en,ru}.yml`, `test/controllers/games_controller_test.rb`

- Если `@game.game_strategy.article_slug` задан и `Article.published.exists?(slug: ...)`, показать ссылку `articles.read_more` на `article_path(slug)`. Иначе ссылки нет и ошибки нет.
- [ ] **Step 1:** Тесты: `shows link for published article`, `hides link for draft`, `hides link when slug is nil`. Реализовать, зелёный.
- [ ] **Step 2:** Коммит: `git add app config test && git commit -m "Link games to articles"`.

---

## Самопроверка плана

**Покрытие спецификации.** Данные пользователя: 4.1–4.7. Отметка состояния: 5.1, 5.2. Прохождения и защита: 1.5, 8.4. Показатели и разбор: 6.1–6.6. Добавление игры: 1.1–1.8, 2.9. Категории: 1.2, 1.4, 7.2. Локализация: 2.1–2.10. Инфографика: 7.1, 7.2. Темы: 3.1–3.6. Статьи и админка: 9.1–9.4. Обратная связь: 8.1, 8.2. About: 8.3. Переименование: 0.1. Пароль в `database.yml`: 0.2.

**Решения владельца (приняты)**
- Несохранённые файлы (`db/seeds.rb`, `docs/plan_cline.md`, файлы adaptive-теста) можно менять и коммитить.
- PostgreSQL везде, секреты в `.env`, TDD, комментарии в коде на английском, документация на русском.
- Этапы запускаются по одному, начало каждого согласуется с владельцем. Одновременно один субагент.

**Остаётся открытым**
- Смена пароля к dev-базе: пароль уже в истории git, правка файла его не убирает. Решает владелец.
- Task 6.5: правила adaptive-теста (число попыток на часть, интервалы) проектируются вместе с владельцем.
- SMTP в production не настроен, без него письма подтверждения не уйдут. Хостинг и отправку писем в план не включили.

**Зависимости.** 1.1–1.4 нужны всем. 2.1 ломает существующие тесты (хелперы путей), поэтому идёт сразу после этапа 1. 4.1 и 4.2 коммитятся вместе. 6.6 требует 6.1 и хотя бы одну из 6.2–6.5. 7.x требует 5.x и 6.x. 8.4 требует 4.x.


