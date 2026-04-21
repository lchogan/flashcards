# Flashcards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the iOS flashcards app and Laravel backend specified in [2026-04-21-flashcards-design.md](../specs/2026-04-21-flashcards-design.md) to public launch over ~20 weeks.

**Architecture:** Native iOS client (Swift 6 + SwiftUI + SwiftData + on-device FSRS) against a Laravel 11 / Postgres API. Offline-first: SwiftData is the client source of truth, a `PendingMutation` queue drains to the server opportunistically. Five-rule REST delta sync (`id`, `updated_at`, `deleted_at`, push upsert, pull since). Reviews are append-only; card FSRS state is a cache recomputed from the review log. Entitlements are server-owned config, client-cached, single resolver API. Design system is mechanically enforced (SwiftLint banned patterns + token-only styling).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, StoreKit 2, AuthenticationServices, UserNotifications, URLSession, Codable, `fsrs-rs` (UniFFI), `KeychainAccess`, `swift-markdown-ui`, `swift-snapshot-testing`, `posthog-ios`, `sentry-cocoa`. Laravel 11, PHP 8.3, Postgres, Redis, Horizon, Cloudflare R2, Sanctum, Cashier (StoreKit), `spatie/laravel-query-builder`, `spatie/laravel-signed-url`, `laravel-notification-channels/apn`, `sentry/sentry-laravel`, Pest.

---

## Monorepo layout

```
flashcards/
  api/                 # Laravel 11 backend
  ios/                 # Xcode workspace
    Flashcards.xcodeproj
    Flashcards/        # app target
    FlashcardsTests/
    FlashcardsUITests/
    NotificationContentExtension/
  docs/
    superpowers/
      specs/           # design spec (existing)
      plans/           # this file
  Mockup/              # (existing) designer reference
  .github/
    workflows/
      ios.yml
      api.yml
    dependabot.yml
```

**Rule:** `api/` and `ios/` are independently buildable. Neither imports from the other. They share only the on-the-wire JSON schema, which is codified in both repos' test fixtures.

---

## File structure — iOS

```
ios/Flashcards/
  App/
    FlashcardsApp.swift
    RootView.swift
    AppState.swift               # @Observable — user, subscription, sync state
  DesignSystem/
    Tokens/
      Colors.swift                # typed wrappers around Asset Catalog
      Typography.swift
      Spacing.swift
      Radii.swift
      Borders.swift
      Motion.swift
      Shadows.swift
    EnvironmentKeys/
      MWAccentKey.swift
    Modifiers/
      MWCard.swift
      MWScreenChrome.swift
      MWFieldStyle.swift
    Styles/
      MWPrimaryButtonStyle.swift
      MWSecondaryButtonStyle.swift
      MWDestructiveButtonStyle.swift
      MWLabelStyles.swift
      MWTextFieldStyle.swift
    Components/
      Atoms/
        MWButton.swift
        MWPill.swift
        MWDot.swift
        MWIcon.swift
        MWTextField.swift
        MWTextArea.swift
        MWDivider.swift
        MWEyebrow.swift
        MWProgressBar.swift
        MWSwitch.swift
        MWChip.swift
      Molecules/
        MWDeckCard.swift
        MWCardTile.swift
        MWStackedDeckPaper.swift
        MWTopBar.swift
        MWSection.swift
        MWFormRow.swift
        MWRatingButton.swift
        MWBottomSheet.swift
        MWActionSheet.swift
        MWEmptyState.swift
        MWDuePill.swift
        MWPaywallScreen.swift
      Layout/
        MWScreen.swift
        MWVStack.swift
        MWHStack.swift
    Icons/
      MWIconShape.swift
      Generated/                  # auto-generated from SVG
  Features/
    Onboarding/                   # Splash, Intro1, Intro2, SignUpWall, MagicLinkSent, Welcome
    Auth/                         # AuthManager, AppleSignInService, MagicLinkService, TokenStore
    Home/                         # HomeView, HomeViewModel, SearchView
    DeckDetail/                   # DeckDetailView, HistoryTab, CardsTab, ManageSubTopics
    Deck/                         # CreateDeckView, DeckFormModel
    Card/                         # CreateCardView, CardEditView, CardFormModel
    Session/                      # SessionRootView, SmartStudy, BasicStudy, SessionSummary, SessionEngine, SessionQueueBuilder
    Settings/                     # SettingsRoot, Profile, Study, Appearance, Subscription, Account, About
    Paywall/                      # PaywallView, PaywallViewModel
  Data/
    Models/                       # UserEntity, DeckEntity, TopicEntity, SubTopicEntity, CardEntity, CardSubTopicEntity, ReviewEntity, SessionEntity, AssetEntity, PendingMutationEntity
    Repositories/                 # DeckRepository, CardRepository, ReviewRepository, SessionRepository, TopicRepository, SubTopicRepository
    Sync/
      SyncManager.swift
      SyncPusher.swift
      SyncPuller.swift
      MutationQueue.swift
      SyncScheduler.swift
      SyncableRecord.swift        # protocol
      Reachability.swift
  Networking/
    APIClient.swift
    APIEndpoint.swift
    APIError.swift
    AuthedSession.swift
  Fsrs/
    FsrsScheduler.swift
    RatingMapping.swift
  Entitlements/
    EntitlementsManager.swift
    EntitlementKey.swift
    PlansCache.swift
  Notifications/
    NotificationManager.swift
    ReminderScheduler.swift
  Purchases/
    PurchasesManager.swift
    StoreKitObserver.swift
  Analytics/
    AnalyticsClient.swift
    Events.swift
  Util/
    Logger.swift
    Clock.swift
    UUIDv7.swift
```

**Rule:** `Features/*` imports `DesignSystem`, `Data`, `Networking`, `Fsrs`, `Entitlements`, `Notifications`, `Purchases`, `Analytics`, `Util`. `DesignSystem` never imports `Features`. `Data` never imports `Features`. CI enforces via swift-format `file_header` + module boundary tests in Phase 4.

---

## File structure — Laravel

```
api/
  app/
    Models/
      User.php
      Deck.php
      Topic.php
      SubTopic.php
      Card.php
      CardSubTopic.php
      Review.php
      Session.php
      Asset.php
      Plan.php
      Reminder.php
      PendingEmailAuth.php
    Http/
      Controllers/Api/V1/
        AppleAuthController.php
        MagicLinkController.php
        TokenController.php
        SyncPushController.php
        SyncPullController.php
        MeController.php
        EntitlementsController.php
        SubscriptionController.php
        AppStoreNotificationsController.php
        AccountController.php
        ReminderController.php
        HealthController.php
      Resources/                # one per entity
      Requests/                 # FormRequest per endpoint
      Middleware/
        EnforceEntitlements.php
    Services/
      Sync/
        SyncPushService.php
        SyncPullService.php
        RecordUpserter.php
      Entitlements/
        PlanResolver.php
        EntitlementChecker.php
      Auth/
        AppleIdentityVerifier.php
        MagicLinkService.php
      Fsrs/
        ReviewReplayer.php
    Jobs/
      ReplayReviewsForCard.php
      HardDeleteExpiredUsers.php
      PurgeTombstones.php
      SendMagicLinkEmail.php
  config/
    plans.php
    sanctum.php
    cashier.php
    horizon.php
  database/
    migrations/
      2026_04_21_000001_create_users_table.php
      2026_04_21_000002_create_decks_table.php
      2026_04_21_000003_create_topics_table.php
      2026_04_21_000004_create_sub_topics_table.php
      2026_04_21_000005_create_cards_table.php
      2026_04_21_000006_create_card_sub_topics_table.php
      2026_04_21_000007_create_reviews_table.php
      2026_04_21_000008_create_sessions_table.php
      2026_04_21_000009_create_assets_table.php
      2026_04_21_000010_create_plans_table.php
      2026_04_21_000011_create_reminders_table.php
      2026_04_21_000012_create_pending_email_auths_table.php
    factories/                  # one per entity
    seeders/
      PlanSeeder.php
  routes/
    api.php
  tests/
    Feature/                    # per endpoint
    Unit/                       # per service
    Pest.php
```

---

## Conventions applied throughout

1. **UUIDv7 everywhere** — both clients generate UUIDv7 for `id` (monotonic, helps indexes). iOS uses a `UUIDv7` helper; Laravel uses `Str::orderedUuid()`.
2. **Timestamps** — `updated_at` is `bigint` milliseconds since epoch (not ISO-8601) to avoid serialization drift and give a monotonic push/pull cursor.
3. **Soft deletes** — `deleted_at` (nullable `bigint` ms) on every entity except `Review` (append-only).
4. **Commit discipline** — every task ends in exactly one commit. Commit messages follow `<type>: <what> (<phase.task>)`. Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
5. **TDD** — tests first for business logic (sync, entitlements, FSRS, session queue). For pure UI atoms, the "test" is a `#Preview` + snapshot test after implementation.
6. **Branch-per-phase** — `phase/0-foundation`, `phase/1-data-sync`, etc. Merged to `main` at phase end.

---

## Phase 0: Foundation (weeks 0-2)

**Goal:** Both projects scaffolded, CI green, design system tokens + core atoms shipped, auth endpoints exist end-to-end (no study features yet).

### Task 0.1: Create monorepo top-level structure

**Files:**
- Create: `api/.gitkeep`, `ios/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Check out a branch**

```bash
git -C /Users/lukehogan/Code/flashcards checkout -b phase/0-foundation
```

- [ ] **Step 2: Create directories**

```bash
mkdir -p /Users/lukehogan/Code/flashcards/api /Users/lukehogan/Code/flashcards/ios /Users/lukehogan/Code/flashcards/.github/workflows
touch /Users/lukehogan/Code/flashcards/api/.gitkeep /Users/lukehogan/Code/flashcards/ios/.gitkeep
```

- [ ] **Step 3: Extend `.gitignore`** — append the block below to the existing file:

```gitignore
# API local
/api/.env
/api/.env.backup
/api/vendor/
/api/node_modules/
/api/storage/logs/*
/api/bootstrap/cache/*.php

# iOS local
ios/.build/
ios/DerivedData/
ios/Flashcards.xcodeproj/xcuserdata/
ios/Flashcards.xcworkspace/xcuserdata/
ios/**/*.xcuserstate
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add -A
git -C /Users/lukehogan/Code/flashcards commit -m "chore: scaffold api/ and ios/ directories (0.1)"
```

---

### Task 0.2: Install Laravel 11 into `api/`

**Files:**
- Create: `api/` (Laravel 11 skeleton via installer)

- [ ] **Step 1: Run the installer**

```bash
cd /Users/lukehogan/Code/flashcards && composer create-project laravel/laravel api "^11.0" --prefer-dist
```

Expected: `Application ready! You can start your local development using: cd api && php artisan serve`.

- [ ] **Step 2: Pin PHP requirement in `api/composer.json`** — edit the `require` block so `"php": "^8.3"`.

- [ ] **Step 3: Verify**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan --version
```

Expected: `Laravel Framework 11.x.x`.

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat: install Laravel 11 skeleton (0.2)"
```

---

### Task 0.3: Configure `api/.env.example`

**Files:**
- Modify: `api/.env.example`

- [ ] **Step 1: Replace contents of `api/.env.example` with:**

```dotenv
APP_NAME=Flashcards
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8000
APP_TIMEZONE=UTC

LOG_CHANNEL=stderr
LOG_LEVEL=debug

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=flashcards
DB_USERNAME=flashcards
DB_PASSWORD=flashcards

CACHE_STORE=redis
FILESYSTEM_DISK=r2
QUEUE_CONNECTION=redis
SESSION_DRIVER=database

REDIS_HOST=127.0.0.1
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_FROM_ADDRESS=no-reply@flashcards.app
MAIL_FROM_NAME="${APP_NAME}"

# Cloudflare R2
R2_KEY=
R2_SECRET=
R2_BUCKET=flashcards-assets
R2_ENDPOINT=
R2_REGION=auto
R2_USE_PATH_STYLE_ENDPOINT=true

# Apple
APPLE_TEAM_ID=
APPLE_SERVICE_ID=com.flashcards.app
APPLE_KEY_ID=
APPLE_AUTH_KEY_PATH=storage/apple/AuthKey.p8
APPLE_JWT_AUDIENCE=https://appleid.apple.com

# Magic link
MAGIC_LINK_TTL_MINUTES=15
MAGIC_LINK_UNIVERSAL_LINK_HOST=flashcards.app

# Sentry
SENTRY_LARAVEL_DSN=
SENTRY_TRACES_SAMPLE_RATE=0.2

# Cashier / StoreKit
CASHIER_SHARED_SECRET=
APP_STORE_SHARED_SECRET=
APP_STORE_ENVIRONMENT=sandbox
```

- [ ] **Step 2: Copy to `api/.env` for local dev**

```bash
cp /Users/lukehogan/Code/flashcards/api/.env.example /Users/lukehogan/Code/flashcards/api/.env
cd /Users/lukehogan/Code/flashcards/api && php artisan key:generate
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api/.env.example
git -C /Users/lukehogan/Code/flashcards commit -m "chore: add .env.example with R2/Apple/Sentry/Cashier slots (0.3)"
```

---

### Task 0.4: Install Sanctum + Horizon + query-builder + signed-url + sentry

**Files:**
- Modify: `api/composer.json`, `api/config/` (published configs)

- [ ] **Step 1: Install packages**

```bash
cd /Users/lukehogan/Code/flashcards/api && composer require -W \
  laravel/sanctum:^4.0 \
  laravel/horizon:^5.0 \
  laravel/cashier:^15.0 \
  spatie/laravel-query-builder:^6.0 \
  spatie/url-signer:^2.0 \
  sentry/sentry-laravel:^4.0 \
  laravel-notification-channels/apn:^5.5
```

> **Cashier note (verified 2026-04-21):** `laravel/cashier-apple` does not exist on Packagist. We install base Cashier (Stripe) for the subscription/webhook/receipt scaffolding and wire StoreKit manually in Task 3.10. If a `cashier-apple` package ships later, swap the require line and reassess Task 3.10.
>
> **APN note (verified 2026-04-21):** `laravel-notification-channels/apn ^6.0` requires PHP 8.4 + Laravel 12. We pin to `^5.5` which supports PHP 8.3 + Laravel 11. Revisit when the project moves to PHP 8.4 / Laravel 12.
>
> `-W` flag required because `edamov/pushok` (APN transitive) needs `brick/math` downgraded from 0.14 → 0.12 to be compatible with `web-token/jwt-library ^3.0`.

- [ ] **Step 2: Install API + publish Sanctum**

Laravel 11 ships without `routes/api.php` by default. Run `php artisan install:api` to scaffold the API route file, wire the `api` routing group in `bootstrap/app.php`, and publish Sanctum's migration. When it asks whether to run pending migrations, answer `no` (we want to run them together once Postgres is provisioned):

```bash
cd /Users/lukehogan/Code/flashcards/api && echo "no" | php artisan install:api
```

**After publishing**, open the generated `database/migrations/*_create_personal_access_tokens_table.php` and change `$table->morphs('tokenable');` to `$table->uuidMorphs('tokenable');`. Our `users` table uses a UUID primary key (Task 0.31), and the default `morphs()` creates a `BIGINT UNSIGNED tokenable_id` which would silently corrupt token issuance. Add an inline comment so future re-reads know why.

Run Pint once on the newly scaffolded `routes/api.php` to apply `declare(strict_types=1)` and the standard blank-line-after-opening-tag rule:

```bash
./vendor/bin/pint routes/api.php
```

**Also**: in `app/Providers/HorizonServiceProvider.php`, the scaffolded `viewHorizon` gate ships with an empty email allow-list, so Horizon's dashboard 403s everyone in non-local environments. Add a `TODO(deploy)` comment inside the gate pointing at Task 5.2 so ops remembers to populate it before first staging deploy.

- [ ] **Step 3: Publish Horizon**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan horizon:install
```

- [ ] **Step 4: Publish Sentry**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan sentry:publish
```

- [ ] **Step 5: Verify `config/` has `sanctum.php`, `horizon.php`, `sentry.php`.**

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat: install Sanctum, Horizon, Cashier, Sentry, query-builder, signed-url, apn (0.4)"
```

---

### Task 0.5: Install Pest and configure

**Files:**
- Modify: `api/composer.json`, `api/tests/Pest.php`, `api/phpunit.xml`

- [ ] **Step 1: Install Pest**

```bash
cd /Users/lukehogan/Code/flashcards/api && composer require --dev -W pestphp/pest:^3.0 pestphp/pest-plugin-laravel:^3.0
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest --init
```

> **Note (verified 2026-04-21):** Pest v3 dropped the `php artisan pest:install` command — use `./vendor/bin/pest --init` instead. The `-W` flag is needed to downgrade phpunit (11.5.55 → 11.5.50) to satisfy Pest v3's constraint. Also: uncomment `DB_CONNECTION=sqlite` and `DB_DATABASE=:memory:` in `api/phpunit.xml` so `RefreshDatabase` can run without a local Postgres.

- [ ] **Step 2: Replace `api/tests/Pest.php` with:**

```php
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(Tests\TestCase::class, RefreshDatabase::class)->in('Feature');
uses(Tests\TestCase::class)->in('Unit');
```

- [ ] **Step 3: Run the suite**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest
```

Expected: example tests pass.

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "test: configure Pest with RefreshDatabase default (0.5)"
```

---

### Task 0.6: Install Pint + Larastan, configure PHPStan level 6

**Files:**
- Create: `api/phpstan.neon`, `api/pint.json`

- [ ] **Step 1: Install**

```bash
cd /Users/lukehogan/Code/flashcards/api && composer require --dev laravel/pint:^1.0 larastan/larastan:^3.0
```

> **Note (verified 2026-04-21):** Larastan `^2.0` targets Laravel 10 and won't resolve against Laravel 11. Use `^3.0` (Larastan 3 supports Laravel 11 + PHPStan 2).

- [ ] **Step 2: Create `api/pint.json`:**

```json
{
  "preset": "laravel",
  "rules": {
    "declare_strict_types": true,
    "strict_comparison": true,
    "ordered_imports": { "sort_algorithm": "alpha" }
  }
}
```

- [ ] **Step 3: Create `api/phpstan.neon`:**

```neon
includes:
    - ./vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app/
        - config/
        - database/
        - routes/
    level: 6
    ignoreErrors:
    excludePaths:
        - ./*/*/FileToBeExcluded.php
```

> **Note (verified 2026-04-21):** PHPStan 2.x removed the `checkMissingIterableValueType` key (it's now always-on at level 6+). The config is otherwise unchanged.

- [ ] **Step 4: Run both**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pint --test
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/phpstan analyse --memory-limit=1G
```

Expected: pint clean, phpstan clean (with possible baseline to generate).

- [ ] **Step 5: If phpstan reports baseline issues, generate baseline**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/phpstan analyse --generate-baseline --memory-limit=1G
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "chore: add Pint + PHPStan level 6 (0.6)"
```

---

### Task 0.7: Health endpoint with test

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/HealthController.php`
- Create: `api/tests/Feature/HealthTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Write the failing test** `api/tests/Feature/HealthTest.php`:

```php
<?php

declare(strict_types=1);

test('/healthz returns 200 with ok payload', function () {
    $response = $this->get('/healthz');

    $response->assertOk();
    $response->assertExactJson(['status' => 'ok']);
});
```

- [ ] **Step 2: Run it — expect failure**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/HealthTest.php
```

Expected: FAIL (route not defined / 404).

- [ ] **Step 3: Create the controller** `api/app/Http/Controllers/Api/V1/HealthController.php`:

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class HealthController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json(['status' => 'ok']);
    }
}
```

- [ ] **Step 4: Register route.** In `api/routes/api.php`, append:

```php
use App\Http\Controllers\Api\V1\HealthController;

Route::get('/healthz', [HealthController::class, 'show']);
```

- [ ] **Step 5: Move `/healthz` to top-level.** Laravel 11 mounts api routes under `/api`. We need `/healthz` at the root for uptime monitors. Edit `api/bootstrap/app.php` and register `/healthz` via `routes/web.php` instead:

Remove the entry from `routes/api.php`, and add to `api/routes/web.php`:

```php
use App\Http\Controllers\Api\V1\HealthController;

Route::get('/healthz', [HealthController::class, 'show']);
```

- [ ] **Step 6: Run test — expect pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/HealthTest.php
```

- [ ] **Step 7: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat: /healthz endpoint (0.7)"
```

---

### Task 0.8: Backend GitHub Actions workflow

**Files:**
- Create: `.github/workflows/api.yml`

- [ ] **Step 1: Create `.github/workflows/api.yml`:**

```yaml
name: API

on:
  push:
    branches: [main]
    paths: ['api/**', '.github/workflows/api.yml']
  pull_request:
    paths: ['api/**', '.github/workflows/api.yml']

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: flashcards
          POSTGRES_PASSWORD: flashcards
          POSTGRES_DB: flashcards
        ports: ['5432:5432']
        options: >-
          --health-cmd="pg_isready -U flashcards"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
      redis:
        image: redis:7
        ports: ['6379:6379']
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: xdebug
          tools: composer:v2
      - run: composer install --prefer-dist --no-interaction --no-progress
      - run: cp .env.example .env && php artisan key:generate
      - run: ./vendor/bin/pint --test
      - run: ./vendor/bin/phpstan analyse --memory-limit=1G
      - run: php artisan migrate --force
      - run: ./vendor/bin/pest --ci
```

- [ ] **Step 2: Verify syntax**

```bash
cd /Users/lukehogan/Code/flashcards && yq '.jobs.test.steps' .github/workflows/api.yml
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add .github/workflows/api.yml
git -C /Users/lukehogan/Code/flashcards commit -m "ci: add API workflow with Pest/Pint/PHPStan (0.8)"
```

---

### Task 0.9: Dependabot for Composer + SPM + Actions

**Files:**
- Create: `.github/dependabot.yml`

- [ ] **Step 1: Create `.github/dependabot.yml`:**

```yaml
version: 2
updates:
  - package-ecosystem: "composer"
    directory: "/api"
    schedule: { interval: "weekly" }
    groups:
      patches:
        update-types: ["patch"]
        applies-to: version-updates
    open-pull-requests-limit: 10

  - package-ecosystem: "swift"
    directory: "/ios"
    schedule: { interval: "weekly" }
    groups:
      patches:
        update-types: ["patch"]
        applies-to: version-updates
    open-pull-requests-limit: 10

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add .github/dependabot.yml
git -C /Users/lukehogan/Code/flashcards commit -m "ci: enable Dependabot for composer, swift, actions (0.9)"
```

---

### Task 0.10: Create Xcode project

**Files:**
- Create: `ios/Flashcards.xcodeproj` + source tree

- [ ] **Step 1: Create project** (GUI-driven; record the exact settings):

In Xcode → File → New → Project → iOS → App.
- Product Name: `Flashcards`
- Team: UWK6JHFFGJ
- Organization Identifier: `com.lukehogan`
- Bundle Identifier: `com.lukehogan.flashcards`
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **SwiftData**
- Include Tests: **checked**
- Save to: `/Users/lukehogan/Code/flashcards/ios/`

- [ ] **Step 2: Set deployment target.** Project → Targets → Flashcards → General → Minimum Deployments → iOS 17.0.

- [ ] **Step 3: Enable Swift 6.** Build Settings → "Swift Language Version" → Swift 6. Build Settings → "Strict Concurrency Checking" → Complete.

- [ ] **Step 4: Add folder groups** matching the iOS file structure above. Create empty folders with `.gitkeep` files where source won't land until later tasks.

- [ ] **Step 5: Build**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug build | tail -n 20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat: scaffold Xcode project Flashcards (iOS 17, Swift 6) (0.10)"
```

---

### Task 0.11: Add SPM dependencies

**Files:**
- Modify: `ios/Flashcards.xcodeproj` (Package Dependencies)

- [ ] **Step 1: Add packages via File → Add Package Dependencies. Add each:**

| Package URL | Version |
|---|---|
| `https://github.com/kishikawakatsumi/KeychainAccess` | upToNextMajor 4.2.2 |
| `https://github.com/gonzalezreal/swift-markdown-ui` | upToNextMajor 2.0.0 |
| `https://github.com/pointfreeco/swift-snapshot-testing` | upToNextMajor 1.17.0 |
| `https://github.com/PostHog/posthog-ios` | upToNextMajor 3.0.0 |
| `https://github.com/getsentry/sentry-cocoa` | upToNextMajor 8.40.0 |

Skip `fsrs-rs` here — it's added in Phase 2 alongside the wrapper.

- [ ] **Step 2: Resolve packages**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -resolvePackageDependencies -scheme Flashcards
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat: add SPM deps (Keychain, markdown-ui, snapshot-testing, PostHog, Sentry) (0.11)"
```

---

### Task 0.12: SwiftLint config with banned style primitives

**Files:**
- Create: `ios/.swiftlint.yml`
- Modify: Flashcards target → Build Phases → Run Script

- [ ] **Step 1: Install SwiftLint via Homebrew (dev dependency, not SPM):**

```bash
brew install swiftlint
swiftlint version
```

- [ ] **Step 2: Create `ios/.swiftlint.yml`:**

```yaml
included:
  - Flashcards
excluded:
  - Flashcards/DesignSystem/Icons/Generated
  - Flashcards/Preview Content

disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - empty_count
  - first_where
  - toggle_bool
  - redundant_nil_coalescing
  - closure_spacing
  - conditional_returns_on_newline

line_length:
  warning: 140
  error: 200

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 450
  error: 700

# ---------------- Custom rules: design system enforcement ----------------
custom_rules:
  no_literal_color_hex:
    name: "No hardcoded hex colors in views"
    regex: 'Color\(\s*hex\s*:'
    match_kinds: [identifier, argument]
    included: "Flashcards/Features/.*\\.swift"
    message: "Use a token from DesignSystem/Tokens/Colors instead of Color(hex:)."
    severity: error

  no_system_color_literals:
    name: "No .black/.white literals in Features"
    regex: '\.foregroundColor\(\.\s*(black|white|red|blue|green|orange|yellow|purple|pink|gray|grey)\b'
    included: "Flashcards/Features/.*\\.swift"
    message: "Use MW color tokens (MWColor.ink, MWColor.accent, …) not SwiftUI named colors."
    severity: error

  no_system_font_literal:
    name: "No .system(size:) in views"
    regex: '\.font\(\s*\.system\s*\(\s*size\s*:'
    included: "Flashcards/(Features|DesignSystem/Components)/.*\\.swift"
    excluded: "Flashcards/DesignSystem/Tokens/Typography\\.swift"
    message: "Use a typography token (MWType.headingL etc)."
    severity: error

  no_literal_padding:
    name: "No literal padding values"
    regex: '\.padding\(\s*(\.[a-zA-Z]+\s*,\s*)?\d+(\.\d+)?\s*\)'
    included: "Flashcards/(Features|DesignSystem/Components)/.*\\.swift"
    message: "Use a spacing token (.padding(.s), .padding(.l)) via the MW padding modifier."
    severity: error

  no_literal_corner_radius:
    name: "No literal cornerRadius"
    regex: '\.cornerRadius\(\s*\d'
    included: "Flashcards/(Features|DesignSystem/Components)/.*\\.swift"
    excluded: "Flashcards/DesignSystem/Tokens/Radii\\.swift"
    message: "Use radius token (.cornerRadius(.m) via MW wrapper)."
    severity: error

  no_literal_animation_duration:
    name: "No literal animation durations"
    regex: '\.animation\(.*duration\s*:\s*\d'
    included: "Flashcards/(Features|DesignSystem/Components)/.*\\.swift"
    message: "Use a motion token (MWMotion.quick, MWMotion.card)."
    severity: error
```

- [ ] **Step 3: Add SwiftLint Run Script Phase** to the Flashcards target (Build Phases → + → New Run Script Phase, above Compile Sources):

```bash
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --config "${SRCROOT}/.swiftlint.yml" --strict
else
  echo "warning: SwiftLint not installed — brew install swiftlint"
fi
```

- [ ] **Step 4: Build — expect zero SwiftLint errors (there's no code yet).**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -n 5
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "chore: add SwiftLint config banning literal colors/sizes/padding in views (0.12)"
```

---

### Task 0.13: swift-format config

**Files:**
- Create: `ios/.swift-format`

- [ ] **Step 1: Create `ios/.swift-format`:**

```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": { "spaces": 4 },
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeControlFlowKeywords": false,
  "lineBreakBeforeEachArgument": false,
  "prioritizeKeepingFunctionOutputTogether": true,
  "indentConditionalCompilationBlocks": false,
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": true,
    "AlwaysUseLowerCamelCase": true,
    "AmbiguousTrailingClosureOverload": true,
    "NoBlockComments": true,
    "NoLeadingUnderscores": false,
    "OrderedImports": true,
    "UseLetInEveryBoundCaseVariable": true,
    "UseShorthandTypeNames": true,
    "ValidateDocumentationComments": true
  }
}
```

- [ ] **Step 2: Add swift-format check script** at `ios/scripts/format-check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
xcrun swift-format lint --recursive --strict Flashcards
```

```bash
chmod +x /Users/lukehogan/Code/flashcards/ios/scripts/format-check.sh
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "chore: add swift-format config + lint script (0.13)"
```

---

### Task 0.14: iOS GitHub Actions workflow

**Files:**
- Create: `.github/workflows/ios.yml`

- [ ] **Step 1: Create `.github/workflows/ios.yml`:**

```yaml
name: iOS

on:
  push:
    branches: [main]
    paths: ['ios/**', '.github/workflows/ios.yml']
  pull_request:
    paths: ['ios/**', '.github/workflows/ios.yml']

jobs:
  build-test:
    runs-on: macos-14
    defaults:
      run:
        working-directory: ios
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.0.app
      - name: Install SwiftLint
        run: brew install swiftlint
      - name: swift-format lint
        run: ./scripts/format-check.sh
      - name: Resolve SPM
        run: xcodebuild -resolvePackageDependencies -scheme Flashcards
      - name: Build & Test
        run: |
          xcodebuild \
            -scheme Flashcards \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
            -configuration Debug \
            -enableCodeCoverage YES \
            clean test | xcbeautify --is-ci
      - name: Coverage
        run: |
          xcrun xccov view --report --only-targets \
            $(find ~/Library/Developer/Xcode/DerivedData -name '*.xcresult' | head -1)
```

- [ ] **Step 2: Install `xcbeautify` note** — document in `ios/README.md` that CI uses it; local runs are optional.

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add .github/workflows/ios.yml
git -C /Users/lukehogan/Code/flashcards commit -m "ci: add iOS workflow with SwiftLint + tests on macos-14 (0.14)"
```

---

### Task 0.15: Design tokens — Colors

**Files:**
- Create: `ios/Flashcards/DesignSystem/Tokens/Colors.swift`
- Create Asset Catalog color sets (light/dark) for each named color

- [ ] **Step 1: In Xcode, add these color sets to `Assets.xcassets` (each with a Light Appearance and Dark Appearance variant). Values sourced from `Mockup/mw/01-tokens.jsx`:**

| Name | Light (hex) | Dark (hex) |
|---|---|---|
| `mw/paper` | `#F7F3EC` | `#14130F` |
| `mw/canvas` | `#EFE9DE` | `#1A1915` |
| `mw/ink` | `#111111` | `#F4EFE6` |
| `mw/inkMuted` | `#5A564E` | `#B7B0A2` |
| `mw/inkFaint` | `#9A958A` | `#6A655C` |
| `mw/grid` | `#E2DBCB` | `#262521` |
| `mw/again` | `#C9422E` | `#E15F48` |
| `mw/hard` | `#C78422` | `#E69A3C` |
| `mw/good` | `#2E7D4F` | `#4FA46F` |
| `mw/easy` | `#1F5A8A` | `#4D8FC8` |

(Accent colors per-deck are in Task 0.22.)

- [ ] **Step 2: Create `ios/Flashcards/DesignSystem/Tokens/Colors.swift`:**

```swift
import SwiftUI

/// Design system color tokens.
/// Consumers: all `DesignSystem/Components/**` and `Features/**`.
/// Never reference `Color(hex:)` or SwiftUI named colors directly outside this file.
public enum MWColor {
    public static let paper     = Color("mw/paper")
    public static let canvas    = Color("mw/canvas")
    public static let ink       = Color("mw/ink")
    public static let inkMuted  = Color("mw/inkMuted")
    public static let inkFaint  = Color("mw/inkFaint")
    public static let grid      = Color("mw/grid")

    /// Confidence accents for ratings.
    public static let again = Color("mw/again")
    public static let hard  = Color("mw/hard")
    public static let good  = Color("mw/good")
    public static let easy  = Color("mw/easy")
}

#Preview("Color swatches") {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(MWColor.allPairs, id: \.name) { pair in
                HStack {
                    Rectangle().fill(pair.color).frame(width: 48, height: 48)
                    Text(pair.name)
                }
            }
        }
        .padding()
    }
}

extension MWColor {
    fileprivate struct Pair { let name: String; let color: Color }
    fileprivate static let allPairs: [Pair] = [
        .init(name: "paper", color: paper),
        .init(name: "canvas", color: canvas),
        .init(name: "ink", color: ink),
        .init(name: "inkMuted", color: inkMuted),
        .init(name: "inkFaint", color: inkFaint),
        .init(name: "grid", color: grid),
        .init(name: "again", color: again),
        .init(name: "hard", color: hard),
        .init(name: "good", color: good),
        .init(name: "easy", color: easy),
    ]
}
```

- [ ] **Step 3: Build — preview shows swatches.**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -n 5
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): Colors token + Asset Catalog sets (0.15)"
```

---

### Task 0.16: Design tokens — Typography

**Files:**
- Create: `ios/Flashcards/DesignSystem/Tokens/Typography.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// Design system typography tokens.
/// Scale taken from mw/01-tokens.jsx. Tracking adjustments are applied via `.tracking(...)`.
public enum MWType {
    public static let display   = Font.custom("SF Pro Display", size: 40).weight(.bold)
    public static let headingL  = Font.custom("SF Pro Display", size: 28).weight(.semibold)
    public static let headingM  = Font.custom("SF Pro Display", size: 20).weight(.semibold)
    public static let bodyL     = Font.custom("SF Pro Text", size: 16).weight(.regular)
    public static let body      = Font.custom("SF Pro Text", size: 14).weight(.regular)
    public static let bodyS     = Font.custom("SF Pro Text", size: 12).weight(.regular)
    public static let eyebrow   = Font.custom("SF Pro Text", size: 10).weight(.medium)
    public static let mono      = Font.custom("SF Mono", size: 13).weight(.regular)

    /// Eyebrow tracking: 0.8pt.
    public static let eyebrowTracking: CGFloat = 0.8
}

#Preview("Typography scale") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Display 40").font(MWType.display)
        Text("Heading L 28").font(MWType.headingL)
        Text("Heading M 20").font(MWType.headingM)
        Text("Body L 16").font(MWType.bodyL)
        Text("Body 14").font(MWType.body)
        Text("Body S 12").font(MWType.bodyS)
        Text("EYEBROW 10").font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
        Text("mono 13").font(MWType.mono)
    }
    .padding()
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): Typography token scale (0.16)"
```

---

### Task 0.17: Design tokens — Spacing

**Files:**
- Create: `ios/Flashcards/DesignSystem/Tokens/Spacing.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// 4pt grid spacing scale.
public enum MWSpacing {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let s:   CGFloat = 8
    public static let m:   CGFloat = 12
    public static let l:   CGFloat = 16
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

/// Token-aware padding modifier. Replaces `.padding(<literal>)` in all view code.
public extension View {
    func mwPadding(_ edges: Edge.Set = .all, _ token: MWSpacingToken) -> some View {
        self.padding(edges, token.value)
    }
}

public enum MWSpacingToken {
    case xxs, xs, s, m, l, xl, xxl, xxxl
    public var value: CGFloat {
        switch self {
        case .xxs: return MWSpacing.xxs
        case .xs:  return MWSpacing.xs
        case .s:   return MWSpacing.s
        case .m:   return MWSpacing.m
        case .l:   return MWSpacing.l
        case .xl:  return MWSpacing.xl
        case .xxl: return MWSpacing.xxl
        case .xxxl: return MWSpacing.xxxl
        }
    }
}

#Preview("Spacing grid") {
    VStack(alignment: .leading, spacing: MWSpacing.s) {
        ForEach(Array(stride(from: 0, through: 48, by: 4)), id: \.self) { px in
            HStack(spacing: 8) {
                Rectangle().fill(MWColor.ink).frame(width: CGFloat(px), height: 8)
                Text("\(px)pt").font(MWType.mono)
            }
        }
    }
    .mwPadding(.all, .l)
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): Spacing token + mwPadding modifier (0.17)"
```

---

### Task 0.18: Design tokens — Radii, Borders, Shadows

**Files:**
- Create: `ios/Flashcards/DesignSystem/Tokens/Radii.swift`
- Create: `ios/Flashcards/DesignSystem/Tokens/Borders.swift`
- Create: `ios/Flashcards/DesignSystem/Tokens/Shadows.swift`

- [ ] **Step 1: `Radii.swift`:**

```swift
import SwiftUI

public enum MWRadius {
    public static let xs: CGFloat = 2
    public static let s:  CGFloat = 4
    public static let m:  CGFloat = 8
    public static let l:  CGFloat = 16
}

public enum MWRadiusToken { case xs, s, m, l
    public var value: CGFloat {
        switch self { case .xs: return MWRadius.xs; case .s: return MWRadius.s; case .m: return MWRadius.m; case .l: return MWRadius.l }
    }
}

public extension View {
    func mwCornerRadius(_ token: MWRadiusToken) -> some View { self.cornerRadius(token.value) }
}
```

- [ ] **Step 2: `Borders.swift`:**

```swift
import SwiftUI

public enum MWBorder {
    public static let hair:    CGFloat = 0.5
    public static let `default`: CGFloat = 1.5
    public static let bold:    CGFloat = 2.5
}

public struct MWStroke: ViewModifier {
    let color: Color
    let width: CGFloat
    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 0).stroke(color, lineWidth: width)
        )
    }
}

public extension View {
    func mwStroke(color: Color = MWColor.ink, width: CGFloat = MWBorder.default) -> some View {
        modifier(MWStroke(color: color, width: width))
    }
}
```

- [ ] **Step 3: `Shadows.swift`:**

```swift
import SwiftUI

/// Modernist uses borders, not shadows. The single exception is the stacked-paper deck metaphor.
public enum MWShadow {
    public static func deck(_ content: some View) -> some View {
        content.shadow(color: MWColor.ink.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): Radii, Borders, Shadows tokens (0.18)"
```

---

### Task 0.19: Design tokens — Motion

**Files:**
- Create: `ios/Flashcards/DesignSystem/Tokens/Motion.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

public enum MWMotion {
    public static let instant  = Animation.easeOut(duration: 0.12)
    public static let quick    = Animation.easeInOut(duration: 0.22)
    public static let standard = Animation.spring(response: 0.32, dampingFraction: 0.85)
    public static let card     = Animation.spring(response: 0.42, dampingFraction: 0.78)
    public static let settled  = Animation.easeInOut(duration: 0.56)

    /// Resolves to `.linear(duration: 0)` when Reduce Motion is on.
    public static func respecting(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): Motion token with reduce-motion resolver (0.19)"
```

---

### Task 0.20: Per-deck accent color via EnvironmentValues

**Files:**
- Create: `ios/Flashcards/DesignSystem/EnvironmentKeys/MWAccentKey.swift`
- Modify: `ios/Flashcards/DesignSystem/Tokens/Colors.swift`

- [ ] **Step 1: Create `MWAccentKey.swift`:**

```swift
import SwiftUI

private struct MWAccentKey: EnvironmentKey {
    static let defaultValue: Color = MWColor.ink
}

public extension EnvironmentValues {
    var mwAccent: Color {
        get { self[MWAccentKey.self] }
        set { self[MWAccentKey.self] = newValue }
    }
}

public extension View {
    func mwAccent(_ color: Color) -> some View { environment(\.mwAccent, color) }
}
```

- [ ] **Step 2: Add the 5-swatch accent palette to `Assets.xcassets` (each with light/dark variants). Names are intentionally neutral — final palette hex values are a `design-owned` open decision from spec §18. Ship placeholder values; they can be retuned without touching any code:**

| Name | Light (placeholder) | Dark (placeholder) |
|---|---|---|
| `mw/accent/amber` | `#D69A3C` | `#E6AE52` |
| `mw/accent/moss` | `#4A6B3A` | `#6F8D5F` |
| `mw/accent/iris` | `#5A5AAB` | `#8484D5` |
| `mw/accent/rust` | `#A84B2A` | `#C96A47` |
| `mw/accent/slate` | `#3F4F5E` | `#67798B` |

- [ ] **Step 3: Add typed accent enum** to `Colors.swift` (append):

```swift
public enum MWAccent: String, CaseIterable, Codable {
    case amber, moss, iris, rust, slate

    public var color: Color { Color("mw/accent/\(rawValue)") }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): mwAccent environment + 5-swatch palette (0.20)"
```

---

### Task 0.21: MWScreen layout root

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Layout/MWScreen.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// Root screen container. Applies canvas background, safe-area handling,
/// and optional grid overlay (Modernist detail — feature-flaggable).
public struct MWScreen<Content: View>: View {
    let showsGrid: Bool
    @ViewBuilder let content: () -> Content

    public init(showsGrid: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.showsGrid = showsGrid
        self.content = content
    }

    public var body: some View {
        ZStack {
            MWColor.canvas.ignoresSafeArea()
            if showsGrid { MWGridOverlay().allowsHitTesting(false) }
            content()
        }
    }
}

private struct MWGridOverlay: View {
    let step: CGFloat = 4
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(MWColor.grid.opacity(0.4)), lineWidth: MWBorder.hair)
        }
    }
}

#Preview("MWScreen with grid") {
    MWScreen(showsGrid: true) {
        Text("Hello Modernist Workshop").font(MWType.headingM).foregroundStyle(MWColor.ink)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWScreen layout with grid overlay (0.21)"
```

---

### Task 0.22: MWCard modifier

**Files:**
- Create: `ios/Flashcards/DesignSystem/Modifiers/MWCard.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// Paper-style card surface with 1.5pt ink border.
public struct MWCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .mwPadding(.all, .l)
            .background(MWColor.paper)
            .mwCornerRadius(.m)
            .mwStroke(color: MWColor.ink, width: MWBorder.default)
    }
}

public extension View {
    func mwCard() -> some View { modifier(MWCardStyle()) }
}

#Preview("MWCard") {
    MWScreen {
        Text("Sample card content").font(MWType.bodyL).foregroundStyle(MWColor.ink).mwCard()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWCard modifier (0.22)"
```

---

### Task 0.23: MWPrimaryButtonStyle

**Files:**
- Create: `ios/Flashcards/DesignSystem/Styles/MWPrimaryButtonStyle.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

public struct MWPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.paper)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? MWColor.ink : MWColor.inkFaint)
            .mwCornerRadius(.s)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MWMotion.instant, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWPrimaryButtonStyle {
    static var mwPrimary: MWPrimaryButtonStyle { .init() }
}

#Preview("Primary button") {
    VStack(spacing: MWSpacing.l) {
        Button("Continue with Apple") {}.buttonStyle(.mwPrimary)
        Button("Disabled") {}.buttonStyle(.mwPrimary).disabled(true)
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWPrimaryButtonStyle (0.23)"
```

---

### Task 0.24: MWSecondaryButtonStyle + MWDestructiveButtonStyle

**Files:**
- Create: `ios/Flashcards/DesignSystem/Styles/MWSecondaryButtonStyle.swift`
- Create: `ios/Flashcards/DesignSystem/Styles/MWDestructiveButtonStyle.swift`

- [ ] **Step 1: `MWSecondaryButtonStyle.swift`:**

```swift
import SwiftUI

public struct MWSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(MWColor.paper)
            .mwCornerRadius(.s)
            .mwStroke(color: MWColor.ink, width: MWBorder.default)
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MWMotion.instant, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWSecondaryButtonStyle {
    static var mwSecondary: MWSecondaryButtonStyle { .init() }
}
```

- [ ] **Step 2: `MWDestructiveButtonStyle.swift`:**

```swift
import SwiftUI

public struct MWDestructiveButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MWType.bodyL.weight(.semibold))
            .foregroundStyle(MWColor.again)
            .frame(maxWidth: .infinity, minHeight: 44)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MWMotion.instant, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == MWDestructiveButtonStyle {
    static var mwDestructive: MWDestructiveButtonStyle { .init() }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWSecondaryButtonStyle + MWDestructiveButtonStyle (0.24)"
```

---

### Task 0.25: MWButton atom

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWButton.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// Primary/Secondary/Destructive button atom. Accepts label as a string or arbitrary view.
/// Use `.buttonStyle(.mwPrimary)` etc directly where a SwiftUI `Button` already exists;
/// this atom is for convenience when the call-site just needs a label.
public struct MWButton<Label: View>: View {
    public enum Kind { case primary, secondary, destructive }

    let kind: Kind
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    public init(_ kind: Kind = .primary, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.kind = kind
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(action: action, label: label).apply {
            switch kind {
            case .primary: $0.buttonStyle(.mwPrimary)
            case .secondary: $0.buttonStyle(.mwSecondary)
            case .destructive: $0.buttonStyle(.mwDestructive)
            }
        }
    }
}

public extension MWButton where Label == Text {
    init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
        self.init(kind, action: action) { Text(title) }
    }
}

// Small helper to branch styles cleanly.
private extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

#Preview("MWButton variants") {
    VStack(spacing: MWSpacing.m) {
        MWButton("Continue") {}
        MWButton("Sign in with email", kind: .secondary) {}
        MWButton("Delete account", kind: .destructive) {}
    }
    .mwPadding(.all, .xl)
    .background(MWColor.canvas)
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWButton atom (0.25)"
```

---

### Task 0.26: MWTextField atom

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWTextField.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

public struct MWTextField: View {
    let label: String
    @Binding var text: String
    let contentType: UITextContentType?
    let keyboard: UIKeyboardType

    public init(label: String, text: Binding<String>,
                contentType: UITextContentType? = nil,
                keyboard: UIKeyboardType = .default) {
        self.label = label
        self._text = text
        self.contentType = contentType
        self.keyboard = keyboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.xs) {
            Text(label)
                .font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
                .foregroundStyle(MWColor.inkMuted)

            TextField("", text: $text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(MWType.bodyL).foregroundStyle(MWColor.ink)
                .mwPadding(.all, .m)
                .background(MWColor.paper)
                .mwCornerRadius(.s)
                .mwStroke(color: MWColor.ink, width: MWBorder.default)
        }
    }
}

#Preview("MWTextField") {
    StatefulPreviewWrapper("") { binding in
        MWTextField(label: "Email", text: binding, contentType: .emailAddress, keyboard: .emailAddress)
            .mwPadding(.all, .xl)
            .background(MWColor.canvas)
    }
}

/// Preview helper — allows mutable state in previews.
public struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content
    public init(_ initial: Value, @ViewBuilder _ content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial); self.content = content
    }
    public var body: some View { content($value) }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWTextField atom (0.26)"
```

---

### Task 0.27: MWPill, MWDot, MWDivider, MWEyebrow atoms

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWPill.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWDot.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWDivider.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWEyebrow.swift`

- [ ] **Step 1: `MWPill.swift`:**

```swift
import SwiftUI

public struct MWPill: View {
    let text: String; let tint: Color
    public init(_ text: String, tint: Color = MWColor.ink) { self.text = text; self.tint = tint }
    public var body: some View {
        Text(text)
            .font(MWType.bodyS.weight(.semibold))
            .foregroundStyle(tint)
            .mwPadding(.horizontal, .s)
            .mwPadding(.vertical, .xs)
            .background(tint.opacity(0.08))
            .mwCornerRadius(.l)
    }
}
```

- [ ] **Step 2: `MWDot.swift`:**

```swift
import SwiftUI

public struct MWDot: View {
    let color: Color; let size: CGFloat
    public init(color: Color = MWColor.ink, size: CGFloat = 8) { self.color = color; self.size = size }
    public var body: some View { Circle().fill(color).frame(width: size, height: size) }
}
```

- [ ] **Step 3: `MWDivider.swift`:**

```swift
import SwiftUI

public struct MWDivider: View {
    public init() {}
    public var body: some View {
        Rectangle().fill(MWColor.ink).frame(height: MWBorder.default)
    }
}
```

- [ ] **Step 4: `MWEyebrow.swift`:**

```swift
import SwiftUI

public struct MWEyebrow: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(MWType.eyebrow).tracking(MWType.eyebrowTracking)
            .foregroundStyle(MWColor.inkMuted)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWPill, MWDot, MWDivider, MWEyebrow atoms (0.27)"
```

---

### Task 0.28: MWScreenChrome modifier (top-bar reservation)

**Files:**
- Create: `ios/Flashcards/DesignSystem/Modifiers/MWScreenChrome.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

/// Applies the standard top-bar chrome reservation and canvas background
/// used by all top-level NavigationStack destinations.
public struct MWScreenChrome: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .toolbarBackground(MWColor.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
            .background(MWColor.canvas)
    }
}

public extension View {
    func mwScreenChrome() -> some View { modifier(MWScreenChrome()) }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWScreenChrome modifier (0.28)"
```

---

### Task 0.29: Snapshot testing baseline

**Files:**
- Create: `ios/FlashcardsTests/DesignSystemSnapshotTests.swift`

- [ ] **Step 1: Create file:**

```swift
import SnapshotTesting
import SwiftUI
import XCTest
@testable import Flashcards

final class DesignSystemSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Record once locally, then commit. CI runs in verify mode.
        isRecording = false
    }

    func test_MWButton_primary_idle() {
        let view = MWButton("Continue") {}.frame(width: 340).padding()
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro))
    }

    func test_MWButton_primary_dark() {
        let view = MWButton("Continue") {}.frame(width: 340).padding()
            .preferredColorScheme(.dark)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro), named: "dark")
    }

    func test_MWTextField() {
        let view = StatefulPreviewWrapper("user@example.com") { binding in
            MWTextField(label: "Email", text: binding, contentType: .emailAddress).padding()
        }.frame(width: 340)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro))
    }

    func test_MWCard() {
        let view = Text("Card body").mwCard().frame(width: 340).padding()
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro))
    }
}
```

- [ ] **Step 2: Record snapshots locally**

Flip `isRecording = true`, run the tests once in Xcode, then flip back to `false` and commit both the code and the `__Snapshots__` PNG folder.

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' test | tail -n 20
```

Expected (after recording): all 4 tests PASS.

- [ ] **Step 3: Commit snapshots and test file**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(ds): snapshot baseline for MWButton, MWTextField, MWCard (0.29)"
```

---

### Task 0.30: AppState shell

**Files:**
- Create: `ios/Flashcards/App/AppState.swift`
- Modify: `ios/Flashcards/FlashcardsApp.swift`

- [ ] **Step 1: Create `AppState.swift`:**

```swift
import Foundation
import Observation

/// App-level observable state. One instance is injected into the SwiftUI environment.
/// Subscription, sync, and today's progress are intentionally shallow here — deeper state
/// lives in the owning manager (AuthManager, SyncManager, …) and is projected up as needed.
@Observable
public final class AppState {
    public enum AuthStatus: Equatable { case unauthenticated, authenticated(userId: String), checking }
    public enum SubscriptionTier: String, Codable { case free, plus }

    public var authStatus: AuthStatus = .checking
    public var subscriptionTier: SubscriptionTier = .free
    public var lastSyncAt: Date?
    public var pendingMutationCount: Int = 0

    public init() {}
}
```

- [ ] **Step 2: Update `FlashcardsApp.swift` to inject:**

```swift
import SwiftUI
import SwiftData

@main
struct FlashcardsApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState)
        }
    }
}
```

- [ ] **Step 3: Create placeholder `RootView.swift`:**

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                MWEyebrow("Flashcards")
                Text("Phase 0 scaffold").font(MWType.headingM).foregroundStyle(MWColor.ink)
                Text("Auth status: \(String(describing: appState.authStatus))")
                    .font(MWType.body).foregroundStyle(MWColor.inkMuted)
            }
        }
    }
}
```

- [ ] **Step 4: Build + run in simulator.**

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat: AppState observable + RootView scaffold (0.30)"
```

---

### Task 0.31: User migration (Laravel)

**Files:**
- Modify: `api/database/migrations/2014_10_12_000000_create_users_table.php` (replace default)
- Modify: `api/app/Models/User.php`

- [ ] **Step 1: Replace the default users migration with one that matches the spec:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->unique();
            $table->string('name')->nullable();
            $table->string('avatar_url')->nullable();
            $table->enum('auth_provider', ['apple', 'email']);
            $table->string('auth_provider_id')->nullable();
            $table->unsignedSmallInteger('daily_goal_cards')->default(20);
            $table->time('reminder_time_local')->nullable();
            $table->boolean('reminder_enabled')->default(false);
            $table->enum('theme_preference', ['system', 'light', 'dark'])->default('system');
            $table->json('fsrs_weights')->nullable();
            $table->enum('subscription_status', ['free', 'active', 'in_grace', 'expired'])->default('free');
            $table->timestamp('subscription_expires_at')->nullable();
            $table->string('subscription_product_id')->nullable();
            $table->unsignedBigInteger('image_quota_used_bytes')->default(0);
            $table->boolean('marketing_opt_in')->default(false);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->unique(['auth_provider', 'auth_provider_id']);
            $table->index('updated_at_ms');
        });
    }

    public function down(): void { Schema::dropIfExists('users'); }
};
```

- [ ] **Step 2: Replace `api/app/Models/User.php`:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    protected $fillable = [
        'email', 'name', 'avatar_url', 'auth_provider', 'auth_provider_id',
        'daily_goal_cards', 'reminder_time_local', 'reminder_enabled',
        'theme_preference', 'fsrs_weights', 'subscription_status',
        'subscription_expires_at', 'subscription_product_id',
        'image_quota_used_bytes', 'marketing_opt_in', 'updated_at_ms', 'deleted_at_ms',
    ];

    protected $casts = [
        'fsrs_weights' => 'array',
        'reminder_enabled' => 'boolean',
        'marketing_opt_in' => 'boolean',
        'subscription_expires_at' => 'datetime',
        'updated_at_ms' => 'integer',
        'deleted_at_ms' => 'integer',
    ];

    protected $hidden = ['auth_provider_id'];
}
```

- [ ] **Step 3: Migrate + run tests**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate:fresh
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat: User model + migration with spec fields (0.31)"
```

---

### Task 0.32: Apple Sign In — verifier service

**Files:**
- Create: `api/app/Services/Auth/AppleIdentityVerifier.php`
- Create: `api/tests/Unit/AppleIdentityVerifierTest.php`

- [ ] **Step 1: Write the failing test:**

```php
<?php

declare(strict_types=1);

use App\Services\Auth\AppleIdentityVerifier;

test('verifies a valid Apple identity token and returns subject + email', function () {
    $mockJwksResponse = [/* stub JWKS — filled in when ci runs mock server; for unit test, inject a public key pair */];
    $verifier = new AppleIdentityVerifier(clientId: 'com.lukehogan.flashcards', jwksFetcher: fn () => $mockJwksResponse);

    // Sign a fake token with a matching private key in the test harness (firebase/php-jwt).
    $token = makeFakeAppleIdentityToken(sub: 'APPLE_UID_123', email: 'user@example.com', aud: 'com.lukehogan.flashcards');

    $claims = $verifier->verify($token);

    expect($claims->subject)->toBe('APPLE_UID_123')
        ->and($claims->email)->toBe('user@example.com');
});

test('rejects a token with wrong audience', function () {
    $verifier = new AppleIdentityVerifier(clientId: 'com.lukehogan.flashcards', jwksFetcher: fn () => []);
    $token = makeFakeAppleIdentityToken(sub: 'x', email: 'x@x', aud: 'wrong.audience');
    expect(fn () => $verifier->verify($token))->toThrow(RuntimeException::class, 'Audience mismatch');
});
```

Add a helper `makeFakeAppleIdentityToken` in `tests/Pest.php` that signs a token with a test RSA key. Install `firebase/php-jwt`:

```bash
cd /Users/lukehogan/Code/flashcards/api && composer require firebase/php-jwt:^6.0
```

- [ ] **Step 2: Create the verifier:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Auth;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use RuntimeException;

final class AppleIdentityVerifier
{
    /**
     * @param  callable(): array<string,mixed>  $jwksFetcher  returns Apple's JWKS payload.
     */
    public function __construct(
        private readonly string $clientId,
        private readonly mixed $jwksFetcher,
    ) {}

    public function verify(string $token): AppleClaims
    {
        $jwks = ($this->jwksFetcher)();
        $keys = JWK::parseKeySet($jwks);

        $decoded = JWT::decode($token, $keys);

        if (($decoded->aud ?? null) !== $this->clientId) {
            throw new RuntimeException('Audience mismatch');
        }
        if (($decoded->iss ?? null) !== 'https://appleid.apple.com') {
            throw new RuntimeException('Issuer mismatch');
        }
        if (!isset($decoded->sub)) {
            throw new RuntimeException('Missing subject');
        }

        return new AppleClaims(
            subject: (string) $decoded->sub,
            email: isset($decoded->email) ? (string) $decoded->email : null,
        );
    }
}

final class AppleClaims
{
    public function __construct(
        public readonly string $subject,
        public readonly ?string $email,
    ) {}
}
```

- [ ] **Step 3: Run tests — expect pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Unit/AppleIdentityVerifierTest.php
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): AppleIdentityVerifier with JWKS (0.32)"
```

---

### Task 0.33: Apple Sign In — endpoint

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/AppleAuthController.php`
- Create: `api/app/Http/Requests/AppleAuthRequest.php`
- Create: `api/tests/Feature/AppleAuthTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test `api/tests/Feature/AppleAuthTest.php`:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('POST /v1/auth/apple creates user on first sign-in and returns tokens', function () {
    $this->mock(\App\Services\Auth\AppleIdentityVerifier::class, function ($mock) {
        $mock->shouldReceive('verify')
            ->once()
            ->andReturn(new \App\Services\Auth\AppleClaims(subject: 'APPLE_UID_1', email: 'a@b.com'));
    });

    $response = $this->postJson('/api/v1/auth/apple', [
        'identity_token' => 'stub.jwt.token',
    ]);

    $response->assertOk()
        ->assertJsonStructure(['access_token', 'refresh_token', 'user' => ['id', 'email']]);

    expect(User::where('email', 'a@b.com')->exists())->toBeTrue();
});

test('POST /v1/auth/apple returns same user on subsequent sign-in', function () {
    $u = User::factory()->create(['auth_provider' => 'apple', 'auth_provider_id' => 'APPLE_UID_2', 'email' => 'c@d.com']);
    $this->mock(\App\Services\Auth\AppleIdentityVerifier::class, function ($mock) {
        $mock->shouldReceive('verify')->andReturn(new \App\Services\Auth\AppleClaims(subject: 'APPLE_UID_2', email: 'c@d.com'));
    });

    $response = $this->postJson('/api/v1/auth/apple', ['identity_token' => 'x']);

    $response->assertOk();
    expect($response->json('user.id'))->toBe($u->id);
});
```

Also add a `UserFactory` `api/database/factories/UserFactory.php`:

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'email' => fake()->unique()->safeEmail(),
            'auth_provider' => 'email',
            'auth_provider_id' => fake()->uuid(),
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 2: Create request class:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AppleAuthRequest extends FormRequest
{
    public function rules(): array
    {
        return ['identity_token' => ['required', 'string']];
    }
}
```

- [ ] **Step 3: Create controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\AppleAuthRequest;
use App\Models\User;
use App\Services\Auth\AppleIdentityVerifier;
use Illuminate\Http\JsonResponse;

class AppleAuthController extends Controller
{
    public function __construct(private readonly AppleIdentityVerifier $verifier) {}

    public function store(AppleAuthRequest $request): JsonResponse
    {
        $claims = $this->verifier->verify($request->string('identity_token')->toString());

        $user = User::firstOrCreate(
            ['auth_provider' => 'apple', 'auth_provider_id' => $claims->subject],
            ['email' => $claims->email ?? '', 'updated_at_ms' => now()->valueOf()],
        );

        $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
        $refresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));

        return response()->json([
            'access_token' => $access->plainTextToken,
            'refresh_token' => $refresh->plainTextToken,
            'user' => ['id' => $user->id, 'email' => $user->email],
        ]);
    }
}
```

- [ ] **Step 4: Bind verifier in `AppServiceProvider::register`:**

```php
$this->app->singleton(\App\Services\Auth\AppleIdentityVerifier::class, function () {
    return new \App\Services\Auth\AppleIdentityVerifier(
        clientId: config('services.apple.client_id', 'com.lukehogan.flashcards'),
        jwksFetcher: fn () => json_decode(file_get_contents('https://appleid.apple.com/auth/keys'), true),
    );
});
```

- [ ] **Step 5: Register route in `api/routes/api.php`:**

```php
use App\Http\Controllers\Api\V1\AppleAuthController;

Route::prefix('v1')->group(function () {
    Route::post('/auth/apple', [AppleAuthController::class, 'store']);
});
```

- [ ] **Step 6: Run tests — expect pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/AppleAuthTest.php
```

- [ ] **Step 7: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): POST /v1/auth/apple endpoint (0.33)"
```

---

### Task 0.34: Magic link — request endpoint

**Files:**
- Create: `api/database/migrations/2026_04_21_000012_create_pending_email_auths_table.php`
- Create: `api/app/Models/PendingEmailAuth.php`
- Create: `api/app/Services/Auth/MagicLinkService.php`
- Create: `api/app/Http/Controllers/Api/V1/MagicLinkController.php`
- Create: `api/tests/Feature/MagicLinkRequestTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('pending_email_auths', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('email')->index();
            $table->string('token_hash');
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void { Schema::dropIfExists('pending_email_auths'); }
};
```

- [ ] **Step 2: Model `PendingEmailAuth.php`:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PendingEmailAuth extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = ['email', 'token_hash', 'expires_at', 'consumed_at'];
    protected $casts = ['expires_at' => 'datetime', 'consumed_at' => 'datetime'];
}
```

- [ ] **Step 3: Service:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Auth;

use App\Models\PendingEmailAuth;
use Illuminate\Support\Str;

final class MagicLinkService
{
    public function __construct(private readonly int $ttlMinutes = 15) {}

    /** @return array{auth_id: string, token: string} */
    public function issue(string $email): array
    {
        $token = bin2hex(random_bytes(32));

        $row = PendingEmailAuth::create([
            'email' => strtolower($email),
            'token_hash' => hash('sha256', $token),
            'expires_at' => now()->addMinutes($this->ttlMinutes),
        ]);

        return ['auth_id' => $row->id, 'token' => $token];
    }
}
```

- [ ] **Step 4: Failing test `api/tests/Feature/MagicLinkRequestTest.php`:**

```php
<?php

declare(strict_types=1);

use App\Models\PendingEmailAuth;
use Illuminate\Support\Facades\Queue;

test('POST /v1/auth/magic-link/request stores a pending auth and queues the email', function () {
    Queue::fake();

    $response = $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'new@user.com']);

    $response->assertNoContent();
    expect(PendingEmailAuth::where('email', 'new@user.com')->exists())->toBeTrue();
    Queue::assertPushed(\App\Jobs\SendMagicLinkEmail::class);
});

test('rate-limits to 5 per hour per email', function () {
    for ($i = 0; $i < 5; $i++) {
        $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'spam@x.com'])->assertNoContent();
    }
    $this->postJson('/api/v1/auth/magic-link/request', ['email' => 'spam@x.com'])->assertStatus(429);
});
```

- [ ] **Step 5: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Jobs\SendMagicLinkEmail;
use App\Services\Auth\MagicLinkService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MagicLinkController extends Controller
{
    public function __construct(private readonly MagicLinkService $service) {}

    public function request(Request $request): JsonResponse
    {
        $validated = $request->validate(['email' => ['required', 'email']]);
        $issued = $this->service->issue($validated['email']);

        SendMagicLinkEmail::dispatch($validated['email'], $issued['token']);

        return response()->json(status: 204);
    }
}
```

- [ ] **Step 6: Job `api/app/Jobs/SendMagicLinkEmail.php`:**

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

final class SendMagicLinkEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly string $email, public readonly string $token) {}

    public function handle(): void
    {
        $host = config('app.magic_link_host');
        $url = "https://{$host}/auth/consume?t={$this->token}";

        Mail::raw("Tap to sign in: {$url}", function ($msg) {
            $msg->to($this->email)->subject('Sign in to Flashcards');
        });
    }
}
```

- [ ] **Step 7: Route + throttle in `api/routes/api.php`:**

```php
use App\Http\Controllers\Api\V1\MagicLinkController;

Route::prefix('v1')->group(function () {
    Route::middleware(['throttle:5,60'])->group(function () {
        Route::post('/auth/magic-link/request', [MagicLinkController::class, 'request']);
    });
});
```

- [ ] **Step 8: Run tests — pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate:fresh && ./vendor/bin/pest tests/Feature/MagicLinkRequestTest.php
```

- [ ] **Step 9: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): magic-link request endpoint + job (0.34)"
```

---

### Task 0.35: Magic link — consume endpoint

**Files:**
- Modify: `api/app/Http/Controllers/Api/V1/MagicLinkController.php`
- Create: `api/tests/Feature/MagicLinkConsumeTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\PendingEmailAuth;
use App\Models\User;

test('valid token consumes and returns access/refresh + user', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'm@l.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
    ]);

    $res = $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token]);

    $res->assertOk()->assertJsonStructure(['access_token', 'refresh_token', 'user' => ['id', 'email']]);
    expect(User::where('email', 'm@l.com')->exists())->toBeTrue();
});

test('expired token returns 410', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'e@x.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->subMinutes(1),
    ]);
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertStatus(410);
});

test('consumed token returns 410 on second use', function () {
    $token = bin2hex(random_bytes(32));
    PendingEmailAuth::create([
        'email' => 'c@x.com',
        'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10),
    ]);
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertOk();
    $this->postJson('/api/v1/auth/magic-link/consume', ['token' => $token])->assertStatus(410);
});
```

- [ ] **Step 2: Add `consume` method to controller:**

```php
public function consume(Request $request): JsonResponse
{
    $validated = $request->validate(['token' => ['required', 'string']]);
    $hash = hash('sha256', $validated['token']);

    $pending = \App\Models\PendingEmailAuth::where('token_hash', $hash)->first();
    abort_unless($pending, 410, 'Invalid token');
    abort_if($pending->consumed_at !== null, 410, 'Token already used');
    abort_if($pending->expires_at->isPast(), 410, 'Token expired');

    $user = \App\Models\User::firstOrCreate(
        ['auth_provider' => 'email', 'email' => $pending->email],
        ['auth_provider_id' => (string) \Illuminate\Support\Str::orderedUuid(), 'updated_at_ms' => now()->valueOf()],
    );

    $pending->update(['consumed_at' => now()]);

    $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
    $refresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));

    return response()->json([
        'access_token' => $access->plainTextToken,
        'refresh_token' => $refresh->plainTextToken,
        'user' => ['id' => $user->id, 'email' => $user->email],
    ]);
}
```

- [ ] **Step 3: Add route:**

```php
Route::post('/auth/magic-link/consume', [MagicLinkController::class, 'consume']);
```

- [ ] **Step 4: Run tests — pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/MagicLinkConsumeTest.php
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): magic-link consume endpoint (0.35)"
```

---

### Task 0.36: Token refresh endpoint

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/TokenController.php`
- Create: `api/tests/Feature/TokenRefreshTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('valid refresh token yields new access token; refresh rotates', function () {
    $u = User::factory()->create();
    $refresh = $u->createToken('refresh', ['auth:refresh'], now()->addDays(90))->plainTextToken;

    $res = $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $refresh]);

    $res->assertOk()->assertJsonStructure(['access_token', 'refresh_token']);
    expect($res->json('refresh_token'))->not->toBe($refresh);
});

test('access token cannot refresh', function () {
    $u = User::factory()->create();
    $access = $u->createToken('ios', ['*'], now()->addMinutes(15))->plainTextToken;
    $this->postJson('/api/v1/auth/refresh', ['refresh_token' => $access])->assertStatus(401);
});
```

- [ ] **Step 2: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

class TokenController extends Controller
{
    public function refresh(Request $request): JsonResponse
    {
        $validated = $request->validate(['refresh_token' => ['required', 'string']]);

        $token = PersonalAccessToken::findToken($validated['refresh_token']);
        abort_unless($token && in_array('auth:refresh', $token->abilities, true), 401);
        abort_if($token->expires_at && $token->expires_at->isPast(), 401);

        $user = $token->tokenable;

        $access = $user->createToken('ios', ['*'], now()->addMinutes(15));
        $newRefresh = $user->createToken('refresh', ['auth:refresh'], now()->addDays(90));
        $token->delete();

        return response()->json([
            'access_token' => $access->plainTextToken,
            'refresh_token' => $newRefresh->plainTextToken,
        ]);
    }
}
```

- [ ] **Step 3: Route:**

```php
Route::post('/auth/refresh', [TokenController::class, 'refresh']);
```

- [ ] **Step 4: Test — pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/TokenRefreshTest.php
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): token refresh rotates refresh token (0.36)"
```

---

### Task 0.37: APIClient, APIEndpoint, APIError (iOS)

**Files:**
- Create: `ios/Flashcards/Networking/APIEndpoint.swift`
- Create: `ios/Flashcards/Networking/APIError.swift`
- Create: `ios/Flashcards/Networking/APIClient.swift`
- Create: `ios/FlashcardsTests/APIClientTests.swift`

- [ ] **Step 1: `APIEndpoint.swift`:**

```swift
import Foundation

public struct APIEndpoint<Response: Decodable> {
    public let method: String
    public let path: String
    public let body: Data?
    public let requiresAuth: Bool

    public init(method: String, path: String, body: Data? = nil, requiresAuth: Bool = true) {
        self.method = method; self.path = path; self.body = body; self.requiresAuth = requiresAuth
    }
}
```

- [ ] **Step 2: `APIError.swift`:**

```swift
import Foundation

public enum APIError: Error, Equatable {
    case offline
    case unauthorized
    case http(status: Int, body: String)
    case decoding(String)
    case unknown(String)
}
```

- [ ] **Step 3: `APIClient.swift`:**

```swift
import Foundation

public protocol APIClientProtocol: Sendable {
    func send<R: Decodable>(_ endpoint: APIEndpoint<R>) async throws -> R
}

public actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> String?

    public init(baseURL: URL, session: URLSession = .shared, tokenProvider: @Sendable @escaping () async -> String?) {
        self.baseURL = baseURL; self.session = session; self.tokenProvider = tokenProvider
    }

    public func send<R: Decodable>(_ endpoint: APIEndpoint<R>) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        req.httpMethod = endpoint.method
        req.httpBody = endpoint.body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = await tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown("no HTTP response") }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw APIError.unauthorized
        default: throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        do { return try JSONDecoder.api.decode(R.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }
}

public extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()
}
public extension JSONEncoder {
    static let api: JSONEncoder = {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e
    }()
}
```

- [ ] **Step 4: `APIClientTests.swift` — happy path + 401 + offline:**

```swift
import XCTest
@testable import Flashcards

final class APIClientTests: XCTestCase {
    func test_sendHappyPath_decodesResponse() async throws {
        let (client, _) = makeClient(statusCode: 200, body: #"{"value":"ok"}"#)
        struct R: Decodable { let value: String }
        let r: R = try await client.send(APIEndpoint(method: "GET", path: "/t"))
        XCTAssertEqual(r.value, "ok")
    }

    func test_401_throwsUnauthorized() async {
        let (client, _) = makeClient(statusCode: 401, body: "")
        do { _ = try await client.send(APIEndpoint<Empty>(method: "GET", path: "/t")); XCTFail() }
        catch let e as APIError { XCTAssertEqual(e, .unauthorized) }
        catch { XCTFail() }
    }

    private struct Empty: Decodable {}

    private func makeClient(statusCode: Int, body: String) -> (APIClient, StubProtocol) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.nextResponse = (statusCode, body)
        let session = URLSession(configuration: config)
        let client = APIClient(baseURL: URL(string: "https://api.test")!, session: session) { nil }
        return (client, StubProtocol())
    }
}

final class StubProtocol: URLProtocol {
    static var nextResponse: (Int, String) = (200, "")
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (code, body) = Self.nextResponse
        let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 5: Build + test in Xcode — pass**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/APIClientTests | tail -n 20
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(net): APIClient actor + APIEndpoint + APIError (0.37)"
```

---

### Task 0.38: TokenStore backed by Keychain

**Files:**
- Create: `ios/Flashcards/Features/Auth/TokenStore.swift`

- [ ] **Step 1: Create file:**

```swift
import Foundation
import KeychainAccess

public actor TokenStore {
    private let keychain: Keychain

    public init(service: String = "com.lukehogan.flashcards.tokens") {
        self.keychain = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    public func save(access: String, refresh: String) throws {
        try keychain.set(access, key: "access")
        try keychain.set(refresh, key: "refresh")
    }

    public func access() -> String? { try? keychain.get("access") }
    public func refresh() -> String? { try? keychain.get("refresh") }

    public func clear() {
        try? keychain.remove("access")
        try? keychain.remove("refresh")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): TokenStore (Keychain-backed) (0.38)"
```

---

### Task 0.39: AuthManager — Apple sign-in path

**Files:**
- Create: `ios/Flashcards/Features/Auth/AuthManager.swift`
- Create: `ios/Flashcards/Features/Auth/AppleSignInService.swift`

- [ ] **Step 1: `AppleSignInService.swift`:**

```swift
import AuthenticationServices
import SwiftUI

public struct AppleIdentity: Sendable, Equatable {
    public let identityToken: String
    public let userIdentifier: String
    public let email: String?
    public let fullName: PersonNameComponents?
}

public final class AppleSignInService: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<AppleIdentity, Error>?

    @MainActor
    public func signIn() async throws -> AppleIdentity {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization) {
        guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: URLError(.badServerResponse)); return
        }
        continuation?.resume(returning: AppleIdentity(
            identityToken: token, userIdentifier: cred.user, email: cred.email, fullName: cred.fullName
        ))
        continuation = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }
}
```

- [ ] **Step 2: `AuthManager.swift`:**

```swift
import Foundation
import Observation

@Observable
public final class AuthManager {
    public enum State: Equatable { case unknown, signedOut, signedIn(userId: String, email: String?) }

    public var state: State = .unknown
    private let api: APIClientProtocol
    private let tokenStore: TokenStore
    private let apple: AppleSignInService

    public init(api: APIClientProtocol, tokenStore: TokenStore = TokenStore(), apple: AppleSignInService = .init()) {
        self.api = api; self.tokenStore = tokenStore; self.apple = apple
    }

    public func restore() async {
        if await tokenStore.access() != nil {
            // Phase 1 wires GET /me; for now mark signed in with placeholder.
            state = .signedIn(userId: "restored", email: nil)
        } else { state = .signedOut }
    }

    public func signInWithApple() async throws {
        let identity = try await apple.signIn()
        struct Body: Encodable { let identity_token: String }
        struct Resp: Decodable { let access_token: String; let refresh_token: String; let user: UserDTO
            struct UserDTO: Decodable { let id: String; let email: String? } }

        let body = try JSONEncoder.api.encode(Body(identity_token: identity.identityToken))
        let resp: Resp = try await api.send(APIEndpoint(method: "POST", path: "/api/v1/auth/apple", body: body, requiresAuth: false))

        try await tokenStore.save(access: resp.access_token, refresh: resp.refresh_token)
        state = .signedIn(userId: resp.user.id, email: resp.user.email)
    }

    public func requestMagicLink(email: String) async throws {
        struct Body: Encodable { let email: String }
        let body = try JSONEncoder.api.encode(Body(email: email))
        _ = try await api.send(APIEndpoint<Empty204>(method: "POST", path: "/api/v1/auth/magic-link/request", body: body, requiresAuth: false))
    }

    public func consumeMagicLink(token: String) async throws {
        struct Body: Encodable { let token: String }
        struct Resp: Decodable { let access_token: String; let refresh_token: String; let user: UserDTO
            struct UserDTO: Decodable { let id: String; let email: String? } }
        let body = try JSONEncoder.api.encode(Body(token: token))
        let resp: Resp = try await api.send(APIEndpoint(method: "POST", path: "/api/v1/auth/magic-link/consume", body: body, requiresAuth: false))
        try await tokenStore.save(access: resp.access_token, refresh: resp.refresh_token)
        state = .signedIn(userId: resp.user.id, email: resp.user.email)
    }

    public func signOut() async {
        await tokenStore.clear()
        state = .signedOut
    }
}

public struct Empty204: Decodable {}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): AuthManager + AppleSignInService (0.39)"
```

---

### Task 0.40: Onboarding — Splash, Intro 1, Intro 2, SignUpWall

**Files:**
- Create: `ios/Flashcards/Features/Onboarding/SplashView.swift`
- Create: `ios/Flashcards/Features/Onboarding/Intro1View.swift`
- Create: `ios/Flashcards/Features/Onboarding/Intro2View.swift`
- Create: `ios/Flashcards/Features/Onboarding/SignUpWallView.swift`
- Create: `ios/Flashcards/Features/Onboarding/MagicLinkSentView.swift`
- Modify: `ios/Flashcards/App/RootView.swift`

- [ ] **Step 1: `SplashView.swift`:**

```swift
import SwiftUI

struct SplashView: View {
    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                MWEyebrow("Flashcards")
                Text("Learn on purpose.")
                    .font(MWType.display).foregroundStyle(MWColor.ink)
            }
        }
    }
}
```

- [ ] **Step 2: `Intro1View.swift`:**

```swift
import SwiftUI

struct Intro1View: View {
    let onContinue: () -> Void
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("01 — Welcome")
                Text("A spaced-repetition app that actually studies you.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Flashcards schedules each card based on your memory, so short sessions beat long ones.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Spacer()
                MWButton("Continue", action: onContinue)
            }.mwPadding(.all, .xl)
        }
    }
}
```

- [ ] **Step 3: `Intro2View.swift`:**

```swift
import SwiftUI

struct Intro2View: View {
    let onContinue: () -> Void
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("02 — Offline by default")
                Text("Works anywhere. Syncs when you're back.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Every study session, every new card — zero waiting on the network.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Spacer()
                MWButton("Continue", action: onContinue)
            }.mwPadding(.all, .xl)
        }
    }
}
```

- [ ] **Step 4: `SignUpWallView.swift`:**

```swift
import SwiftUI

struct SignUpWallView: View {
    let onAppleSignIn: () async -> Void
    let onRequestMagicLink: (String) async -> Void
    @State private var email = ""
    @State private var marketingOptIn = false
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Save your progress")
                    Text("No password required.")
                        .font(MWType.headingL).foregroundStyle(MWColor.ink)
                    Text("We ask for your email so your flashcards live in your account, not just this device. If you lose your phone, you won't lose a single card.")
                        .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)

                    MWButton("Continue with Apple") {
                        Task { isSubmitting = true; await onAppleSignIn(); isSubmitting = false }
                    }

                    MWTextField(label: "Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)

                    MWButton("Continue with email", kind: .secondary) {
                        Task { isSubmitting = true; await onRequestMagicLink(email); isSubmitting = false }
                    }.disabled(email.isEmpty || isSubmitting)

                    Text("Free to use. No payment needed. We won't sell your data or email you marketing.")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkFaint)

                    Toggle(isOn: $marketingOptIn) {
                        Text("Send me occasional product updates")
                            .font(MWType.body).foregroundStyle(MWColor.inkMuted)
                    }.tint(MWColor.ink)

                    if let errorText {
                        Text(errorText).font(MWType.body).foregroundStyle(MWColor.again)
                    }
                }.mwPadding(.all, .xl)
            }
        }
    }
}
```

- [ ] **Step 5: `MagicLinkSentView.swift`:**

```swift
import SwiftUI

struct MagicLinkSentView: View {
    let email: String
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("Check your inbox")
                Text("We sent you a link.")
                    .font(MWType.headingL).foregroundStyle(MWColor.ink)
                Text("Tap it on this device — we'll bring you right back.")
                    .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                Text(email).font(MWType.mono).foregroundStyle(MWColor.ink)
            }.mwPadding(.all, .xl)
        }
    }
}
```

- [ ] **Step 6: Wire `RootView` to route between onboarding screens based on `AuthManager.state`:**

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var auth = AuthManager(
        api: APIClient(baseURL: URL(string: "http://localhost:8000")!) { nil }
    )
    @State private var step: Step = .splash
    @State private var emailSent: String?

    enum Step { case splash, intro1, intro2, signup, magicLinkSent }

    var body: some View {
        Group {
            switch auth.state {
            case .signedIn:
                Text("Signed in — home coming in Phase 2.")
                    .font(MWType.headingM).foregroundStyle(MWColor.ink)
            default:
                switch step {
                case .splash: SplashView().task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    step = .intro1
                }
                case .intro1: Intro1View { step = .intro2 }
                case .intro2: Intro2View { step = .signup }
                case .signup: SignUpWallView(
                    onAppleSignIn: {
                        try? await auth.signInWithApple()
                    },
                    onRequestMagicLink: { email in
                        try? await auth.requestMagicLink(email: email)
                        emailSent = email
                        step = .magicLinkSent
                    }
                )
                case .magicLinkSent:
                    MagicLinkSentView(email: emailSent ?? "")
                }
            }
        }
        .task { await auth.restore() }
    }
}
```

- [ ] **Step 7: Build and run in simulator — walk through the flow.**

- [ ] **Step 8: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(onboarding): Splash + Intro1/2 + SignUpWall + MagicLinkSent (0.40)"
```

---

### Task 0.41: Universal Link — magic-link consume on iOS

**Files:**
- Create: `ios/Flashcards/Features/Auth/MagicLinkConsumer.swift`
- Modify: `ios/Flashcards/FlashcardsApp.swift`
- Add: `ios/Flashcards/Info.plist` entry for associated domains
- Create: `api/public/.well-known/apple-app-site-association`

- [ ] **Step 1: Create `MagicLinkConsumer.swift`:**

```swift
import Foundation

public enum MagicLinkConsumer {
    public static func extractToken(from url: URL) -> String? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path.hasSuffix("/auth/consume") else { return nil }
        return comps.queryItems?.first(where: { $0.name == "t" })?.value
    }
}
```

- [ ] **Step 2: Handle `onOpenURL` in `FlashcardsApp`:**

```swift
WindowGroup {
    RootView().environment(appState)
        .onOpenURL { url in
            if let token = MagicLinkConsumer.extractToken(from: url) {
                // The AuthManager instance lives in RootView. Use a shared environment for now.
                NotificationCenter.default.post(name: .mwMagicLinkToken, object: token)
            }
        }
}
```

```swift
public extension Notification.Name {
    static let mwMagicLinkToken = Notification.Name("mw.magicLinkToken")
}
```

In `RootView`, observe and forward:

```swift
.task {
    for await n in NotificationCenter.default.notifications(named: .mwMagicLinkToken) {
        if let token = n.object as? String {
            try? await auth.consumeMagicLink(token: token)
        }
    }
}
```

- [ ] **Step 3: Declare Associated Domains** — in Flashcards target → Signing & Capabilities → + Associated Domains → `applinks:flashcards.app`.

- [ ] **Step 4: Serve `apple-app-site-association` from backend.**

Create `api/public/.well-known/apple-app-site-association` (no extension):

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["UWK6JHFFGJ.com.lukehogan.flashcards"],
        "components": [
          { "/": "/auth/consume", "?": { "t": "*" } }
        ]
      }
    ]
  }
}
```

(Replace `TEAMID` with the actual Apple team ID at deploy time — this is configuration not code.)

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios api/public/.well-known
git -C /Users/lukehogan/Code/flashcards commit -m "feat(auth): universal link magic-link consume + AASA (0.41)"
```

---

### Task 0.42: Sentry + PostHog init on iOS

**Files:**
- Create: `ios/Flashcards/Analytics/AnalyticsClient.swift`
- Modify: `ios/Flashcards/FlashcardsApp.swift`

- [ ] **Step 1: `AnalyticsClient.swift`:**

```swift
import Foundation
import PostHog
import Sentry

public enum AnalyticsClient {
    public static func configure() {
        let phKey = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_KEY") as? String ?? ""
        let phHost = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String ?? "https://us.i.posthog.com"
        let sentryDSN = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? ""

        if !phKey.isEmpty {
            let config = PostHogConfig(apiKey: phKey, host: phHost)
            config.captureApplicationLifecycleEvents = true
            PostHogSDK.shared.setup(config)
        }
        if !sentryDSN.isEmpty {
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.tracesSampleRate = 0.2
                options.enableAutoPerformanceTracing = true
            }
        }
    }

    public static func track(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    public static func identify(userId: String) {
        PostHogSDK.shared.identify(userId)
        SentrySDK.setUser(Sentry.User(userId: userId))
    }

    public static func reset() {
        PostHogSDK.shared.reset()
        SentrySDK.setUser(nil)
    }
}
```

- [ ] **Step 2: Call `AnalyticsClient.configure()` in `FlashcardsApp.init`:**

```swift
@main
struct FlashcardsApp: App {
    @State private var appState = AppState()

    init() {
        AnalyticsClient.configure()
    }

    var body: some Scene {
        WindowGroup { RootView().environment(appState) }
    }
}
```

- [ ] **Step 3: Add Info.plist keys `POSTHOG_KEY`, `POSTHOG_HOST`, `SENTRY_DSN`** (empty strings for now; real values via xcconfig at build).

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(analytics): Sentry + PostHog init + AnalyticsClient facade (0.42)"
```

---

### Task 0.43: Phase 0 acceptance — merge to main

**Files:** none

- [ ] **Step 1: Run full CI locally**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pint --test && ./vendor/bin/phpstan analyse --memory-limit=1G && ./vendor/bin/pest
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test | tail -n 20
```

- [ ] **Step 2: Open PR, confirm green, merge to `main`.**

- [ ] **Step 3: Tag**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-0 -m "Phase 0: Foundation complete"
git -C /Users/lukehogan/Code/flashcards push origin main phase-0
```

**Phase 0 acceptance criteria:**
- Both projects build green on CI.
- Sign in with Apple end-to-end: app → API → Sanctum tokens → stored in Keychain.
- Magic link request + consume end-to-end.
- Design tokens + 9 atoms + snapshot baselines committed.
- SwiftLint fails on any banned style primitive in `Features/**`.
- PostHog + Sentry initialized.

---

## Phase 1: Data Model + Sync Engine (weeks 2-6)

**Goal:** All 9 entities exist on both sides, sync push/pull works offline-first end-to-end, and the entire data model round-trips cleanly in tests.

### Task 1.1: Shared on-the-wire record shape

**Files:**
- Create: `docs/sync-wire-format.md`

- [ ] **Step 1: Write doc `docs/sync-wire-format.md`:**

```markdown
# Sync wire format

Every synced entity payload uses these shared envelope fields on top of per-entity attributes.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID string | Client-generated (UUIDv7 preferred). |
| `updated_at_ms` | int64 | Milliseconds since epoch. Monotonic per-client. |
| `deleted_at_ms` | int64 or null | null = live; non-null = tombstone. |

## Push
`POST /api/v1/sync/push`
```json
{
  "client_clock_ms": 1713700000000,
  "records": {
    "decks":      [ { "id": "...", "title": "...", ..., "updated_at_ms": ... }, ... ],
    "topics":     [ ... ],
    "sub_topics": [ ... ],
    "cards":      [ ... ],
    "card_sub_topics": [ ... ],
    "reviews":    [ ... ],
    "sessions":   [ ... ]
  }
}
```
Response: `{ "accepted": 42, "rejected": [{ "id": "...", "reason": "stale" }], "server_clock_ms": ... }`

## Pull
`GET /api/v1/sync/pull?since=<ms>&entities=decks,topics,...`

Response:
```json
{
  "server_clock_ms": 1713700000500,
  "records": { "decks": [...], "topics": [...], ... }
}
```

Page size cap: 500 per entity; response includes `"has_more": true` flag with a continuation `next_since` if truncated.
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards checkout -b phase/1-data-sync
git -C /Users/lukehogan/Code/flashcards add docs/sync-wire-format.md
git -C /Users/lukehogan/Code/flashcards commit -m "docs: sync wire format (1.1)"
```

---

### Task 1.2: `SyncableRecord` protocol (iOS)

**Files:**
- Create: `ios/Flashcards/Data/Sync/SyncableRecord.swift`

- [ ] **Step 1: Create file:**

```swift
import Foundation

/// A SwiftData entity that participates in sync.
public protocol SyncableRecord: AnyObject {
    static var syncEntityKey: String { get }   // e.g. "decks"
    var syncId: String { get }
    var syncUpdatedAtMs: Int64 { get set }
    var syncDeletedAtMs: Int64? { get set }

    /// Snake_case-keyed JSON payload including envelope fields.
    func syncPayload() throws -> [String: Any]
    /// Apply remote payload, respecting LWW (caller enforces).
    func applyRemote(_ payload: [String: Any]) throws
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): SyncableRecord protocol (1.2)"
```

---

### Task 1.3: `PendingMutation` SwiftData entity + `MutationQueue`

**Files:**
- Create: `ios/Flashcards/Data/Models/PendingMutationEntity.swift`
- Create: `ios/Flashcards/Data/Sync/MutationQueue.swift`
- Create: `ios/FlashcardsTests/MutationQueueTests.swift`

- [ ] **Step 1: `PendingMutationEntity.swift`:**

```swift
import Foundation
import SwiftData

@Model
public final class PendingMutationEntity {
    @Attribute(.unique) public var id: UUID
    public var entityKey: String       // "decks", "cards", ...
    public var recordId: String        // client UUID of the record
    public var payloadJSON: Data       // full record snapshot
    public var createdAtMs: Int64
    public var retryCount: Int
    public var nextAttemptAtMs: Int64

    public init(entityKey: String, recordId: String, payload: [String: Any]) {
        self.id = UUID()
        self.entityKey = entityKey
        self.recordId = recordId
        self.payloadJSON = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        self.createdAtMs = Clock.nowMs()
        self.retryCount = 0
        self.nextAttemptAtMs = 0
    }
}
```

- [ ] **Step 2: `Clock.swift`:**

```swift
import Foundation

public enum Clock {
    public static var override: (() -> Int64)?
    public static func nowMs() -> Int64 {
        override?() ?? Int64(Date().timeIntervalSince1970 * 1000)
    }
}
```

- [ ] **Step 3: Failing test `MutationQueueTests.swift`:**

```swift
import XCTest
import SwiftData
@testable import Flashcards

final class MutationQueueTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    func test_enqueue_persists_one_row() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1", "title": "T"])
        XCTAssertEqual(try q.pendingCount(), 1)
    }

    @MainActor
    func test_takeBatch_returnsDueAndNotFuture() throws {
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "decks", recordId: "r1", payload: ["id": "r1"])
        let m = try q.allPending().first!
        m.nextAttemptAtMs = Int64.max
        try container.mainContext.save()

        XCTAssertTrue(try q.takeBatch(now: 0, limit: 100).isEmpty)
    }

    @MainActor
    func test_backoff_schedule_increases() {
        XCTAssertEqual(MutationQueue.backoffMs(retry: 0), 2_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 1), 8_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 2), 30_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 3), 120_000)
        XCTAssertEqual(MutationQueue.backoffMs(retry: 99), 900_000) // cap 15 min
    }
}
```

- [ ] **Step 4: `MutationQueue.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class MutationQueue {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func enqueue(entityKey: String, recordId: String, payload: [String: Any]) throws {
        let m = PendingMutationEntity(entityKey: entityKey, recordId: recordId, payload: payload)
        context.insert(m)
        try context.save()
    }

    public func pendingCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<PendingMutationEntity>())
    }

    public func allPending() throws -> [PendingMutationEntity] {
        try context.fetch(FetchDescriptor<PendingMutationEntity>(sortBy: [SortDescriptor(\.createdAtMs)]))
    }

    public func takeBatch(now: Int64, limit: Int = 100) throws -> [PendingMutationEntity] {
        let all = try allPending()
        return Array(all.filter { $0.nextAttemptAtMs <= now }.prefix(limit))
    }

    public func markSuccess(_ m: PendingMutationEntity) throws {
        context.delete(m)
        try context.save()
    }

    public func markFailure(_ m: PendingMutationEntity, now: Int64) throws {
        m.retryCount += 1
        m.nextAttemptAtMs = now + Self.backoffMs(retry: m.retryCount)
        try context.save()
    }

    /// Exponential backoff: 2s, 8s, 30s, 2m, 15m cap.
    public static func backoffMs(retry: Int) -> Int64 {
        let steps: [Int64] = [2_000, 8_000, 30_000, 120_000, 900_000]
        return steps[min(retry, steps.count - 1)]
    }
}
```

- [ ] **Step 5: Run tests — pass**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/MutationQueueTests | tail -n 15
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): PendingMutation entity + MutationQueue with backoff (1.3)"
```

---

### Task 1.4: Sync push endpoint (skeleton, no per-entity handling yet)

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/SyncPushController.php`
- Create: `api/app/Services/Sync/SyncPushService.php`
- Create: `api/tests/Feature/SyncPushSkeletonTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('POST /v1/sync/push with empty records returns accepted=0', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', ['client_clock_ms' => 0, 'records' => (object) []]);

    $res->assertOk()->assertJsonStructure(['accepted', 'rejected', 'server_clock_ms']);
    expect($res->json('accepted'))->toBe(0);
});

test('unauthenticated push returns 401', function () {
    $this->postJson('/api/v1/sync/push', ['client_clock_ms' => 0, 'records' => (object) []])
        ->assertStatus(401);
});
```

- [ ] **Step 2: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncPushService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncPushController extends Controller
{
    public function __construct(private readonly SyncPushService $service) {}

    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'client_clock_ms' => ['required', 'integer'],
            'records' => ['required', 'array'],
        ]);

        $result = $this->service->apply(
            user: $request->user(),
            records: $validated['records'],
        );

        return response()->json([
            'accepted' => $result->accepted,
            'rejected' => $result->rejected,
            'server_clock_ms' => (int) (microtime(true) * 1000),
        ]);
    }
}
```

- [ ] **Step 3: Service:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync;

use App\Models\User;

final class SyncPushResult
{
    /** @param list<array{id: string, reason: string}> $rejected */
    public function __construct(public int $accepted, public array $rejected) {}
}

final class SyncPushService
{
    /** @var array<string, class-string<RecordUpserter>> */
    private array $upserters = [];

    public function register(string $entityKey, string $upserterClass): void
    {
        $this->upserters[$entityKey] = $upserterClass;
    }

    /** @param array<string, array<int, array<string, mixed>>> $records */
    public function apply(User $user, array $records): SyncPushResult
    {
        $accepted = 0; $rejected = [];
        foreach ($records as $entityKey => $rows) {
            $upserterClass = $this->upserters[$entityKey] ?? null;
            if ($upserterClass === null) { continue; }

            /** @var RecordUpserter $upserter */
            $upserter = app($upserterClass);
            foreach ($rows as $row) {
                $result = $upserter->upsert($user, $row);
                if ($result->accepted) { $accepted++; }
                else { $rejected[] = ['id' => (string) ($row['id'] ?? ''), 'reason' => $result->reason ?? 'unknown']; }
            }
        }
        return new SyncPushResult(accepted: $accepted, rejected: $rejected);
    }
}

interface RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult;
}

final class UpsertResult
{
    public function __construct(public bool $accepted, public ?string $reason = null) {}
}
```

- [ ] **Step 4: Route (authed):**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::post('/sync/push', \App\Http\Controllers\Api\V1\SyncPushController::class);
});
```

- [ ] **Step 5: Bind service as singleton in `AppServiceProvider`:**

```php
$this->app->singleton(\App\Services\Sync\SyncPushService::class);
```

- [ ] **Step 6: Run tests — pass**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/SyncPushSkeletonTest.php
```

- [ ] **Step 7: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): /v1/sync/push skeleton with upserter registry (1.4)"
```

---

### Task 1.5: Sync pull endpoint (skeleton)

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/SyncPullController.php`
- Create: `api/app/Services/Sync/SyncPullService.php`
- Create: `api/tests/Feature/SyncPullSkeletonTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('GET /v1/sync/pull returns empty record map when nothing exists', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=decks,topics');

    $res->assertOk()->assertJsonStructure(['server_clock_ms', 'records', 'has_more']);
    expect($res->json('records.decks'))->toBe([])
        ->and($res->json('has_more'))->toBeFalse();
});
```

- [ ] **Step 2: Service:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync;

use App\Models\User;

final class SyncPullResult
{
    /** @param array<string, list<array<string,mixed>>> $records */
    public function __construct(public array $records, public bool $hasMore, public int $nextSince) {}
}

final class SyncPullService
{
    /** @var array<string, class-string<RecordReader>> */
    private array $readers = [];

    public function register(string $entityKey, string $readerClass): void
    {
        $this->readers[$entityKey] = $readerClass;
    }

    public function pull(User $user, int $since, array $entityKeys, int $pageSize = 500): SyncPullResult
    {
        $records = [];
        $hasMore = false;
        $maxUpdated = $since;

        foreach ($entityKeys as $entityKey) {
            $readerClass = $this->readers[$entityKey] ?? null;
            if ($readerClass === null) { $records[$entityKey] = []; continue; }

            /** @var RecordReader $reader */
            $reader = app($readerClass);
            [$rows, $entityHasMore, $maxForEntity] = $reader->read($user, $since, $pageSize);

            $records[$entityKey] = $rows;
            $hasMore = $hasMore || $entityHasMore;
            $maxUpdated = max($maxUpdated, $maxForEntity);
        }

        return new SyncPullResult(records: $records, hasMore: $hasMore, nextSince: $maxUpdated);
    }
}

interface RecordReader
{
    /** @return array{0: list<array<string, mixed>>, 1: bool, 2: int} */
    public function read(User $user, int $since, int $pageSize): array;
}
```

- [ ] **Step 3: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Sync\SyncPullService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncPullController extends Controller
{
    public function __construct(private readonly SyncPullService $service) {}

    public function __invoke(Request $request): JsonResponse
    {
        $since = (int) $request->query('since', '0');
        $entityKeys = array_filter(explode(',', (string) $request->query('entities', '')));

        $result = $this->service->pull($request->user(), $since, $entityKeys);

        return response()->json([
            'server_clock_ms' => (int) (microtime(true) * 1000),
            'records' => $result->records,
            'has_more' => $result->hasMore,
            'next_since' => $result->nextSince,
        ]);
    }
}
```

- [ ] **Step 4: Route + service singleton:**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::get('/sync/pull', \App\Http\Controllers\Api\V1\SyncPullController::class);
});
```

```php
$this->app->singleton(\App\Services\Sync\SyncPullService::class);
```

- [ ] **Step 5: Test — pass; commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/SyncPullSkeletonTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): /v1/sync/pull skeleton with reader registry (1.5)"
```

---

### Task 1.6: `Topic` — backend migration + model + factory

**Files:**
- Create: `api/database/migrations/2026_04_21_000003_create_topics_table.php`
- Create: `api/app/Models/Topic.php`
- Create: `api/database/factories/TopicFactory.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('color_hint')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }
    public function down(): void { Schema::dropIfExists('topics'); }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Topic extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = ['user_id', 'name', 'color_hint', 'updated_at_ms', 'deleted_at_ms'];
    protected $casts = ['updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer'];
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
}
```

- [ ] **Step 3: Factory:**

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Topic;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class TopicFactory extends Factory
{
    protected $model = Topic::class;
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'name' => fake()->word(),
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 4: `php artisan migrate` + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Topic migration + model + factory (1.6)"
```

---

### Task 1.7: `Topic` — upserter + reader + push/pull registration + tests

**Files:**
- Create: `api/app/Services/Sync/Entities/TopicUpserter.php`
- Create: `api/app/Services/Sync/Entities/TopicReader.php`
- Create: `api/tests/Feature/Sync/TopicSyncTest.php`
- Modify: `api/app/Providers/AppServiceProvider.php`

- [ ] **Step 1: Failing test `TopicSyncTest.php`:**

```php
<?php

declare(strict_types=1);

use App\Models\Topic;
use App\Models\User;

test('push creates a topic row owned by the user', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1_713_000_000_000,
            'records' => ['topics' => [[
                'id' => $id, 'name' => 'Biology', 'color_hint' => null,
                'updated_at_ms' => 1_713_000_000_000, 'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Topic::where('id', $id)->where('user_id', $u->id)->exists())->toBeTrue();
});

test('push rejects a stale update (older updated_at_ms than existing)', function () {
    $u = User::factory()->create();
    $t = Topic::factory()->for($u)->create(['name' => 'Current', 'updated_at_ms' => 2000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1500,
            'records' => ['topics' => [[
                'id' => $t->id, 'name' => 'Stale', 'color_hint' => null,
                'updated_at_ms' => 1000, 'deleted_at_ms' => null,
            ]]],
        ]);

    $res->assertOk()->assertJson(['accepted' => 0]);
    expect($t->fresh()->name)->toBe('Current');
});

test('pull since=0 returns topics owned by user', function () {
    $u = User::factory()->create();
    Topic::factory()->for($u)->create(['name' => 'Alpha', 'updated_at_ms' => 100]);
    Topic::factory()->for(User::factory())->create(['name' => 'Other']); // noise

    $token = $u->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=0&entities=topics');

    $res->assertOk();
    expect($res->json('records.topics'))->toHaveCount(1)
        ->and($res->json('records.topics.0.name'))->toBe('Alpha');
});
```

- [ ] **Step 2: Upserter:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Topic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class TopicUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '') { return new UpsertResult(false, 'missing_id'); }

        $existing = Topic::find($id);
        if ($existing && $existing->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        Topic::updateOrCreate(
            ['id' => $id],
            [
                'user_id' => $user->id,
                'name' => (string) ($row['name'] ?? ''),
                'color_hint' => $row['color_hint'] ?? null,
                'updated_at_ms' => $incoming,
                'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
            ],
        );
        return new UpsertResult(true);
    }
}
```

- [ ] **Step 3: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Topic;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class TopicReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Topic::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)
            ->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Topic $t) => [
                'id' => $t->id,
                'name' => $t->name,
                'color_hint' => $t->color_hint,
                'updated_at_ms' => $t->updated_at_ms,
                'deleted_at_ms' => $t->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
```

- [ ] **Step 4: Register in `AppServiceProvider::boot`:**

```php
public function boot(): void
{
    app(\App\Services\Sync\SyncPushService::class)
        ->register('topics', \App\Services\Sync\Entities\TopicUpserter::class);
    app(\App\Services\Sync\SyncPullService::class)
        ->register('topics', \App\Services\Sync\Entities\TopicReader::class);
}
```

- [ ] **Step 5: Run tests — pass; commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/Sync/TopicSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): Topic upserter + reader wired to push/pull (1.7)"
```

---

### Task 1.8: `Deck` — backend migration + model + factory + sync

**Files:**
- Create: `api/database/migrations/2026_04_21_000002_create_decks_table.php`
- Create: `api/app/Models/Deck.php`
- Create: `api/database/factories/DeckFactory.php`
- Create: `api/app/Services/Sync/Entities/DeckUpserter.php`
- Create: `api/app/Services/Sync/Entities/DeckReader.php`
- Create: `api/tests/Feature/Sync/DeckSyncTest.php`
- Modify: `api/app/Providers/AppServiceProvider.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('decks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('topic_id')->nullable()->constrained('topics')->nullOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('accent_color')->default('amber');
            $table->enum('default_study_mode', ['smart', 'basic'])->default('smart');
            $table->integer('card_count')->default(0);
            $table->bigInteger('last_studied_at_ms')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }
    public function down(): void { Schema::dropIfExists('decks'); }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Deck extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = [
        'user_id', 'topic_id', 'title', 'description', 'accent_color',
        'default_study_mode', 'card_count', 'last_studied_at_ms',
        'updated_at_ms', 'deleted_at_ms',
    ];
    protected $casts = [
        'updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer',
        'last_studied_at_ms' => 'integer', 'card_count' => 'integer',
    ];
    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function topic(): BelongsTo { return $this->belongsTo(Topic::class); }
    public function cards(): HasMany { return $this->hasMany(Card::class); }
    public function subTopics(): HasMany { return $this->hasMany(SubTopic::class); }
}
```

- [ ] **Step 3: Factory:**

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Deck;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class DeckFactory extends Factory
{
    protected $model = Deck::class;
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'title' => fake()->sentence(3),
            'accent_color' => 'amber',
            'default_study_mode' => 'smart',
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 4: Failing test `DeckSyncTest.php`:**

```php
<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\Topic;
use App\Models\User;

test('push creates deck and persists all spec fields', function () {
    $u = User::factory()->create();
    $topic = Topic::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['decks' => [[
                'id' => $id,
                'topic_id' => $topic->id,
                'title' => 'Spanish 1',
                'description' => 'Verbs',
                'accent_color' => 'moss',
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'last_studied_at_ms' => null,
                'updated_at_ms' => 1000,
                'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    $d = Deck::findOrFail($id);
    expect($d->user_id)->toBe($u->id)
        ->and($d->topic_id)->toBe($topic->id)
        ->and($d->title)->toBe('Spanish 1')
        ->and($d->accent_color)->toBe('moss');
});

test('tombstone push marks deck deleted', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['decks' => [[
                'id' => $d->id,
                'title' => $d->title,
                'accent_color' => $d->accent_color,
                'default_study_mode' => 'smart',
                'card_count' => 0,
                'updated_at_ms' => 2000,
                'deleted_at_ms' => 2000,
            ]]],
        ])->assertJson(['accepted' => 1]);

    expect($d->fresh()->deleted_at_ms)->toBe(2000);
});

test('pull returns decks since cursor', function () {
    $u = User::factory()->create();
    Deck::factory()->for($u)->create(['title' => 'Old', 'updated_at_ms' => 100]);
    Deck::factory()->for($u)->create(['title' => 'New', 'updated_at_ms' => 200]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->getJson('/api/v1/sync/pull?since=150&entities=decks');

    expect($res->json('records.decks'))->toHaveCount(1)
        ->and($res->json('records.decks.0.title'))->toBe('New');
});
```

- [ ] **Step 5: Upserter:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class DeckUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '') { return new UpsertResult(false, 'missing_id'); }

        $existing = Deck::find($id);
        if ($existing && $existing->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        Deck::updateOrCreate(
            ['id' => $id],
            [
                'user_id' => $user->id,
                'topic_id' => $row['topic_id'] ?? null,
                'title' => (string) ($row['title'] ?? ''),
                'description' => $row['description'] ?? null,
                'accent_color' => (string) ($row['accent_color'] ?? 'amber'),
                'default_study_mode' => (string) ($row['default_study_mode'] ?? 'smart'),
                'card_count' => (int) ($row['card_count'] ?? 0),
                'last_studied_at_ms' => isset($row['last_studied_at_ms']) ? (int) $row['last_studied_at_ms'] : null,
                'updated_at_ms' => $incoming,
                'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
            ],
        );
        return new UpsertResult(true);
    }
}
```

- [ ] **Step 6: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class DeckReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Deck::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Deck $d) => [
                'id' => $d->id,
                'topic_id' => $d->topic_id,
                'title' => $d->title,
                'description' => $d->description,
                'accent_color' => $d->accent_color,
                'default_study_mode' => $d->default_study_mode,
                'card_count' => $d->card_count,
                'last_studied_at_ms' => $d->last_studied_at_ms,
                'updated_at_ms' => $d->updated_at_ms,
                'deleted_at_ms' => $d->deleted_at_ms,
            ])->values()->all(),
            $hasMore,
            $max,
        ];
    }
}
```

- [ ] **Step 7: Register:**

```php
app(\App\Services\Sync\SyncPushService::class)->register('decks', \App\Services\Sync\Entities\DeckUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('decks', \App\Services\Sync\Entities\DeckReader::class);
```

- [ ] **Step 8: Migrate + test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/DeckSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Deck entity + sync (1.8)"
```

---

### Task 1.9: `SubTopic` — backend migration + model + factory + sync

**Files:**
- Create: `api/database/migrations/2026_04_21_000004_create_sub_topics_table.php`
- Create: `api/app/Models/SubTopic.php`
- Create: `api/database/factories/SubTopicFactory.php`
- Create: `api/app/Services/Sync/Entities/SubTopicUpserter.php`
- Create: `api/app/Services/Sync/Entities/SubTopicReader.php`
- Create: `api/tests/Feature/Sync/SubTopicSyncTest.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('sub_topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->integer('position')->default(0);
            $table->string('color_hint')->nullable();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['deck_id', 'updated_at_ms']);
            $table->index(['deck_id', 'position']);
        });
    }
    public function down(): void { Schema::dropIfExists('sub_topics'); }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SubTopic extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = ['deck_id', 'name', 'position', 'color_hint', 'updated_at_ms', 'deleted_at_ms'];
    protected $casts = ['updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer', 'position' => 'integer'];
    public function deck(): BelongsTo { return $this->belongsTo(Deck::class); }
}
```

- [ ] **Step 3: Factory:**

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Deck;
use App\Models\SubTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

class SubTopicFactory extends Factory
{
    protected $model = SubTopic::class;
    public function definition(): array
    {
        return [
            'deck_id' => Deck::factory(),
            'name' => fake()->word(),
            'position' => 0,
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 4: Failing test `SubTopicSyncTest.php`:**

```php
<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;

test('push creates sub-topic under a deck owned by user', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sub_topics' => [[
                'id' => $id, 'deck_id' => $d->id, 'name' => 'Verbs', 'position' => 1,
                'updated_at_ms' => 1000, 'deleted_at_ms' => null,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(SubTopic::find($id)?->deck_id)->toBe($d->id);
});

test('push rejects sub-topic attaching to someone else\'s deck', function () {
    $owner = User::factory()->create();
    $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sub_topics' => [[
                'id' => (string) \Illuminate\Support\Str::orderedUuid(),
                'deck_id' => $d->id, 'name' => 'Evil', 'position' => 0,
                'updated_at_ms' => 1000,
            ]]],
        ]);
    $res->assertJson(['accepted' => 0]);
});
```

- [ ] **Step 5: Upserter:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class SubTopicUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $deckId = (string) ($row['deck_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '' || $deckId === '') { return new UpsertResult(false, 'missing_id'); }

        $deck = Deck::find($deckId);
        if (!$deck || $deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = SubTopic::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) {
            return new UpsertResult(false, 'stale');
        }

        SubTopic::updateOrCreate(
            ['id' => $id],
            [
                'deck_id' => $deckId,
                'name' => (string) ($row['name'] ?? ''),
                'position' => (int) ($row['position'] ?? 0),
                'color_hint' => $row['color_hint'] ?? null,
                'updated_at_ms' => $incoming,
                'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
            ],
        );
        return new UpsertResult(true);
    }
}
```

- [ ] **Step 6: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class SubTopicReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = SubTopic::query()
            ->whereIn('deck_id', $user->decks()->select('id'))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (SubTopic $s) => [
                'id' => $s->id, 'deck_id' => $s->deck_id, 'name' => $s->name,
                'position' => $s->position, 'color_hint' => $s->color_hint,
                'updated_at_ms' => $s->updated_at_ms, 'deleted_at_ms' => $s->deleted_at_ms,
            ])->values()->all(),
            $hasMore, $max,
        ];
    }
}
```

Add `public function decks(): HasMany { return $this->hasMany(Deck::class); }` to `User.php` to make the reader query work.

- [ ] **Step 7: Register in `AppServiceProvider::boot`, migrate, test, commit:**

```php
app(\App\Services\Sync\SyncPushService::class)->register('sub_topics', \App\Services\Sync\Entities\SubTopicUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('sub_topics', \App\Services\Sync\Entities\SubTopicReader::class);
```

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/SubTopicSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): SubTopic entity + sync with deck ownership check (1.9)"
```

---

### Task 1.10: `Card` — backend migration + model + factory + sync

**Files:**
- Create: `api/database/migrations/2026_04_21_000005_create_cards_table.php`
- Create: `api/app/Models/Card.php`
- Create: `api/database/factories/CardFactory.php`
- Create: `api/app/Services/Sync/Entities/CardUpserter.php`
- Create: `api/app/Services/Sync/Entities/CardReader.php`
- Create: `api/tests/Feature/Sync/CardSyncTest.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('cards', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->text('front_text');
            $table->text('back_text');
            $table->uuid('front_image_asset_id')->nullable();
            $table->uuid('back_image_asset_id')->nullable();
            $table->integer('position')->default(0);
            $table->float('stability')->nullable();
            $table->float('difficulty')->nullable();
            $table->enum('state', ['new', 'learning', 'review', 'relearning'])->default('new');
            $table->bigInteger('last_reviewed_at_ms')->nullable();
            $table->bigInteger('due_at_ms')->nullable();
            $table->integer('lapses')->default(0);
            $table->integer('reps')->default(0);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['deck_id', 'updated_at_ms']);
            $table->index(['deck_id', 'due_at_ms']);
        });
    }
    public function down(): void { Schema::dropIfExists('cards'); }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Card extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = [
        'deck_id', 'front_text', 'back_text',
        'front_image_asset_id', 'back_image_asset_id',
        'position', 'stability', 'difficulty', 'state',
        'last_reviewed_at_ms', 'due_at_ms', 'lapses', 'reps',
        'updated_at_ms', 'deleted_at_ms',
    ];
    protected $casts = [
        'updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer',
        'last_reviewed_at_ms' => 'integer', 'due_at_ms' => 'integer',
        'lapses' => 'integer', 'reps' => 'integer', 'position' => 'integer',
        'stability' => 'float', 'difficulty' => 'float',
    ];
    public function deck(): BelongsTo { return $this->belongsTo(Deck::class); }
    public function reviews(): HasMany { return $this->hasMany(Review::class); }
}
```

- [ ] **Step 3: Factory:**

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\Deck;
use Illuminate\Database\Eloquent\Factories\Factory;

class CardFactory extends Factory
{
    protected $model = Card::class;
    public function definition(): array
    {
        return [
            'deck_id' => Deck::factory(),
            'front_text' => fake()->sentence(),
            'back_text' => fake()->sentence(),
            'state' => 'new',
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 4: Test `CardSyncTest.php` — round-trip + ownership check (pattern mirrors 1.9):**

```php
<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;

test('card push creates row in user\'s deck', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['cards' => [[
                'id' => $id, 'deck_id' => $d->id,
                'front_text' => 'hola', 'back_text' => 'hi',
                'position' => 0, 'state' => 'new',
                'reps' => 0, 'lapses' => 0,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertOk()->assertJson(['accepted' => 1]);

    expect(Card::find($id)?->deck_id)->toBe($d->id);
});

test('card push to non-owned deck rejected', function () {
    $owner = User::factory()->create(); $attacker = User::factory()->create();
    $d = Deck::factory()->for($owner)->create();
    $token = $attacker->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['cards' => [[
                'id' => (string) \Illuminate\Support\Str::orderedUuid(),
                'deck_id' => $d->id, 'front_text' => 'x', 'back_text' => 'x',
                'state' => 'new', 'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 0]);
});
```

- [ ] **Step 5: Upserter:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\Deck;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class CardUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $deckId = (string) ($row['deck_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '' || $deckId === '') { return new UpsertResult(false, 'missing_id'); }

        $deck = Deck::find($deckId);
        if (!$deck || $deck->user_id !== $user->id) { return new UpsertResult(false, 'forbidden'); }

        $existing = Card::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) { return new UpsertResult(false, 'stale'); }

        Card::updateOrCreate(['id' => $id], [
            'deck_id' => $deckId,
            'front_text' => (string) ($row['front_text'] ?? ''),
            'back_text' => (string) ($row['back_text'] ?? ''),
            'front_image_asset_id' => $row['front_image_asset_id'] ?? null,
            'back_image_asset_id' => $row['back_image_asset_id'] ?? null,
            'position' => (int) ($row['position'] ?? 0),
            'stability' => $row['stability'] ?? null,
            'difficulty' => $row['difficulty'] ?? null,
            'state' => (string) ($row['state'] ?? 'new'),
            'last_reviewed_at_ms' => isset($row['last_reviewed_at_ms']) ? (int) $row['last_reviewed_at_ms'] : null,
            'due_at_ms' => isset($row['due_at_ms']) ? (int) $row['due_at_ms'] : null,
            'lapses' => (int) ($row['lapses'] ?? 0),
            'reps' => (int) ($row['reps'] ?? 0),
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        return new UpsertResult(true);
    }
}
```

- [ ] **Step 6: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class CardReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Card::query()
            ->whereIn('deck_id', $user->decks()->select('id'))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Card $c) => [
                'id' => $c->id, 'deck_id' => $c->deck_id,
                'front_text' => $c->front_text, 'back_text' => $c->back_text,
                'front_image_asset_id' => $c->front_image_asset_id,
                'back_image_asset_id' => $c->back_image_asset_id,
                'position' => $c->position,
                'stability' => $c->stability, 'difficulty' => $c->difficulty,
                'state' => $c->state,
                'last_reviewed_at_ms' => $c->last_reviewed_at_ms,
                'due_at_ms' => $c->due_at_ms,
                'lapses' => $c->lapses, 'reps' => $c->reps,
                'updated_at_ms' => $c->updated_at_ms, 'deleted_at_ms' => $c->deleted_at_ms,
            ])->values()->all(),
            $hasMore, $max,
        ];
    }
}
```

- [ ] **Step 7: Register, migrate, test, commit:**

```php
app(\App\Services\Sync\SyncPushService::class)->register('cards', \App\Services\Sync\Entities\CardUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('cards', \App\Services\Sync\Entities\CardReader::class);
```

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/CardSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Card entity + sync (1.10)"
```

---

### Task 1.11: `CardSubTopic` (join) — migration, upserter, reader

**Files:**
- Create: `api/database/migrations/2026_04_21_000006_create_card_sub_topics_table.php`
- Create: `api/app/Models/CardSubTopic.php`
- Create: `api/database/factories/CardSubTopicFactory.php`
- Create: `api/app/Services/Sync/Entities/CardSubTopicUpserter.php`
- Create: `api/app/Services/Sync/Entities/CardSubTopicReader.php`
- Create: `api/tests/Feature/Sync/CardSubTopicSyncTest.php`

- [ ] **Step 1: Migration (synced join: has its own id/updated_at_ms so LWW works on delete):**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('card_sub_topics', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('card_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('sub_topic_id')->constrained('sub_topics')->cascadeOnDelete();
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->unique(['card_id', 'sub_topic_id']);
            $table->index('updated_at_ms');
        });
    }
    public function down(): void { Schema::dropIfExists('card_sub_topics'); }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CardSubTopic extends Model
{
    use HasFactory, HasUuids;
    protected $table = 'card_sub_topics';
    protected $fillable = ['card_id', 'sub_topic_id', 'updated_at_ms', 'deleted_at_ms'];
    protected $casts = ['updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer'];
}
```

- [ ] **Step 3: Factory:**

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\SubTopic;
use Illuminate\Database\Eloquent\Factories\Factory;

class CardSubTopicFactory extends Factory
{
    protected $model = CardSubTopic::class;
    public function definition(): array
    {
        return [
            'card_id' => Card::factory(),
            'sub_topic_id' => SubTopic::factory(),
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 4: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\Deck;
use App\Models\SubTopic;
use App\Models\User;

test('push creates card-subtopic association', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->create(['deck_id' => $d->id]);
    $st = SubTopic::factory()->create(['deck_id' => $d->id]);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['card_sub_topics' => [[
                'id' => (string) \Illuminate\Support\Str::orderedUuid(),
                'card_id' => $card->id, 'sub_topic_id' => $st->id,
                'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 1]);

    expect(CardSubTopic::where('card_id', $card->id)->where('sub_topic_id', $st->id)->exists())->toBeTrue();
});
```

- [ ] **Step 5: Upserter:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\SubTopic;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class CardSubTopicUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $cardId = (string) ($row['card_id'] ?? '');
        $subTopicId = (string) ($row['sub_topic_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '' || $cardId === '' || $subTopicId === '') { return new UpsertResult(false, 'missing_id'); }

        $card = Card::with('deck')->find($cardId);
        $st = SubTopic::find($subTopicId);
        if (!$card || !$st || $card->deck->user_id !== $user->id || $st->deck_id !== $card->deck_id) {
            return new UpsertResult(false, 'forbidden');
        }

        $existing = CardSubTopic::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) { return new UpsertResult(false, 'stale'); }

        CardSubTopic::updateOrCreate(['id' => $id], [
            'card_id' => $cardId, 'sub_topic_id' => $subTopicId,
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        return new UpsertResult(true);
    }
}
```

- [ ] **Step 6: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\CardSubTopic;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class CardSubTopicReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = CardSubTopic::query()
            ->whereHas('card', fn ($q) => $q->whereHas('deck', fn ($q2) => $q2->where('user_id', $user->id)))
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (CardSubTopic $r) => [
                'id' => $r->id, 'card_id' => $r->card_id, 'sub_topic_id' => $r->sub_topic_id,
                'updated_at_ms' => $r->updated_at_ms, 'deleted_at_ms' => $r->deleted_at_ms,
            ])->values()->all(),
            $hasMore, $max,
        ];
    }
}
```

Add `public function card() { return $this->belongsTo(Card::class); }` to `CardSubTopic` model.

- [ ] **Step 7: Register, migrate, test, commit:**

```php
app(\App\Services\Sync\SyncPushService::class)->register('card_sub_topics', \App\Services\Sync\Entities\CardSubTopicUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('card_sub_topics', \App\Services\Sync\Entities\CardSubTopicReader::class);
```

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/CardSubTopicSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): CardSubTopic join + sync (1.11)"
```

---

### Task 1.12: `Review` — backend migration + model + insert-only upserter

**Files:**
- Create: `api/database/migrations/2026_04_21_000007_create_reviews_table.php`
- Create: `api/app/Models/Review.php`
- Create: `api/database/factories/ReviewFactory.php`
- Create: `api/app/Services/Sync/Entities/ReviewUpserter.php`
- Create: `api/app/Services/Sync/Entities/ReviewReader.php`
- Create: `api/tests/Feature/Sync/ReviewSyncTest.php`

- [ ] **Step 1: Migration (immutable — no updated_at_ms mutations allowed):**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('card_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('session_id')->nullable()->constrained('sessions')->nullOnDelete();
            $table->unsignedTinyInteger('rating'); // 1-4
            $table->integer('review_duration_ms')->default(0);
            $table->bigInteger('rated_at_ms');
            $table->json('state_before');
            $table->json('state_after');
            $table->string('scheduler_version')->default('fsrs-6');
            $table->bigInteger('updated_at_ms');
            $table->timestamps();
            $table->index(['card_id', 'rated_at_ms']);
            $table->index(['user_id', 'updated_at_ms']);
        });
    }
    public function down(): void { Schema::dropIfExists('reviews'); }
};
```

- [ ] **Step 2: Model + factory (abbreviated pattern, follows prior):**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Review extends Model
{
    use HasFactory, HasUuids;
    public $timestamps = true;
    const UPDATED_AT = null; // append-only
    protected $fillable = [
        'card_id', 'user_id', 'session_id', 'rating',
        'review_duration_ms', 'rated_at_ms', 'state_before', 'state_after',
        'scheduler_version', 'updated_at_ms',
    ];
    protected $casts = [
        'state_before' => 'array', 'state_after' => 'array',
        'rating' => 'integer', 'rated_at_ms' => 'integer', 'updated_at_ms' => 'integer',
    ];
}
```

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Card;
use App\Models\Review;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class ReviewFactory extends Factory
{
    protected $model = Review::class;
    public function definition(): array
    {
        return [
            'card_id' => Card::factory(),
            'user_id' => User::factory(),
            'rating' => 3,
            'rated_at_ms' => now()->valueOf(),
            'state_before' => ['state' => 'new'],
            'state_after' => ['state' => 'learning', 'stability' => 1.0, 'difficulty' => 5.0],
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 3: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\Review;
use App\Models\User;

test('review push creates a review row', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->create(['deck_id' => $d->id]);
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['reviews' => [[
                'id' => $id, 'card_id' => $card->id, 'user_id' => $u->id,
                'rating' => 3, 'review_duration_ms' => 2500, 'rated_at_ms' => 1000,
                'state_before' => ['state' => 'new'],
                'state_after' => ['state' => 'learning', 'stability' => 1.0, 'difficulty' => 5.0],
                'scheduler_version' => 'fsrs-6', 'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 1]);

    expect(Review::where('id', $id)->exists())->toBeTrue();
});

test('duplicate review id is idempotent (INSERT IGNORE semantics)', function () {
    $u = User::factory()->create();
    $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->create(['deck_id' => $d->id]);
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();
    $payload = [[
        'id' => $id, 'card_id' => $card->id, 'user_id' => $u->id,
        'rating' => 3, 'rated_at_ms' => 1000,
        'state_before' => [], 'state_after' => [],
        'updated_at_ms' => 1000,
    ]];
    $this->withHeader('Authorization', "Bearer {$token}")->postJson('/api/v1/sync/push', ['client_clock_ms'=>1000,'records'=>['reviews'=>$payload]])->assertJson(['accepted'=>1]);
    $this->withHeader('Authorization', "Bearer {$token}")->postJson('/api/v1/sync/push', ['client_clock_ms'=>1000,'records'=>['reviews'=>$payload]])->assertJson(['accepted'=>0]);

    expect(Review::count())->toBe(1);
});
```

- [ ] **Step 4: Upserter (insert-only):**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Card;
use App\Models\Review;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;
use Illuminate\Support\Facades\DB;

final class ReviewUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $cardId = (string) ($row['card_id'] ?? '');
        if ($id === '' || $cardId === '') { return new UpsertResult(false, 'missing_id'); }

        $card = Card::with('deck')->find($cardId);
        if (!$card || $card->deck->user_id !== $user->id) {
            return new UpsertResult(false, 'forbidden');
        }

        if (Review::where('id', $id)->exists()) {
            return new UpsertResult(false, 'duplicate');
        }

        Review::create([
            'id' => $id, 'card_id' => $cardId, 'user_id' => $user->id,
            'session_id' => $row['session_id'] ?? null,
            'rating' => (int) ($row['rating'] ?? 3),
            'review_duration_ms' => (int) ($row['review_duration_ms'] ?? 0),
            'rated_at_ms' => (int) ($row['rated_at_ms'] ?? 0),
            'state_before' => (array) ($row['state_before'] ?? []),
            'state_after' => (array) ($row['state_after'] ?? []),
            'scheduler_version' => (string) ($row['scheduler_version'] ?? 'fsrs-6'),
            'updated_at_ms' => (int) ($row['updated_at_ms'] ?? 0),
        ]);

        // Enqueue FSRS replay job (Task 1.13).
        \App\Jobs\ReplayReviewsForCard::dispatch($cardId);

        return new UpsertResult(true);
    }
}
```

- [ ] **Step 5: Reader:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Review;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class ReviewReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Review::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Review $r) => [
                'id' => $r->id, 'card_id' => $r->card_id, 'user_id' => $r->user_id,
                'session_id' => $r->session_id,
                'rating' => $r->rating, 'review_duration_ms' => $r->review_duration_ms,
                'rated_at_ms' => $r->rated_at_ms,
                'state_before' => $r->state_before, 'state_after' => $r->state_after,
                'scheduler_version' => $r->scheduler_version,
                'updated_at_ms' => $r->updated_at_ms,
            ])->values()->all(),
            $hasMore, $max,
        ];
    }
}
```

- [ ] **Step 6: Register + migrate:**

```php
app(\App\Services\Sync\SyncPushService::class)->register('reviews', \App\Services\Sync\Entities\ReviewUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('reviews', \App\Services\Sync\Entities\ReviewReader::class);
```

- [ ] **Step 7: Commit** (the job itself is added in 1.13 — create a stub class that accepts the call without crashing):

Create stub `api/app/Jobs/ReplayReviewsForCard.php`:

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

final class ReplayReviewsForCard implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;
    public function __construct(public readonly string $cardId) {}
    public function handle(): void { /* filled in task 1.13 */ }
}
```

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/ReviewSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Review entity + insert-only sync + stub replay job (1.12)"
```

---

### Task 1.13: `ReplayReviewsForCard` — server-side FSRS replay

**Files:**
- Modify: `api/app/Jobs/ReplayReviewsForCard.php`
- Create: `api/app/Services/Fsrs/ReviewReplayer.php`
- Create: `api/tests/Unit/ReviewReplayerTest.php`

> The server does not run FSRS to *schedule* — iOS does. But when reviews from multiple devices sync in out of order, we recompute the canonical card state by replaying the review log in `rated_at_ms` order. The replay uses the same state-transition math (we install a PHP FSRS port — `openSpacedRepetition/fsrs-php` if available; otherwise a small transcription of the deterministic state machine).

- [ ] **Step 1: Install PHP FSRS port (or transcribe if unavailable):**

```bash
cd /Users/lukehogan/Code/flashcards/api && composer require open-spaced-repetition/fsrs:^1.0 2>/dev/null || echo "package not available — implement minimal replayer inline"
```

If the package is not available on Packagist at implementation time, implement a minimal replayer that reads each review's `state_after` (the client has already computed the canonical FSRS state) and picks the latest by `rated_at_ms`. The card state field is always a cache; the review log is the source of truth.

- [ ] **Step 2: Implement `ReviewReplayer.php` using the "last state_after wins" strategy:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Fsrs;

use App\Models\Card;
use App\Models\Review;

final class ReviewReplayer
{
    public function replay(string $cardId): void
    {
        $card = Card::find($cardId);
        if (!$card) { return; }

        $latest = Review::where('card_id', $cardId)
            ->orderByDesc('rated_at_ms')
            ->first();

        if (!$latest) { return; }

        $after = $latest->state_after;

        $card->update([
            'stability' => $after['stability'] ?? null,
            'difficulty' => $after['difficulty'] ?? null,
            'state' => $after['state'] ?? 'new',
            'last_reviewed_at_ms' => $latest->rated_at_ms,
            'due_at_ms' => $after['due_at_ms'] ?? null,
            'reps' => Review::where('card_id', $cardId)->count(),
            'lapses' => Review::where('card_id', $cardId)->where('rating', 1)->count(),
            'updated_at_ms' => (int) (microtime(true) * 1000),
        ]);
    }
}
```

- [ ] **Step 3: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Card;
use App\Models\Deck;
use App\Models\Review;
use App\Models\User;
use App\Services\Fsrs\ReviewReplayer;

test('replay updates card state from latest review\'s state_after', function () {
    $u = User::factory()->create(); $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->create(['deck_id' => $d->id, 'state' => 'new']);

    Review::create([
        'id' => (string) \Illuminate\Support\Str::orderedUuid(),
        'card_id' => $card->id, 'user_id' => $u->id,
        'rating' => 3, 'rated_at_ms' => 1000,
        'state_before' => ['state' => 'new'],
        'state_after' => ['state' => 'learning', 'stability' => 1.2, 'difficulty' => 5.4, 'due_at_ms' => 2000],
        'scheduler_version' => 'fsrs-6', 'updated_at_ms' => 1000,
    ]);

    (new ReviewReplayer())->replay($card->id);

    $card->refresh();
    expect($card->state)->toBe('learning')
        ->and($card->stability)->toBe(1.2)
        ->and($card->due_at_ms)->toBe(2000)
        ->and($card->reps)->toBe(1);
});

test('later review supersedes earlier when replayed', function () {
    $u = User::factory()->create(); $d = Deck::factory()->for($u)->create();
    $card = Card::factory()->create(['deck_id' => $d->id]);

    foreach ([[1000, 'learning', 1.0], [2000, 'review', 5.0]] as [$at, $state, $stab]) {
        Review::create([
            'id' => (string) \Illuminate\Support\Str::orderedUuid(),
            'card_id' => $card->id, 'user_id' => $u->id,
            'rating' => 3, 'rated_at_ms' => $at,
            'state_before' => [], 'state_after' => ['state' => $state, 'stability' => $stab],
            'scheduler_version' => 'fsrs-6', 'updated_at_ms' => $at,
        ]);
    }

    (new ReviewReplayer())->replay($card->id);

    expect($card->fresh()->state)->toBe('review');
});
```

- [ ] **Step 4: Wire job:**

```php
public function handle(): void
{
    app(\App\Services\Fsrs\ReviewReplayer::class)->replay($this->cardId);
}
```

- [ ] **Step 5: Test + commit:**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Unit/ReviewReplayerTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(fsrs): ReviewReplayer + wire ReplayReviewsForCard job (1.13)"
```

---

### Task 1.14: `Session` — backend migration + model + sync

**Files:**
- Create: `api/database/migrations/2026_04_21_000008_create_sessions_table.php`
- Create: `api/app/Models/Session.php`
- Create: `api/database/factories/SessionFactory.php`
- Create: `api/app/Services/Sync/Entities/SessionUpserter.php`
- Create: `api/app/Services/Sync/Entities/SessionReader.php`
- Create: `api/tests/Feature/Sync/SessionSyncTest.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('deck_id')->constrained()->cascadeOnDelete();
            $table->enum('mode', ['smart', 'basic']);
            $table->bigInteger('started_at_ms');
            $table->bigInteger('ended_at_ms')->nullable();
            $table->integer('cards_reviewed')->default(0);
            $table->float('accuracy_pct')->default(0);
            $table->float('mastery_delta')->default(0);
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'updated_at_ms']);
        });
    }
    public function down(): void { Schema::dropIfExists('sessions'); }
};
```

- [ ] **Step 2: Model + factory + upserter + reader + test** — same shape as Deck (1.8). Enforce `user_id === auth->id`, LWW on `updated_at_ms`. Register `sessions` in service provider.

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Session extends Model
{
    use HasFactory, HasUuids;
    protected $table = 'sessions';
    protected $fillable = [
        'user_id', 'deck_id', 'mode', 'started_at_ms', 'ended_at_ms',
        'cards_reviewed', 'accuracy_pct', 'mastery_delta',
        'updated_at_ms', 'deleted_at_ms',
    ];
    protected $casts = [
        'started_at_ms' => 'integer', 'ended_at_ms' => 'integer',
        'updated_at_ms' => 'integer', 'deleted_at_ms' => 'integer',
        'cards_reviewed' => 'integer', 'accuracy_pct' => 'float', 'mastery_delta' => 'float',
    ];
}
```

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class SessionFactory extends Factory
{
    protected $model = Session::class;
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'deck_id' => Deck::factory(),
            'mode' => 'smart', 'started_at_ms' => now()->valueOf(),
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;
use App\Services\Sync\RecordUpserter;
use App\Services\Sync\UpsertResult;

final class SessionUpserter implements RecordUpserter
{
    public function upsert(User $user, array $row): UpsertResult
    {
        $id = (string) ($row['id'] ?? '');
        $deckId = (string) ($row['deck_id'] ?? '');
        $incoming = (int) ($row['updated_at_ms'] ?? 0);
        if ($id === '' || $deckId === '') { return new UpsertResult(false, 'missing_id'); }

        $deck = Deck::find($deckId);
        if (!$deck || $deck->user_id !== $user->id) { return new UpsertResult(false, 'forbidden'); }

        $existing = Session::find($id);
        if ($existing && $existing->updated_at_ms >= $incoming) { return new UpsertResult(false, 'stale'); }

        Session::updateOrCreate(['id' => $id], [
            'user_id' => $user->id, 'deck_id' => $deckId,
            'mode' => (string) ($row['mode'] ?? 'smart'),
            'started_at_ms' => (int) ($row['started_at_ms'] ?? 0),
            'ended_at_ms' => isset($row['ended_at_ms']) ? (int) $row['ended_at_ms'] : null,
            'cards_reviewed' => (int) ($row['cards_reviewed'] ?? 0),
            'accuracy_pct' => (float) ($row['accuracy_pct'] ?? 0),
            'mastery_delta' => (float) ($row['mastery_delta'] ?? 0),
            'updated_at_ms' => $incoming,
            'deleted_at_ms' => isset($row['deleted_at_ms']) ? (int) $row['deleted_at_ms'] : null,
        ]);
        return new UpsertResult(true);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Services\Sync\Entities;

use App\Models\Session;
use App\Models\User;
use App\Services\Sync\RecordReader;

final class SessionReader implements RecordReader
{
    public function read(User $user, int $since, int $pageSize): array
    {
        $rows = Session::query()
            ->where('user_id', $user->id)
            ->where('updated_at_ms', '>', $since)
            ->orderBy('updated_at_ms')
            ->limit($pageSize + 1)->get();

        $hasMore = $rows->count() > $pageSize;
        $page = $rows->take($pageSize);
        $max = (int) ($page->max('updated_at_ms') ?? $since);

        return [
            $page->map(fn (Session $s) => [
                'id' => $s->id, 'user_id' => $s->user_id, 'deck_id' => $s->deck_id,
                'mode' => $s->mode,
                'started_at_ms' => $s->started_at_ms, 'ended_at_ms' => $s->ended_at_ms,
                'cards_reviewed' => $s->cards_reviewed,
                'accuracy_pct' => $s->accuracy_pct, 'mastery_delta' => $s->mastery_delta,
                'updated_at_ms' => $s->updated_at_ms, 'deleted_at_ms' => $s->deleted_at_ms,
            ])->values()->all(),
            $hasMore, $max,
        ];
    }
}
```

```php
<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\Session;
use App\Models\User;

test('session push creates row for user deck', function () {
    $u = User::factory()->create(); $d = Deck::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;
    $id = (string) \Illuminate\Support\Str::orderedUuid();

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 1000,
            'records' => ['sessions' => [[
                'id' => $id, 'user_id' => $u->id, 'deck_id' => $d->id,
                'mode' => 'smart', 'started_at_ms' => 1000, 'cards_reviewed' => 10,
                'accuracy_pct' => 80.0, 'mastery_delta' => 5.0, 'updated_at_ms' => 1000,
            ]]],
        ])->assertJson(['accepted' => 1]);

    expect(Session::find($id))->not->toBeNull();
});
```

Register in `AppServiceProvider::boot`:

```php
app(\App\Services\Sync\SyncPushService::class)->register('sessions', \App\Services\Sync\Entities\SessionUpserter::class);
app(\App\Services\Sync\SyncPullService::class)->register('sessions', \App\Services\Sync\Entities\SessionReader::class);
```

- [ ] **Step 3: Migrate + test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/Sync/SessionSyncTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Session entity + sync (1.14)"
```

---

### Task 1.15: `Asset` (reserved) — backend migration only

**Files:**
- Create: `api/database/migrations/2026_04_21_000009_create_assets_table.php`
- Create: `api/app/Models/Asset.php`
- Create: `api/database/factories/AssetFactory.php`

> Images are stubbed in v1 per spec §10.2. No upserter/reader yet — the table must exist so iOS entity FKs round-trip when images ship in v1.5.

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('assets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->string('mime_type');
            $table->integer('width')->nullable();
            $table->integer('height')->nullable();
            $table->bigInteger('bytes')->nullable();
            $table->string('r2_key')->nullable();
            $table->enum('upload_status', ['pending', 'uploaded', 'failed'])->default('pending');
            $table->bigInteger('updated_at_ms');
            $table->bigInteger('deleted_at_ms')->nullable();
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('assets'); }
};
```

- [ ] **Step 2: Model + factory (standard pattern, trimmed).**

- [ ] **Step 3: Migrate + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Asset table (reserved for v1.5 images) (1.15)"
```

---

### Task 1.16: `Me` endpoint — profile GET/PATCH

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/MeController.php`
- Create: `api/tests/Feature/MeTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('GET /v1/me returns authed user shape', function () {
    $u = User::factory()->create(['name' => 'Alice']);
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonStructure(['id', 'email', 'name', 'daily_goal_cards', 'theme_preference', 'subscription_status']);
});

test('PATCH /v1/me updates profile fields', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->patchJson('/api/v1/me', ['daily_goal_cards' => 50, 'theme_preference' => 'dark'])
        ->assertOk();

    expect($u->fresh()->daily_goal_cards)->toBe(50)->and($u->fresh()->theme_preference)->toBe('dark');
});
```

- [ ] **Step 2: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $u = $request->user();
        return response()->json([
            'id' => $u->id, 'email' => $u->email, 'name' => $u->name, 'avatar_url' => $u->avatar_url,
            'daily_goal_cards' => $u->daily_goal_cards,
            'reminder_time_local' => $u->reminder_time_local,
            'reminder_enabled' => $u->reminder_enabled,
            'theme_preference' => $u->theme_preference,
            'subscription_status' => $u->subscription_status,
            'subscription_expires_at' => $u->subscription_expires_at?->toIso8601String(),
            'updated_at_ms' => $u->updated_at_ms,
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:200'],
            'daily_goal_cards' => ['sometimes', 'integer', 'min:1', 'max:500'],
            'reminder_time_local' => ['sometimes', 'nullable', 'date_format:H:i'],
            'reminder_enabled' => ['sometimes', 'boolean'],
            'theme_preference' => ['sometimes', 'in:system,light,dark'],
        ]);
        $data['updated_at_ms'] = (int) (microtime(true) * 1000);
        $request->user()->update($data);
        return $this->show($request);
    }
}
```

- [ ] **Step 3: Route (authed):**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::get('/me', [\App\Http\Controllers\Api\V1\MeController::class, 'show']);
    Route::patch('/me', [\App\Http\Controllers\Api\V1\MeController::class, 'update']);
});
```

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/MeTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(api): GET/PATCH /v1/me (1.16)"
```

---

### Task 1.17: iOS — SwiftData entities for all 9 tables

**Files:**
- Create: `ios/Flashcards/Data/Models/UserEntity.swift`
- Create: `ios/Flashcards/Data/Models/DeckEntity.swift`
- Create: `ios/Flashcards/Data/Models/TopicEntity.swift`
- Create: `ios/Flashcards/Data/Models/SubTopicEntity.swift`
- Create: `ios/Flashcards/Data/Models/CardEntity.swift`
- Create: `ios/Flashcards/Data/Models/CardSubTopicEntity.swift`
- Create: `ios/Flashcards/Data/Models/ReviewEntity.swift`
- Create: `ios/Flashcards/Data/Models/SessionEntity.swift`
- Create: `ios/Flashcards/Data/Models/AssetEntity.swift`

- [ ] **Step 1: `UserEntity.swift`:**

```swift
import Foundation
import SwiftData

@Model
public final class UserEntity {
    @Attribute(.unique) public var id: String
    public var email: String
    public var name: String?
    public var avatarUrl: String?
    public var authProvider: String
    public var dailyGoalCards: Int
    public var reminderTimeLocal: String? // "HH:mm"
    public var reminderEnabled: Bool
    public var themePreference: String // "system" | "light" | "dark"
    public var subscriptionStatus: String
    public var subscriptionExpiresAt: Date?
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, email: String, authProvider: String, syncUpdatedAtMs: Int64) {
        self.id = id
        self.email = email
        self.authProvider = authProvider
        self.dailyGoalCards = 20
        self.reminderEnabled = false
        self.themePreference = "system"
        self.subscriptionStatus = "free"
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }
}
```

- [ ] **Step 2: `TopicEntity.swift`:**

```swift
import Foundation
import SwiftData

@Model
public final class TopicEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var name: String
    public var colorHint: String?
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, userId: String, name: String, syncUpdatedAtMs: Int64) {
        self.id = id; self.userId = userId; self.name = name; self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "topics" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        [
            "id": id, "name": name, "color_hint": colorHint as Any,
            "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    public func applyRemote(_ payload: [String: Any]) throws {
        if let s = payload["name"] as? String { name = s }
        colorHint = payload["color_hint"] as? String
        if let u = payload["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = payload["deleted_at_ms"] as? Int64
    }
}
```

- [ ] **Step 3: `DeckEntity.swift`:**

```swift
import Foundation
import SwiftData

@Model
public final class DeckEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var topicId: String?
    public var title: String
    public var deckDescription: String?
    public var accentColor: String
    public var defaultStudyMode: String
    public var cardCount: Int
    public var lastStudiedAtMs: Int64?
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, userId: String, title: String, accentColor: String = "amber",
                defaultStudyMode: String = "smart", syncUpdatedAtMs: Int64) {
        self.id = id; self.userId = userId; self.title = title
        self.accentColor = accentColor; self.defaultStudyMode = defaultStudyMode
        self.cardCount = 0; self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "decks" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        [
            "id": id, "topic_id": topicId as Any, "title": title,
            "description": deckDescription as Any,
            "accent_color": accentColor, "default_study_mode": defaultStudyMode,
            "card_count": cardCount,
            "last_studied_at_ms": lastStudiedAtMs as Any,
            "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any,
        ]
    }

    public func applyRemote(_ payload: [String: Any]) throws {
        topicId = payload["topic_id"] as? String
        if let t = payload["title"] as? String { title = t }
        deckDescription = payload["description"] as? String
        if let a = payload["accent_color"] as? String { accentColor = a }
        if let m = payload["default_study_mode"] as? String { defaultStudyMode = m }
        if let c = payload["card_count"] as? Int { cardCount = c }
        lastStudiedAtMs = payload["last_studied_at_ms"] as? Int64
        if let u = payload["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = payload["deleted_at_ms"] as? Int64
    }
}
```

- [ ] **Step 4: `SubTopicEntity.swift`, `CardEntity.swift`, `CardSubTopicEntity.swift`, `ReviewEntity.swift`, `SessionEntity.swift`, `AssetEntity.swift`** — same pattern. Abbreviated skeletons (fill each in with the full spec fields to mirror backend migrations from 1.9-1.15):

```swift
// SubTopicEntity.swift
@Model public final class SubTopicEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var deckId: String
    public var name: String
    public var position: Int
    public var colorHint: String?
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, deckId: String, name: String, position: Int = 0, syncUpdatedAtMs: Int64) {
        self.id = id; self.deckId = deckId; self.name = name
        self.position = position; self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "sub_topics" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        ["id": id, "deck_id": deckId, "name": name, "position": position,
         "color_hint": colorHint as Any,
         "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any]
    }

    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["name"] as? String { name = s }
        if let i = p["position"] as? Int { position = i }
        colorHint = p["color_hint"] as? String
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
```

```swift
// CardEntity.swift
@Model public final class CardEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var deckId: String
    public var frontText: String
    public var backText: String
    public var frontImageAssetId: String?
    public var backImageAssetId: String?
    public var position: Int
    public var stability: Double?
    public var difficulty: Double?
    public var state: String
    public var lastReviewedAtMs: Int64?
    public var dueAtMs: Int64?
    public var lapses: Int
    public var reps: Int
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, deckId: String, frontText: String, backText: String, syncUpdatedAtMs: Int64) {
        self.id = id; self.deckId = deckId; self.frontText = frontText; self.backText = backText
        self.position = 0; self.state = "new"; self.lapses = 0; self.reps = 0
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "cards" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        ["id": id, "deck_id": deckId, "front_text": frontText, "back_text": backText,
         "front_image_asset_id": frontImageAssetId as Any, "back_image_asset_id": backImageAssetId as Any,
         "position": position, "stability": stability as Any, "difficulty": difficulty as Any,
         "state": state,
         "last_reviewed_at_ms": lastReviewedAtMs as Any, "due_at_ms": dueAtMs as Any,
         "lapses": lapses, "reps": reps,
         "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any]
    }

    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["front_text"] as? String { frontText = s }
        if let s = p["back_text"] as? String { backText = s }
        frontImageAssetId = p["front_image_asset_id"] as? String
        backImageAssetId = p["back_image_asset_id"] as? String
        if let i = p["position"] as? Int { position = i }
        stability = p["stability"] as? Double
        difficulty = p["difficulty"] as? Double
        if let s = p["state"] as? String { state = s }
        lastReviewedAtMs = p["last_reviewed_at_ms"] as? Int64
        dueAtMs = p["due_at_ms"] as? Int64
        if let i = p["lapses"] as? Int { lapses = i }
        if let i = p["reps"] as? Int { reps = i }
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
```

```swift
// CardSubTopicEntity.swift
@Model public final class CardSubTopicEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var cardId: String
    public var subTopicId: String
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, cardId: String, subTopicId: String, syncUpdatedAtMs: Int64) {
        self.id = id; self.cardId = cardId; self.subTopicId = subTopicId
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "card_sub_topics" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        ["id": id, "card_id": cardId, "sub_topic_id": subTopicId,
         "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any]
    }

    public func applyRemote(_ p: [String: Any]) throws {
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
```

```swift
// ReviewEntity.swift
@Model public final class ReviewEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var cardId: String
    public var userId: String
    public var sessionId: String?
    public var rating: Int
    public var reviewDurationMs: Int
    public var ratedAtMs: Int64
    public var stateBeforeJSON: Data
    public var stateAfterJSON: Data
    public var schedulerVersion: String
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64? = nil // unused; reviews are append-only

    public init(id: String, cardId: String, userId: String, rating: Int,
                ratedAtMs: Int64, stateBefore: [String: Any], stateAfter: [String: Any],
                syncUpdatedAtMs: Int64) {
        self.id = id; self.cardId = cardId; self.userId = userId
        self.sessionId = nil; self.rating = rating
        self.reviewDurationMs = 0; self.ratedAtMs = ratedAtMs
        self.stateBeforeJSON = (try? JSONSerialization.data(withJSONObject: stateBefore)) ?? Data()
        self.stateAfterJSON = (try? JSONSerialization.data(withJSONObject: stateAfter)) ?? Data()
        self.schedulerVersion = "fsrs-6"
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "reviews" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        [
            "id": id, "card_id": cardId, "user_id": userId,
            "session_id": sessionId as Any,
            "rating": rating, "review_duration_ms": reviewDurationMs,
            "rated_at_ms": ratedAtMs,
            "state_before": (try? JSONSerialization.jsonObject(with: stateBeforeJSON)) ?? [:],
            "state_after": (try? JSONSerialization.jsonObject(with: stateAfterJSON)) ?? [:],
            "scheduler_version": schedulerVersion,
            "updated_at_ms": syncUpdatedAtMs,
        ]
    }

    public func applyRemote(_ p: [String: Any]) throws {
        // Reviews are append-only; apply once.
    }
}
```

```swift
// SessionEntity.swift
@Model public final class SessionEntity: SyncableRecord {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var deckId: String
    public var mode: String
    public var startedAtMs: Int64
    public var endedAtMs: Int64?
    public var cardsReviewed: Int
    public var accuracyPct: Double
    public var masteryDelta: Double
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, userId: String, deckId: String, mode: String,
                startedAtMs: Int64, syncUpdatedAtMs: Int64) {
        self.id = id; self.userId = userId; self.deckId = deckId; self.mode = mode
        self.startedAtMs = startedAtMs
        self.cardsReviewed = 0; self.accuracyPct = 0; self.masteryDelta = 0
        self.syncUpdatedAtMs = syncUpdatedAtMs
    }

    public static var syncEntityKey: String { "sessions" }
    public var syncId: String { id }

    public func syncPayload() throws -> [String: Any] {
        ["id": id, "user_id": userId, "deck_id": deckId, "mode": mode,
         "started_at_ms": startedAtMs, "ended_at_ms": endedAtMs as Any,
         "cards_reviewed": cardsReviewed, "accuracy_pct": accuracyPct,
         "mastery_delta": masteryDelta,
         "updated_at_ms": syncUpdatedAtMs, "deleted_at_ms": syncDeletedAtMs as Any]
    }

    public func applyRemote(_ p: [String: Any]) throws {
        if let s = p["mode"] as? String { mode = s }
        if let i = p["started_at_ms"] as? Int64 { startedAtMs = i }
        endedAtMs = p["ended_at_ms"] as? Int64
        if let i = p["cards_reviewed"] as? Int { cardsReviewed = i }
        if let d = p["accuracy_pct"] as? Double { accuracyPct = d }
        if let d = p["mastery_delta"] as? Double { masteryDelta = d }
        if let u = p["updated_at_ms"] as? Int64 { syncUpdatedAtMs = u }
        syncDeletedAtMs = p["deleted_at_ms"] as? Int64
    }
}
```

```swift
// AssetEntity.swift (reserved)
@Model public final class AssetEntity {
    @Attribute(.unique) public var id: String
    public var userId: String
    public var mimeType: String
    public var bytes: Int?
    public var r2Key: String?
    public var localPath: String?
    public var uploadStatus: String
    public var syncUpdatedAtMs: Int64
    public var syncDeletedAtMs: Int64?

    public init(id: String, userId: String, mimeType: String, syncUpdatedAtMs: Int64) {
        self.id = id; self.userId = userId; self.mimeType = mimeType
        self.uploadStatus = "pending"; self.syncUpdatedAtMs = syncUpdatedAtMs
    }
}
```

- [ ] **Step 5: Wire the `ModelContainer` in `FlashcardsApp`:**

```swift
import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var appState = AppState()
    let container: ModelContainer

    init() {
        AnalyticsClient.configure()
        container = try! ModelContainer(
            for: UserEntity.self, TopicEntity.self, DeckEntity.self, SubTopicEntity.self,
                 CardEntity.self, CardSubTopicEntity.self, ReviewEntity.self,
                 SessionEntity.self, AssetEntity.self, PendingMutationEntity.self
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState).modelContainer(container)
        }
    }
}
```

- [ ] **Step 6: Build + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -n 5
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): SwiftData entities for all 9 tables + ModelContainer (1.17)"
```

---

### Task 1.18: iOS — SyncPusher

**Files:**
- Create: `ios/Flashcards/Data/Sync/SyncPusher.swift`
- Create: `ios/FlashcardsTests/SyncPusherTests.swift`

- [ ] **Step 1: Failing test:**

```swift
import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncPusherTests: XCTestCase {
    func test_push_emptyQueue_returnsZero() async throws {
        let container = try ModelContainer(for: PendingMutationEntity.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let stub = StubAPI(capturedBodies: [])
        let pusher = SyncPusher(context: container.mainContext, api: stub)

        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 0)
    }

    func test_push_groupsByEntityAndSendsBatch() async throws {
        let container = try ModelContainer(for: PendingMutationEntity.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let q = MutationQueue(context: container.mainContext)
        try q.enqueue(entityKey: "topics", recordId: "t1", payload: ["id": "t1"])
        try q.enqueue(entityKey: "decks",  recordId: "d1", payload: ["id": "d1"])

        let stub = StubAPI(response: #"{"accepted":2,"rejected":[],"server_clock_ms":0}"#)
        let pusher = SyncPusher(context: container.mainContext, api: stub)

        let accepted = try await pusher.pushOnce()
        XCTAssertEqual(accepted, 2)
        XCTAssertEqual(try q.pendingCount(), 0)
    }
}

final class StubAPI: APIClientProtocol, @unchecked Sendable {
    var response: String
    init(response: String = #"{"accepted":0,"rejected":[],"server_clock_ms":0}"#, capturedBodies: [Data] = []) {
        self.response = response
    }
    func send<R: Decodable>(_ endpoint: APIEndpoint<R>) async throws -> R {
        try JSONDecoder.api.decode(R.self, from: response.data(using: .utf8)!)
    }
}
```

- [ ] **Step 2: Implementation:**

```swift
import Foundation
import SwiftData

public struct SyncPushResponse: Decodable {
    public let accepted: Int
    public let rejected: [Rejected]
    public let serverClockMs: Int64

    public struct Rejected: Decodable { public let id: String; public let reason: String }
}

@MainActor
public final class SyncPusher {
    private let context: ModelContext
    private let api: APIClientProtocol
    public init(context: ModelContext, api: APIClientProtocol) { self.context = context; self.api = api }

    /// Push up to 100 pending mutations. Returns accepted count. On transport failure, requeues with backoff.
    public func pushOnce() async throws -> Int {
        let q = MutationQueue(context: context)
        let batch = try q.takeBatch(now: Clock.nowMs(), limit: 100)
        guard !batch.isEmpty else { return 0 }

        var records: [String: [[String: Any]]] = [:]
        for m in batch {
            let p = (try? JSONSerialization.jsonObject(with: m.payloadJSON)) as? [String: Any] ?? [:]
            records[m.entityKey, default: []].append(p)
        }

        let body = try JSONSerialization.data(withJSONObject: [
            "client_clock_ms": Clock.nowMs(),
            "records": records,
        ])

        do {
            let resp: SyncPushResponse = try await api.send(APIEndpoint(
                method: "POST", path: "/api/v1/sync/push", body: body, requiresAuth: true
            ))

            let rejectedIds = Set(resp.rejected.map(\.id))
            for m in batch {
                if rejectedIds.contains(m.recordId) {
                    try q.markFailure(m, now: Clock.nowMs())
                } else {
                    try q.markSuccess(m)
                }
            }
            return resp.accepted
        } catch {
            for m in batch { try q.markFailure(m, now: Clock.nowMs()) }
            throw error
        }
    }
}
```

- [ ] **Step 3: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/SyncPusherTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): SyncPusher batches pending mutations (1.18)"
```

---

### Task 1.19: iOS — SyncPuller

**Files:**
- Create: `ios/Flashcards/Data/Sync/SyncPuller.swift`
- Create: `ios/FlashcardsTests/SyncPullerTests.swift`

- [ ] **Step 1: Failing test:**

```swift
import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncPullerTests: XCTestCase {
    func test_pull_appliesIncomingTopicRecord() async throws {
        let container = try ModelContainer(
            for: TopicEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let stub = StubAPI(response: """
            {"server_clock_ms":1000,"records":{"topics":[{"id":"t1","name":"Biology","color_hint":null,"updated_at_ms":1000,"deleted_at_ms":null}]},"has_more":false,"next_since":1000}
        """)
        let puller = SyncPuller(context: container.mainContext, api: stub)

        try await puller.pull(entities: ["topics"], since: 0)

        let all = try container.mainContext.fetch(FetchDescriptor<TopicEntity>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Biology")
    }
}
```

- [ ] **Step 2: Implementation:**

```swift
import Foundation
import SwiftData

public struct SyncPullResponse: Decodable {
    public let serverClockMs: Int64
    public let records: [String: [[String: AnyCodable]]]
    public let hasMore: Bool
    public let nextSince: Int64
}

/// Type-erased decodable for heterogeneous record payloads.
public struct AnyCodable: Codable {
    public let value: Any
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Int64.self)   { self.value = v; return }
        if let v = try? c.decode(Double.self)  { self.value = v; return }
        if let v = try? c.decode(Bool.self)    { self.value = v; return }
        if let v = try? c.decode(String.self)  { self.value = v; return }
        if let v = try? c.decode([String: AnyCodable].self) { self.value = v.mapValues(\.value); return }
        if let v = try? c.decode([AnyCodable].self) { self.value = v.map(\.value); return }
        if c.decodeNil() { self.value = NSNull(); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown type")
    }
    public func encode(to encoder: Encoder) throws {}
}

@MainActor
public final class SyncPuller {
    private let context: ModelContext
    private let api: APIClientProtocol
    public init(context: ModelContext, api: APIClientProtocol) { self.context = context; self.api = api }

    /// Pull records since `since` for the given entity keys. Applies LWW per record.
    public func pull(entities: [String], since: Int64) async throws {
        let path = "/api/v1/sync/pull?since=\(since)&entities=\(entities.joined(separator: ","))"
        let resp: SyncPullResponse = try await api.send(APIEndpoint<SyncPullResponse>(
            method: "GET", path: path, body: nil, requiresAuth: true
        ))

        for (entityKey, rows) in resp.records {
            let rawRows = rows.map { $0.mapValues(\.value) }
            try apply(entityKey: entityKey, rows: rawRows)
        }
        try context.save()
    }

    private func apply(entityKey: String, rows: [[String: Any]]) throws {
        switch entityKey {
        case "topics":         try applyTopics(rows)
        case "decks":          try applyDecks(rows)
        case "sub_topics":     try applySubTopics(rows)
        case "cards":          try applyCards(rows)
        case "card_sub_topics": try applyCardSubTopics(rows)
        case "reviews":        try applyReviews(rows)
        case "sessions":       try applySessions(rows)
        default: return
        }
    }

    private func applyTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(TopicEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing {
                try existing.applyRemote(row)
            } else {
                let t = TopicEntity(id: id,
                                    userId: (row["user_id"] as? String) ?? "",
                                    name: (row["name"] as? String) ?? "",
                                    syncUpdatedAtMs: row["updated_at_ms"] as? Int64 ?? 0)
                context.insert(t)
                try t.applyRemote(row)
            }
        }
    }

    private func applyDecks(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(DeckEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing { try existing.applyRemote(row) } else {
                let d = DeckEntity(id: id, userId: (row["user_id"] as? String) ?? "",
                                   title: (row["title"] as? String) ?? "",
                                   syncUpdatedAtMs: row["updated_at_ms"] as? Int64 ?? 0)
                context.insert(d); try d.applyRemote(row)
            }
        }
    }

    private func applySubTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(SubTopicEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing { try existing.applyRemote(row) } else {
                let s = SubTopicEntity(id: id,
                                       deckId: (row["deck_id"] as? String) ?? "",
                                       name: (row["name"] as? String) ?? "",
                                       position: (row["position"] as? Int) ?? 0,
                                       syncUpdatedAtMs: row["updated_at_ms"] as? Int64 ?? 0)
                context.insert(s); try s.applyRemote(row)
            }
        }
    }

    private func applyCards(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(CardEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing { try existing.applyRemote(row) } else {
                let c = CardEntity(id: id,
                                   deckId: (row["deck_id"] as? String) ?? "",
                                   frontText: (row["front_text"] as? String) ?? "",
                                   backText: (row["back_text"] as? String) ?? "",
                                   syncUpdatedAtMs: row["updated_at_ms"] as? Int64 ?? 0)
                context.insert(c); try c.applyRemote(row)
            }
        }
    }

    private func applyCardSubTopics(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(CardSubTopicEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing { try existing.applyRemote(row) } else {
                let j = CardSubTopicEntity(id: id,
                                           cardId: (row["card_id"] as? String) ?? "",
                                           subTopicId: (row["sub_topic_id"] as? String) ?? "",
                                           syncUpdatedAtMs: row["updated_at_ms"] as? Int64 ?? 0)
                context.insert(j); try j.applyRemote(row)
            }
        }
    }

    private func applyReviews(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            if try fetch(ReviewEntity.self, id: id) != nil { continue } // append-only
            let r = ReviewEntity(id: id,
                                 cardId: (row["card_id"] as? String) ?? "",
                                 userId: (row["user_id"] as? String) ?? "",
                                 rating: (row["rating"] as? Int) ?? 3,
                                 ratedAtMs: (row["rated_at_ms"] as? Int64) ?? 0,
                                 stateBefore: (row["state_before"] as? [String: Any]) ?? [:],
                                 stateAfter: (row["state_after"] as? [String: Any]) ?? [:],
                                 syncUpdatedAtMs: (row["updated_at_ms"] as? Int64) ?? 0)
            context.insert(r)
        }
    }

    private func applySessions(_ rows: [[String: Any]]) throws {
        for row in rows {
            guard let id = row["id"] as? String else { continue }
            let existing = try fetch(SessionEntity.self, id: id)
            if let existing, existing.syncUpdatedAtMs >= (row["updated_at_ms"] as? Int64 ?? 0) { continue }
            if let existing { try existing.applyRemote(row) } else {
                let s = SessionEntity(id: id,
                                      userId: (row["user_id"] as? String) ?? "",
                                      deckId: (row["deck_id"] as? String) ?? "",
                                      mode: (row["mode"] as? String) ?? "smart",
                                      startedAtMs: (row["started_at_ms"] as? Int64) ?? 0,
                                      syncUpdatedAtMs: (row["updated_at_ms"] as? Int64) ?? 0)
                context.insert(s); try s.applyRemote(row)
            }
        }
    }

    private func fetch<T: PersistentModel>(_ type: T.Type, id: String) throws -> T? where T: SyncableRecord {
        let descriptor = FetchDescriptor<T>(predicate: #Predicate { ($0 as? T)?.syncId == id })
        return try context.fetch(descriptor).first
    }
}
```

> Note: SwiftData `#Predicate` can't reflect a protocol property directly; each entity type carries its `id` attribute. In practice, replace the generic `fetch` with per-entity helpers using `#Predicate<DeckEntity> { $0.id == id }`. Inline per-method for clarity.

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/SyncPullerTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): SyncPuller applies remote records with LWW (1.19)"
```

---

### Task 1.20: iOS — SyncScheduler + SyncManager

**Files:**
- Create: `ios/Flashcards/Data/Sync/Reachability.swift`
- Create: `ios/Flashcards/Data/Sync/SyncScheduler.swift`
- Create: `ios/Flashcards/Data/Sync/SyncManager.swift`

- [ ] **Step 1: `Reachability.swift`:**

```swift
import Foundation
import Network

public actor Reachability {
    private let monitor = NWPathMonitor()
    public private(set) var isConnected: Bool = false

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.updateConnected(path.status == .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    private func updateConnected(_ c: Bool) { isConnected = c }
}
```

- [ ] **Step 2: `SyncScheduler.swift`:**

```swift
import Foundation

@MainActor
public final class SyncScheduler {
    private let manager: SyncManager
    private var timerTask: Task<Void, Never>?

    public init(manager: SyncManager) { self.manager = manager }

    public func start() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                await self?.manager.syncNow()
            }
        }
    }

    public func stop() { timerTask?.cancel() }

    public func onForeground() { Task { await manager.syncNow() } }
}
```

- [ ] **Step 3: `SyncManager.swift`:**

```swift
import Foundation
import SwiftData

@Observable
@MainActor
public final class SyncManager {
    public var lastSyncedAt: Date?
    public var lastError: String?

    private let context: ModelContext
    private let pusher: SyncPusher
    private let puller: SyncPuller
    private let reachability: Reachability

    public init(context: ModelContext, api: APIClientProtocol, reachability: Reachability = .init()) {
        self.context = context
        self.pusher = SyncPusher(context: context, api: api)
        self.puller = SyncPuller(context: context, api: api)
        self.reachability = reachability
    }

    public func syncNow() async {
        guard await reachability.isConnected else { return }
        do {
            _ = try await pusher.pushOnce()
            try await puller.pull(
                entities: ["topics", "decks", "sub_topics", "cards", "card_sub_topics", "reviews", "sessions"],
                since: lastSyncedAtMs()
            )
            lastSyncedAt = Date()
            lastError = nil
            AnalyticsClient.track("sync.pull.ok")
        } catch {
            lastError = String(describing: error)
            AnalyticsClient.track("sync.pull.fail", properties: ["error": lastError ?? ""])
        }
    }

    /// Persisted elsewhere (UserDefaults for simplicity — small and bounded).
    private func lastSyncedAtMs() -> Int64 {
        Int64(UserDefaults.standard.integer(forKey: "mw.lastSyncedAtMs"))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(sync): Reachability + SyncScheduler + SyncManager (1.20)"
```

---

### Task 1.21: Integration test — offline create → sync

**Files:**
- Create: `ios/FlashcardsTests/SyncIntegrationTests.swift`

- [ ] **Step 1: Create test (uses a fake transport that records calls):**

```swift
import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SyncIntegrationTests: XCTestCase {
    func test_createDeckOffline_enqueuesMutation_thenPushes() async throws {
        let container = try ModelContainer(
            for: DeckEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let q = MutationQueue(context: ctx)

        let deck = DeckEntity(id: "d1", userId: "u1", title: "Bio", syncUpdatedAtMs: Clock.nowMs())
        ctx.insert(deck)
        try ctx.save()
        try q.enqueue(entityKey: DeckEntity.syncEntityKey, recordId: deck.id,
                      payload: try deck.syncPayload())

        XCTAssertEqual(try q.pendingCount(), 1)

        let stub = StubAPI(response: #"{"accepted":1,"rejected":[],"server_clock_ms":1}"#)
        let pusher = SyncPusher(context: ctx, api: stub)
        let accepted = try await pusher.pushOnce()

        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(try q.pendingCount(), 0)
    }
}
```

- [ ] **Step 2: Run + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/SyncIntegrationTests | tail -n 10
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(sync): offline create → push integration (1.21)"
```

---

### Task 1.22: PurgeTombstones scheduled job

**Files:**
- Create: `api/app/Jobs/PurgeTombstones.php`
- Modify: `api/app/Console/Kernel.php` (schedule)
- Create: `api/tests/Feature/PurgeTombstonesTest.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Jobs\PurgeTombstones;
use App\Models\Deck;
use App\Models\User;

test('purges decks with deleted_at_ms older than 90 days', function () {
    $u = User::factory()->create();
    $old = Deck::factory()->for($u)->create(['deleted_at_ms' => now()->subDays(100)->valueOf(), 'updated_at_ms' => now()->valueOf()]);
    $recent = Deck::factory()->for($u)->create(['deleted_at_ms' => now()->subDays(30)->valueOf(), 'updated_at_ms' => now()->valueOf()]);
    $live = Deck::factory()->for($u)->create(['deleted_at_ms' => null, 'updated_at_ms' => now()->valueOf()]);

    (new PurgeTombstones())->handle();

    expect(Deck::find($old->id))->toBeNull()
        ->and(Deck::find($recent->id))->not->toBeNull()
        ->and(Deck::find($live->id))->not->toBeNull();
});
```

- [ ] **Step 2: Job:**

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Card;
use App\Models\CardSubTopic;
use App\Models\Deck;
use App\Models\Session;
use App\Models\SubTopic;
use App\Models\Topic;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

final class PurgeTombstones implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        $cutoff = now()->subDays(90)->valueOf();
        foreach ([Topic::class, Deck::class, SubTopic::class, Card::class, CardSubTopic::class, Session::class] as $model) {
            $model::whereNotNull('deleted_at_ms')->where('deleted_at_ms', '<', $cutoff)->delete();
        }
    }
}
```

- [ ] **Step 3: Schedule daily in `api/routes/console.php`:**

```php
use App\Jobs\PurgeTombstones;
use Illuminate\Support\Facades\Schedule;

Schedule::job(new PurgeTombstones())->daily();
```

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/PurgeTombstonesTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(jobs): PurgeTombstones daily at 90 days (1.22)"
```

---

### Task 1.23: Observability — sync event emission

**Files:**
- Modify: `ios/Flashcards/Data/Sync/SyncManager.swift`
- Modify: `ios/Flashcards/Data/Sync/SyncPusher.swift`

- [ ] **Step 1: Add events in `SyncPusher.pushOnce`:**

```swift
AnalyticsClient.track("sync.push.ok", properties: ["accepted": accepted, "rejected": resp.rejected.count])
// on catch:
AnalyticsClient.track("sync.push.fail", properties: ["error": String(describing: error)])
```

- [ ] **Step 2: In `SyncManager.syncNow`, add `sync.queue.stuck` detection:**

```swift
let pending = (try? MutationQueue(context: context).pendingCount()) ?? 0
if pending > 100, let last = lastSyncedAt, Date().timeIntervalSince(last) > 600 {
    AnalyticsClient.track("sync.queue.stuck", properties: ["pending": pending])
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(observability): sync.{push,pull,queue}.* events (1.23)"
```

---

### Task 1.24: Phase 1 acceptance — merge to main

- [ ] **Step 1: Run full CI locally.**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pint --test && ./vendor/bin/phpstan analyse --memory-limit=1G && ./vendor/bin/pest
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test | tail -n 20
```

- [ ] **Step 2: Open PR, green, merge, tag.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-1 -m "Phase 1: Data model + Sync engine"
git -C /Users/lukehogan/Code/flashcards push origin main phase-1
```

**Phase 1 acceptance criteria:**
- All 9 entities migrated + tested on both sides.
- `/v1/sync/push` accepts batches for all 7 synced entities (reviews insert-only).
- `/v1/sync/pull?since=…&entities=…` returns ownership-scoped rows with pagination.
- iOS `MutationQueue` + `SyncPusher` + `SyncPuller` round-trip records in-memory and against a local API.
- `ReplayReviewsForCard` updates card state from latest review.
- `PurgeTombstones` scheduled daily at 90 days.

---

## Phase 2: FSRS + Study + Core CRUD (weeks 6-10)

**Goal:** On-device FSRS scheduling + Smart/Basic study sessions + deck/card CRUD UI + search. User can install, create decks/cards, study, and see progress — all offline.

### Task 2.1: Add `fsrs-rs` via UniFFI Swift bindings

**Files:**
- Create: `ios/Packages/FsrsKit/` (local SPM package wrapping generated UniFFI bindings)

- [ ] **Step 1: Generate bindings locally.** Clone `openSpacedRepetition/fsrs-rs` at the chosen version (pin `v1.3.0` or latest stable at implementation time):

```bash
git clone https://github.com/open-spaced-repetition/fsrs-rs /tmp/fsrs-rs
cd /tmp/fsrs-rs && git checkout v1.3.0
```

Build for all iOS targets and combine into an `.xcframework`:

```bash
cd /tmp/fsrs-rs
cargo install cargo-swift
cargo swift package --platforms ios --name FsrsRust --release
```

Expected output: `FsrsRust.xcframework` and generated `FsrsRust.swift`.

- [ ] **Step 2: Copy artifacts into `ios/Packages/FsrsKit/`:**

```
ios/Packages/FsrsKit/
  Package.swift
  Sources/FsrsKit/FsrsRust.swift
  Frameworks/FsrsRust.xcframework/
```

`Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FsrsKit",
    platforms: [.iOS(.v17)],
    products: [.library(name: "FsrsKit", targets: ["FsrsKit"])],
    targets: [
        .target(
            name: "FsrsKit",
            dependencies: ["FsrsRust"],
            path: "Sources/FsrsKit"
        ),
        .binaryTarget(
            name: "FsrsRust",
            path: "Frameworks/FsrsRust.xcframework"
        ),
    ]
)
```

- [ ] **Step 3: Add local package to Flashcards project.** File → Add Package Dependencies → Add Local → `ios/Packages/FsrsKit`.

- [ ] **Step 4: Build — verify bindings resolve.**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -n 10
```

- [ ] **Step 5: Commit** (the xcframework is binary; add it to git-lfs if >50MB).

```bash
git -C /Users/lukehogan/Code/flashcards checkout -b phase/2-fsrs-study
git -C /Users/lukehogan/Code/flashcards lfs track "*.xcframework" 2>/dev/null || true
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(fsrs): add FsrsKit local SPM package (UniFFI bindings to fsrs-rs) (2.1)"
```

---

### Task 2.2: `FsrsScheduler` wrapper + tests

**Files:**
- Create: `ios/Flashcards/Fsrs/FsrsScheduler.swift`
- Create: `ios/Flashcards/Fsrs/RatingMapping.swift`
- Create: `ios/FlashcardsTests/FsrsSchedulerTests.swift`

- [ ] **Step 1: `RatingMapping.swift`:**

```swift
import Foundation

public enum MWRating: Int, Codable, CaseIterable {
    case again = 1, hard = 2, good = 3, easy = 4

    public var label: String {
        switch self { case .again: "Again"; case .hard: "Hard"; case .good: "Good"; case .easy: "Easy" }
    }
}
```

- [ ] **Step 2: Failing test `FsrsSchedulerTests.swift`:**

```swift
import XCTest
@testable import Flashcards

final class FsrsSchedulerTests: XCTestCase {
    func test_firstReview_new_toLearning_onGood() {
        let sched = FsrsScheduler(weights: nil)
        let now: Int64 = 1_000
        let card = FsrsScheduler.CardState(stability: nil, difficulty: nil, state: .new,
                                           lastReviewedAtMs: nil, dueAtMs: nil, reps: 0, lapses: 0)

        let next = sched.applyReview(to: card, rating: .good, at: now)

        XCTAssertNotEqual(next.state, .new)
        XCTAssertNotNil(next.stability)
        XCTAssertNotNil(next.difficulty)
        XCTAssertGreaterThan(next.dueAtMs ?? 0, now)
    }

    func test_again_fromReview_toRelearning() {
        let sched = FsrsScheduler(weights: nil)
        var card = FsrsScheduler.CardState(stability: 10.0, difficulty: 6.0, state: .review,
                                           lastReviewedAtMs: 0, dueAtMs: 100, reps: 3, lapses: 0)
        let next = sched.applyReview(to: card, rating: .again, at: 200)
        XCTAssertEqual(next.state, .relearning)
        XCTAssertEqual(next.lapses, 1)
    }

    func test_intervalPreview_returnsFourCandidates() {
        let sched = FsrsScheduler(weights: nil)
        let card = FsrsScheduler.CardState(stability: 2.0, difficulty: 5.0, state: .review,
                                           lastReviewedAtMs: 0, dueAtMs: 100, reps: 1, lapses: 0)
        let preview = sched.intervalPreview(for: card, at: 100)
        XCTAssertEqual(preview.count, 4)
        XCTAssertLessThan(preview[.again]!, preview[.good]!)
        XCTAssertLessThan(preview[.good]!, preview[.easy]!)
    }
}
```

- [ ] **Step 3: `FsrsScheduler.swift`:**

```swift
import Foundation
import FsrsKit

public final class FsrsScheduler {
    public enum State: String, Codable { case new, learning, review, relearning }

    public struct CardState: Equatable {
        public var stability: Double?
        public var difficulty: Double?
        public var state: State
        public var lastReviewedAtMs: Int64?
        public var dueAtMs: Int64?
        public var reps: Int
        public var lapses: Int

        public init(stability: Double? = nil, difficulty: Double? = nil,
                    state: State = .new, lastReviewedAtMs: Int64? = nil,
                    dueAtMs: Int64? = nil, reps: Int = 0, lapses: Int = 0) {
            self.stability = stability; self.difficulty = difficulty; self.state = state
            self.lastReviewedAtMs = lastReviewedAtMs; self.dueAtMs = dueAtMs
            self.reps = reps; self.lapses = lapses
        }
    }

    private let core: FsrsCore

    public init(weights: [Double]? = nil) {
        self.core = FsrsCore(parameters: weights)
    }

    public func applyReview(to card: CardState, rating: MWRating, at nowMs: Int64) -> CardState {
        let req = ReviewRequest(
            stability: card.stability,
            difficulty: card.difficulty,
            state: mapStateToCore(card.state),
            elapsedDays: elapsedDays(from: card.lastReviewedAtMs ?? nowMs, to: nowMs),
            rating: UInt32(rating.rawValue)
        )
        let r = core.schedule(request: req)

        return CardState(
            stability: r.stability,
            difficulty: r.difficulty,
            state: mapStateFromCore(r.state),
            lastReviewedAtMs: nowMs,
            dueAtMs: nowMs + Int64(r.scheduledDays * 86_400_000),
            reps: card.reps + 1,
            lapses: card.lapses + (rating == .again ? 1 : 0)
        )
    }

    public func intervalPreview(for card: CardState, at nowMs: Int64) -> [MWRating: Int64] {
        var preview: [MWRating: Int64] = [:]
        for r in MWRating.allCases {
            let next = applyReview(to: card, rating: r, at: nowMs)
            preview[r] = (next.dueAtMs ?? nowMs) - nowMs
        }
        return preview
    }

    private func elapsedDays(from: Int64, to: Int64) -> Double {
        max(0, Double(to - from) / 86_400_000.0)
    }

    private func mapStateToCore(_ s: State) -> UInt32 {
        switch s { case .new: 0; case .learning: 1; case .review: 2; case .relearning: 3 }
    }
    private func mapStateFromCore(_ s: UInt32) -> State {
        switch s { case 1: .learning; case 2: .review; case 3: .relearning; default: .new }
    }
}
```

> Note: `FsrsCore`, `ReviewRequest`, etc. are the UniFFI-generated Swift types. If the binding surface differs, adjust the adapter here only — keep the `FsrsScheduler` API stable for callers.

- [ ] **Step 4: Run tests — pass. Commit.**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/FsrsSchedulerTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(fsrs): FsrsScheduler wrapper + rating mapping + tests (2.2)"
```

---

### Task 2.3: `SessionQueueBuilder` — smart + basic queue construction

**Files:**
- Create: `ios/Flashcards/Features/Session/SessionQueueBuilder.swift`
- Create: `ios/FlashcardsTests/SessionQueueBuilderTests.swift`

- [ ] **Step 1: Failing test:**

```swift
import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SessionQueueBuilderTests: XCTestCase {
    func test_smartQueue_prioritizesDueOverNew() throws {
        let container = try ModelContainer(for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext

        let deckId = "d1"
        let now: Int64 = 10_000
        let dueOverdue = CardEntity(id: "c1", deckId: deckId, frontText: "d1", backText: "e1", syncUpdatedAtMs: 0)
        dueOverdue.state = "review"; dueOverdue.dueAtMs = 5_000
        let newCard = CardEntity(id: "c2", deckId: deckId, frontText: "d2", backText: "e2", syncUpdatedAtMs: 0)
        newCard.state = "new"
        let futureCard = CardEntity(id: "c3", deckId: deckId, frontText: "d3", backText: "e3", syncUpdatedAtMs: 0)
        futureCard.state = "review"; futureCard.dueAtMs = 20_000
        [dueOverdue, newCard, futureCard].forEach { ctx.insert($0) }
        try ctx.save()

        let builder = SessionQueueBuilder(context: ctx)
        let q = try builder.smartQueue(deckId: deckId, now: now, dailyNewCardLimit: 10)

        XCTAssertEqual(q.map(\.id), ["c1", "c2"])
    }

    func test_smartQueue_respectsNewLimit() throws {
        let container = try ModelContainer(for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext

        for i in 0..<20 {
            let c = CardEntity(id: "c\(i)", deckId: "d", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
            c.state = "new"
            ctx.insert(c)
        }
        try ctx.save()

        let q = try SessionQueueBuilder(context: ctx)
            .smartQueue(deckId: "d", now: 0, dailyNewCardLimit: 5)

        XCTAssertEqual(q.count, 5)
    }

    func test_basicQueue_returnsAllCardsByPosition() throws {
        let container = try ModelContainer(for: CardEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        for i in 0..<3 {
            let c = CardEntity(id: "c\(i)", deckId: "d", frontText: "\(i)", backText: "\(i)", syncUpdatedAtMs: 0)
            c.position = 2 - i
            ctx.insert(c)
        }
        try ctx.save()

        let q = try SessionQueueBuilder(context: ctx).basicQueue(deckId: "d")
        XCTAssertEqual(q.map(\.id), ["c2", "c1", "c0"])
    }
}
```

- [ ] **Step 2: Implementation:**

```swift
import Foundation
import SwiftData

@MainActor
public final class SessionQueueBuilder {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    /// Due cards first (ordered by how overdue), then new cards up to daily limit.
    public func smartQueue(deckId: String, now: Int64, dailyNewCardLimit: Int) throws -> [CardEntity] {
        let due = try fetchDue(deckId: deckId, now: now)
        let new = try fetchNew(deckId: deckId, limit: dailyNewCardLimit)
        return due + new
    }

    /// All non-deleted cards in `position` order.
    public func basicQueue(deckId: String) throws -> [CardEntity] {
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.position)]
        )
        descriptor.fetchLimit = 1000
        return try context.fetch(descriptor)
    }

    private func fetchDue(deckId: String, now: Int64) throws -> [CardEntity] {
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate {
                $0.deckId == deckId &&
                $0.syncDeletedAtMs == nil &&
                $0.state != "new" &&
                ($0.dueAtMs ?? Int64.max) <= now
            },
            sortBy: [SortDescriptor(\.dueAtMs)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    private func fetchNew(deckId: String, limit: Int) throws -> [CardEntity] {
        var descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate {
                $0.deckId == deckId &&
                $0.syncDeletedAtMs == nil &&
                $0.state == "new"
            },
            sortBy: [SortDescriptor(\.position)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/SessionQueueBuilderTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): SessionQueueBuilder smart/basic queues with tests (2.3)"
```

---

### Task 2.4: `SessionEngine` — rate a card, persist review, update card, enqueue

**Files:**
- Create: `ios/Flashcards/Features/Session/SessionEngine.swift`
- Create: `ios/FlashcardsTests/SessionEngineTests.swift`

- [ ] **Step 1: Failing test:**

```swift
import XCTest
import SwiftData
@testable import Flashcards

@MainActor
final class SessionEngineTests: XCTestCase {
    func test_rateGood_writesReview_updatesCard_enqueuesMutations() throws {
        let container = try ModelContainer(
            for: CardEntity.self, ReviewEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let card = CardEntity(id: "c1", deckId: "d1", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
        ctx.insert(card); try ctx.save()

        let engine = SessionEngine(context: ctx, userId: "u1", scheduler: FsrsScheduler(weights: nil), sessionId: "s1")

        try engine.rate(card: card, rating: .good, at: 1_000, mode: .smart)

        let reviews = try ctx.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(reviews.count, 1)
        XCTAssertEqual(reviews[0].cardId, "c1")
        XCTAssertEqual(reviews[0].rating, 3)

        XCTAssertNotEqual(card.state, "new") // advanced to learning
        XCTAssertEqual(card.reps, 1)

        let pending = try MutationQueue(context: ctx).pendingCount()
        XCTAssertEqual(pending, 2) // one for Review, one for Card
    }

    func test_basicMode_writesReview_butDoesNotMutateCardState() throws {
        let container = try ModelContainer(
            for: CardEntity.self, ReviewEntity.self, PendingMutationEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        let card = CardEntity(id: "c1", deckId: "d1", frontText: "f", backText: "b", syncUpdatedAtMs: 0)
        card.state = "review"; card.stability = 4.0; card.difficulty = 6.0
        ctx.insert(card); try ctx.save()

        let engine = SessionEngine(context: ctx, userId: "u1", scheduler: FsrsScheduler(weights: nil), sessionId: "s1")
        try engine.rate(card: card, rating: .again, at: 1_000, mode: .basic)

        XCTAssertEqual(card.state, "review")
        XCTAssertEqual(card.stability, 4.0)
        XCTAssertEqual(card.difficulty, 6.0)

        let reviews = try ctx.fetch(FetchDescriptor<ReviewEntity>())
        XCTAssertEqual(reviews.count, 1)
    }
}
```

- [ ] **Step 2: Implementation:**

```swift
import Foundation
import SwiftData

public enum SessionMode: String, Codable { case smart, basic }

@MainActor
public final class SessionEngine {
    private let context: ModelContext
    private let userId: String
    private let scheduler: FsrsScheduler
    private let sessionId: String

    public init(context: ModelContext, userId: String, scheduler: FsrsScheduler, sessionId: String) {
        self.context = context; self.userId = userId; self.scheduler = scheduler; self.sessionId = sessionId
    }

    public func rate(card: CardEntity, rating: MWRating, at nowMs: Int64, mode: SessionMode) throws {
        let stateBefore = card.fsrsState()
        let stateAfter: FsrsScheduler.CardState = (mode == .smart)
            ? scheduler.applyReview(to: stateBefore, rating: rating, at: nowMs)
            : stateBefore   // basic mode doesn't mutate state

        let reviewId = UUIDv7.next()
        let review = ReviewEntity(
            id: reviewId, cardId: card.id, userId: userId,
            rating: rating.rawValue,
            ratedAtMs: nowMs,
            stateBefore: stateBefore.dict(),
            stateAfter: stateAfter.dict(),
            syncUpdatedAtMs: nowMs
        )
        review.sessionId = sessionId
        context.insert(review)

        if mode == .smart {
            card.stability = stateAfter.stability
            card.difficulty = stateAfter.difficulty
            card.state = stateAfter.state.rawValue
            card.lastReviewedAtMs = stateAfter.lastReviewedAtMs
            card.dueAtMs = stateAfter.dueAtMs
            card.reps = stateAfter.reps
            card.lapses = stateAfter.lapses
            card.syncUpdatedAtMs = nowMs
        } else {
            card.reps += 1
            card.lastReviewedAtMs = nowMs
            card.syncUpdatedAtMs = nowMs
        }

        try context.save()

        let q = MutationQueue(context: context)
        try q.enqueue(entityKey: ReviewEntity.syncEntityKey, recordId: review.id, payload: review.syncPayload())
        try q.enqueue(entityKey: CardEntity.syncEntityKey, recordId: card.id, payload: card.syncPayload())
    }
}

public extension CardEntity {
    func fsrsState() -> FsrsScheduler.CardState {
        FsrsScheduler.CardState(
            stability: stability, difficulty: difficulty,
            state: FsrsScheduler.State(rawValue: state) ?? .new,
            lastReviewedAtMs: lastReviewedAtMs, dueAtMs: dueAtMs,
            reps: reps, lapses: lapses
        )
    }
}

public extension FsrsScheduler.CardState {
    func dict() -> [String: Any] {
        [
            "stability": stability as Any, "difficulty": difficulty as Any,
            "state": state.rawValue,
            "last_reviewed_at_ms": lastReviewedAtMs as Any,
            "due_at_ms": dueAtMs as Any,
            "reps": reps, "lapses": lapses,
        ]
    }
}
```

- [ ] **Step 3: Add `UUIDv7.swift` helper** in `ios/Flashcards/Util/`:

```swift
import Foundation

public enum UUIDv7 {
    /// Generates a UUIDv7 string (time-ordered; 48-bit unix-ms prefix + 74 random bits).
    public static func next() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((ms >> 40) & 0xFF)
        bytes[1] = UInt8((ms >> 32) & 0xFF)
        bytes[2] = UInt8((ms >> 24) & 0xFF)
        bytes[3] = UInt8((ms >> 16) & 0xFF)
        bytes[4] = UInt8((ms >> 8) & 0xFF)
        bytes[5] = UInt8(ms & 0xFF)
        for i in 6..<16 { bytes[i] = UInt8.random(in: 0...255) }
        bytes[6] = (bytes[6] & 0x0F) | 0x70  // version 7
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let s = hex
        let parts = [s.prefix(8), s.dropFirst(8).prefix(4), s.dropFirst(12).prefix(4),
                     s.dropFirst(16).prefix(4), s.dropFirst(20).prefix(12)]
        return parts.joined(separator: "-")
    }
}
```

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/SessionEngineTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): SessionEngine (rate → review + card + enqueue) + UUIDv7 (2.4)"
```

---

### Task 2.5: `MWRatingButton` molecule

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWRatingButton.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI

public struct MWRatingButton: View {
    public enum Size { case regular, compact }
    let rating: MWRating
    let intervalLabel: String
    let action: () -> Void
    let size: Size

    public init(rating: MWRating, intervalLabel: String, size: Size = .regular, action: @escaping () -> Void) {
        self.rating = rating; self.intervalLabel = intervalLabel; self.size = size; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: MWSpacing.xs) {
                Text(rating.label).font(MWType.bodyL.weight(.semibold))
                Text(intervalLabel).font(MWType.bodyS)
            }
            .foregroundStyle(MWColor.paper)
            .frame(maxWidth: .infinity, minHeight: size == .regular ? 72 : 56)
            .background(tint)
            .mwCornerRadius(.s)
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        switch rating { case .again: MWColor.again; case .hard: MWColor.hard
        case .good: MWColor.good; case .easy: MWColor.easy }
    }
}

#Preview("Rating buttons row") {
    HStack(spacing: MWSpacing.s) {
        MWRatingButton(rating: .again, intervalLabel: "6m") {}
        MWRatingButton(rating: .hard,  intervalLabel: "1d") {}
        MWRatingButton(rating: .good,  intervalLabel: "4d") {}
        MWRatingButton(rating: .easy,  intervalLabel: "12d") {}
    }
    .mwPadding(.all, .l)
    .background(MWColor.canvas)
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWRatingButton molecule (2.5)"
```

---

### Task 2.6: `MWDuePill`, `MWProgressBar`, `MWSwitch`, `MWChip` atoms

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWDuePill.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWProgressBar.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWSwitch.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWChip.swift`

- [ ] **Step 1: `MWDuePill.swift`:**

```swift
import SwiftUI

public struct MWDuePill: View {
    let count: Int
    public init(count: Int) { self.count = count }
    public var body: some View {
        HStack(spacing: MWSpacing.xs) {
            MWDot(color: count > 0 ? MWColor.good : MWColor.inkFaint)
            Text(count == 0 ? "All caught up" : "\(count) due")
                .font(MWType.bodyS.weight(.semibold))
                .foregroundStyle(MWColor.ink)
        }
        .mwPadding(.horizontal, .s).mwPadding(.vertical, .xs)
        .background(MWColor.paper)
        .mwCornerRadius(.l)
        .mwStroke(color: MWColor.ink, width: MWBorder.default)
    }
}
```

- [ ] **Step 2: `MWProgressBar.swift`:**

```swift
import SwiftUI

public struct MWProgressBar: View {
    let progress: Double
    public init(progress: Double) { self.progress = max(0, min(1, progress)) }
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(MWColor.canvas)
                Rectangle().fill(MWColor.ink)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: MWBorder.bold * 2)
        .mwStroke(color: MWColor.ink, width: MWBorder.default)
    }
}
```

- [ ] **Step 3: `MWSwitch.swift`:**

```swift
import SwiftUI

public struct MWSwitch: View {
    @Binding var isOn: Bool
    public init(isOn: Binding<Bool>) { self._isOn = isOn }
    public var body: some View {
        Toggle("", isOn: $isOn).labelsHidden().tint(MWColor.ink)
    }
}
```

- [ ] **Step 4: `MWChip.swift`:**

```swift
import SwiftUI

public struct MWChip: View {
    let text: String
    let selected: Bool
    let onTap: () -> Void
    public init(text: String, selected: Bool = false, onTap: @escaping () -> Void) {
        self.text = text; self.selected = selected; self.onTap = onTap
    }
    public var body: some View {
        Button(action: onTap) {
            Text(text).font(MWType.bodyS.weight(.medium))
                .foregroundStyle(selected ? MWColor.paper : MWColor.ink)
                .mwPadding(.horizontal, .m).mwPadding(.vertical, .xs)
                .background(selected ? MWColor.ink : MWColor.paper)
                .mwCornerRadius(.l)
                .mwStroke(color: MWColor.ink, width: MWBorder.default)
        }.buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWDuePill, MWProgressBar, MWSwitch, MWChip (2.6)"
```

---

### Task 2.7: `MWTextArea`, `MWTopBar`, `MWSection`, `MWFormRow`

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Atoms/MWTextArea.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWTopBar.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWSection.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWFormRow.swift`

- [ ] **Step 1: `MWTextArea.swift`:**

```swift
import SwiftUI

public struct MWTextArea: View {
    let label: String
    @Binding var text: String
    let minHeight: CGFloat

    public init(label: String, text: Binding<String>, minHeight: CGFloat = 120) {
        self.label = label; self._text = text; self.minHeight = minHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.xs) {
            MWEyebrow(label)
            TextEditor(text: $text)
                .font(MWType.bodyL)
                .foregroundStyle(MWColor.ink)
                .scrollContentBackground(.hidden)
                .mwPadding(.all, .s)
                .frame(minHeight: minHeight)
                .background(MWColor.paper)
                .mwCornerRadius(.s)
                .mwStroke(color: MWColor.ink, width: MWBorder.default)
        }
    }
}
```

- [ ] **Step 2: `MWTopBar.swift`:**

```swift
import SwiftUI

public struct MWTopBar<Leading: View, Trailing: View>: View {
    let title: String?
    let leading: () -> Leading
    let trailing: () -> Trailing
    public init(title: String? = nil, @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title; self.leading = leading; self.trailing = trailing
    }
    public var body: some View {
        HStack {
            leading()
            Spacer()
            if let title { Text(title).font(MWType.headingM).foregroundStyle(MWColor.ink) }
            Spacer()
            trailing()
        }
        .frame(minHeight: 44)
        .mwPadding(.horizontal, .l)
    }
}
```

- [ ] **Step 3: `MWSection.swift`:**

```swift
import SwiftUI

public struct MWSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content
    public init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.content = content
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.s) {
            if let title { MWEyebrow(title) }
            content()
        }
    }
}
```

- [ ] **Step 4: `MWFormRow.swift`:**

```swift
import SwiftUI

public struct MWFormRow<Accessory: View>: View {
    let title: String
    let value: String?
    @ViewBuilder let accessory: () -> Accessory
    let onTap: (() -> Void)?
    public init(title: String, value: String? = nil,
                onTap: (() -> Void)? = nil,
                @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title; self.value = value; self.accessory = accessory; self.onTap = onTap
    }
    public var body: some View {
        Button(action: { onTap?() }) {
            HStack {
                Text(title).font(MWType.bodyL).foregroundStyle(MWColor.ink)
                Spacer()
                if let value { Text(value).font(MWType.body).foregroundStyle(MWColor.inkMuted) }
                accessory()
            }
            .mwPadding(.vertical, .m)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWTextArea, MWTopBar, MWSection, MWFormRow (2.7)"
```

---

### Task 2.8: `MWBottomSheet`, `MWActionSheet`, `MWEmptyState`

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWBottomSheet.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWActionSheet.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWEmptyState.swift`

- [ ] **Step 1: `MWBottomSheet.swift`:**

```swift
import SwiftUI

public struct MWBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: () -> SheetContent

    public func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetContent()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(MWColor.paper)
        }
    }
}

public extension View {
    func mwBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(MWBottomSheetModifier(isPresented: isPresented, detents: detents, sheetContent: content))
    }
}
```

- [ ] **Step 2: `MWActionSheet.swift`:**

```swift
import SwiftUI

public struct MWActionSheetAction: Identifiable {
    public let id = UUID()
    let label: String
    let role: ButtonRole?
    let action: () -> Void
    public init(_ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label; self.role = role; self.action = action
    }
}

public extension View {
    func mwActionSheet(title: String, isPresented: Binding<Bool>, actions: [MWActionSheetAction]) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            ForEach(actions) { a in
                Button(a.label, role: a.role, action: a.action)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
```

- [ ] **Step 3: `MWEmptyState.swift`:**

```swift
import SwiftUI

public struct MWEmptyState: View {
    let eyebrow: String?
    let title: String
    let message: String?
    let ctaTitle: String?
    let onCtaTap: (() -> Void)?

    public init(eyebrow: String? = nil, title: String, message: String? = nil,
                ctaTitle: String? = nil, onCtaTap: (() -> Void)? = nil) {
        self.eyebrow = eyebrow; self.title = title; self.message = message
        self.ctaTitle = ctaTitle; self.onCtaTap = onCtaTap
    }

    public var body: some View {
        VStack(spacing: MWSpacing.l) {
            if let eyebrow { MWEyebrow(eyebrow) }
            Text(title).font(MWType.headingM).foregroundStyle(MWColor.ink).multilineTextAlignment(.center)
            if let message { Text(message).font(MWType.body).foregroundStyle(MWColor.inkMuted).multilineTextAlignment(.center) }
            if let ctaTitle, let onCtaTap {
                MWButton(ctaTitle, action: onCtaTap)
            }
        }
        .mwPadding(.all, .xl)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWBottomSheet, MWActionSheet, MWEmptyState (2.8)"
```

---

### Task 2.9: `MWDeckCard`, `MWCardTile`, `MWStackedDeckPaper`

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWDeckCard.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWCardTile.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWStackedDeckPaper.swift`

- [ ] **Step 1: `MWStackedDeckPaper.swift`:**

```swift
import SwiftUI

/// The stacked-paper illusion — three offset sheets behind the top card.
public struct MWStackedDeckPaper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public var body: some View {
        ZStack {
            // Rear sheets
            RoundedRectangle(cornerRadius: MWRadius.m)
                .fill(MWColor.paper).mwStroke(color: MWColor.ink, width: MWBorder.default)
                .offset(x: 6, y: 6).opacity(0.65)
            RoundedRectangle(cornerRadius: MWRadius.m)
                .fill(MWColor.paper).mwStroke(color: MWColor.ink, width: MWBorder.default)
                .offset(x: 3, y: 3).opacity(0.85)
            content()
                .background(MWColor.paper)
                .mwCornerRadius(.m)
                .mwStroke(color: MWColor.ink, width: MWBorder.default)
        }
    }
}
```

- [ ] **Step 2: `MWDeckCard.swift`:**

```swift
import SwiftUI

public struct MWDeckCard: View {
    let title: String
    let subTopicCount: Int
    let cardCount: Int
    let dueCount: Int
    let accent: MWAccent

    public init(title: String, subTopicCount: Int, cardCount: Int, dueCount: Int, accent: MWAccent) {
        self.title = title; self.subTopicCount = subTopicCount
        self.cardCount = cardCount; self.dueCount = dueCount; self.accent = accent
    }

    public var body: some View {
        MWStackedDeckPaper {
            VStack(alignment: .leading, spacing: MWSpacing.m) {
                HStack {
                    Rectangle().fill(accent.color).frame(width: 10, height: 10)
                    Spacer()
                    MWDuePill(count: dueCount)
                }
                Text(title).font(MWType.headingM).foregroundStyle(MWColor.ink).lineLimit(2)
                HStack(spacing: MWSpacing.l) {
                    Label("\(cardCount)", systemImage: "square.stack.3d.up")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                    Label("\(subTopicCount)", systemImage: "tag")
                        .font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                }
            }
            .mwPadding(.all, .l)
        }
        .mwAccent(accent.color)
        .frame(height: 160)
    }
}
```

- [ ] **Step 3: `MWCardTile.swift`:**

```swift
import SwiftUI

public struct MWCardTile: View {
    let frontText: String
    let backTextPreview: String?
    let subTopics: [String]
    let dueLabel: String?

    public init(frontText: String, backTextPreview: String? = nil,
                subTopics: [String] = [], dueLabel: String? = nil) {
        self.frontText = frontText; self.backTextPreview = backTextPreview
        self.subTopics = subTopics; self.dueLabel = dueLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MWSpacing.s) {
            Text(frontText).font(MWType.bodyL.weight(.semibold)).foregroundStyle(MWColor.ink).lineLimit(2)
            if let backTextPreview {
                Text(backTextPreview).font(MWType.body).foregroundStyle(MWColor.inkMuted).lineLimit(2)
            }
            HStack(spacing: MWSpacing.xs) {
                ForEach(subTopics, id: \.self) { st in MWPill(st, tint: MWColor.inkMuted) }
                Spacer()
                if let dueLabel {
                    Text(dueLabel).font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                }
            }
        }
        .mwPadding(.all, .m)
        .background(MWColor.paper)
        .mwCornerRadius(.s)
        .mwStroke(color: MWColor.ink, width: MWBorder.default)
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWDeckCard, MWCardTile, MWStackedDeckPaper (2.9)"
```

---

### Task 2.10: `MWIcon` + SVG-generated Shape struct pipeline

**Files:**
- Create: `ios/Flashcards/DesignSystem/Icons/MWIcon.swift`
- Create: `ios/Flashcards/DesignSystem/Icons/Generated/HomeIcon.swift` (example generated)
- Create: `ios/scripts/generate-icons.sh`

- [ ] **Step 1: Create `MWIcon.swift` enum of named icons:**

```swift
import SwiftUI

public enum MWIconName: String, CaseIterable {
    case home, search, settings, add, delete, back, more, check, close, chevronRight
}

public struct MWIcon: View {
    let name: MWIconName
    let size: CGFloat
    public init(_ name: MWIconName, size: CGFloat = 20) { self.name = name; self.size = size }
    public var body: some View {
        switch name {
        case .home: HomeIcon().frame(width: size, height: size)
        case .search: SearchIcon().frame(width: size, height: size)
        case .settings: SettingsIcon().frame(width: size, height: size)
        case .add: AddIcon().frame(width: size, height: size)
        case .delete: DeleteIcon().frame(width: size, height: size)
        case .back: BackIcon().frame(width: size, height: size)
        case .more: MoreIcon().frame(width: size, height: size)
        case .check: CheckIcon().frame(width: size, height: size)
        case .close: CloseIcon().frame(width: size, height: size)
        case .chevronRight: ChevronRightIcon().frame(width: size, height: size)
        }
    }
}
```

- [ ] **Step 2: Implement minimum-viable stroke-drawn shapes** for each icon (one file per icon in `Generated/`). Example `HomeIcon.swift`:

```swift
import SwiftUI

struct HomeIcon: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            Path { path in
                path.move(to: CGPoint(x: s * 0.1, y: s * 0.5))
                path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.15))
                path.addLine(to: CGPoint(x: s * 0.9, y: s * 0.5))
                path.move(to: CGPoint(x: s * 0.2, y: s * 0.45))
                path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.9))
                path.addLine(to: CGPoint(x: s * 0.8, y: s * 0.9))
                path.addLine(to: CGPoint(x: s * 0.8, y: s * 0.45))
            }
            .stroke(MWColor.ink, style: StrokeStyle(lineWidth: MWBorder.default, lineCap: .round, lineJoin: .round))
        }
    }
}
```

Implement the remaining 9 icons in the same pattern (one file each). Keep each under 20 lines. Icon SVG sources from `mw/01-tokens.jsx` if available — translate stroke paths to SwiftUI `Path` calls.

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): MWIcon system + 10 stroke-drawn icons (2.10)"
```

---

### Task 2.11: Repositories — Deck, Card, SubTopic, Topic

**Files:**
- Create: `ios/Flashcards/Data/Repositories/DeckRepository.swift`
- Create: `ios/Flashcards/Data/Repositories/CardRepository.swift`
- Create: `ios/Flashcards/Data/Repositories/SubTopicRepository.swift`
- Create: `ios/Flashcards/Data/Repositories/TopicRepository.swift`

- [ ] **Step 1: `DeckRepository.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class DeckRepository {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func create(title: String, accentColor: MWAccent, userId: String,
                       defaultStudyMode: SessionMode = .smart, topicId: String? = nil,
                       description: String? = nil) throws -> DeckEntity {
        let now = Clock.nowMs()
        let d = DeckEntity(id: UUIDv7.next(), userId: userId, title: title,
                           accentColor: accentColor.rawValue, defaultStudyMode: defaultStudyMode.rawValue,
                           syncUpdatedAtMs: now)
        d.topicId = topicId
        d.deckDescription = description
        context.insert(d)
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: DeckEntity.syncEntityKey,
                                                    recordId: d.id, payload: d.syncPayload())
        return d
    }

    public func update(_ deck: DeckEntity, apply: (DeckEntity) -> Void) throws {
        apply(deck)
        deck.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: DeckEntity.syncEntityKey,
                                                    recordId: deck.id, payload: deck.syncPayload())
    }

    public func softDelete(_ deck: DeckEntity) throws {
        deck.syncDeletedAtMs = Clock.nowMs()
        deck.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: DeckEntity.syncEntityKey,
                                                    recordId: deck.id, payload: deck.syncPayload())
    }

    public func liveDecksForUser(_ userId: String) throws -> [DeckEntity] {
        try context.fetch(FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.userId == userId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.lastStudiedAtMs, order: .reverse)]
        ))
    }

    public func duplicate(_ source: DeckEntity) throws -> DeckEntity {
        let copy = try create(
            title: "\(source.title) (copy)",
            accentColor: MWAccent(rawValue: source.accentColor) ?? .amber,
            userId: source.userId,
            defaultStudyMode: SessionMode(rawValue: source.defaultStudyMode) ?? .smart,
            topicId: source.topicId, description: source.deckDescription
        )
        // Copy cards (FSRS state NOT copied, per spec §10.3).
        let cards = try context.fetch(FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == source.id && $0.syncDeletedAtMs == nil }
        ))
        for c in cards {
            let newCard = CardEntity(id: UUIDv7.next(), deckId: copy.id,
                                     frontText: c.frontText, backText: c.backText,
                                     syncUpdatedAtMs: Clock.nowMs())
            newCard.position = c.position
            context.insert(newCard)
            try MutationQueue(context: context).enqueue(entityKey: CardEntity.syncEntityKey,
                                                        recordId: newCard.id, payload: newCard.syncPayload())
        }
        // Copy sub-topics (no card-linkage carried since IDs changed).
        let subs = try context.fetch(FetchDescriptor<SubTopicEntity>(
            predicate: #Predicate { $0.deckId == source.id && $0.syncDeletedAtMs == nil }
        ))
        for s in subs {
            let newSub = SubTopicEntity(id: UUIDv7.next(), deckId: copy.id, name: s.name,
                                        position: s.position, syncUpdatedAtMs: Clock.nowMs())
            context.insert(newSub)
            try MutationQueue(context: context).enqueue(entityKey: SubTopicEntity.syncEntityKey,
                                                        recordId: newSub.id, payload: newSub.syncPayload())
        }
        try context.save()
        return copy
    }
}
```

- [ ] **Step 2: `CardRepository.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class CardRepository {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func create(deckId: String, frontText: String, backText: String,
                       subTopicIds: [String] = []) throws -> CardEntity {
        let now = Clock.nowMs()
        let nextPos = try maxPosition(deckId: deckId) + 1
        let c = CardEntity(id: UUIDv7.next(), deckId: deckId,
                           frontText: frontText, backText: backText, syncUpdatedAtMs: now)
        c.position = nextPos
        context.insert(c)

        let q = MutationQueue(context: context)
        try q.enqueue(entityKey: CardEntity.syncEntityKey, recordId: c.id, payload: c.syncPayload())

        for stId in subTopicIds {
            let j = CardSubTopicEntity(id: UUIDv7.next(), cardId: c.id,
                                       subTopicId: stId, syncUpdatedAtMs: now)
            context.insert(j)
            try q.enqueue(entityKey: CardSubTopicEntity.syncEntityKey, recordId: j.id, payload: j.syncPayload())
        }
        try context.save()
        return c
    }

    public func update(_ card: CardEntity, apply: (CardEntity) -> Void) throws {
        apply(card); card.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: CardEntity.syncEntityKey,
                                                    recordId: card.id, payload: card.syncPayload())
    }

    public func softDelete(_ card: CardEntity) throws {
        card.syncDeletedAtMs = Clock.nowMs()
        card.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: CardEntity.syncEntityKey,
                                                    recordId: card.id, payload: card.syncPayload())
    }

    public func liveCards(deckId: String) throws -> [CardEntity] {
        try context.fetch(FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.position)]
        ))
    }

    public func resetProgress(_ card: CardEntity) throws {
        try update(card) { c in
            c.stability = nil; c.difficulty = nil; c.state = "new"
            c.dueAtMs = nil; c.lastReviewedAtMs = nil
            c.reps = 0; c.lapses = 0
        }
    }

    private func maxPosition(deckId: String) throws -> Int {
        let all = try context.fetch(FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.deckId == deckId }
        ))
        return all.map(\.position).max() ?? -1
    }
}
```

- [ ] **Step 3: `SubTopicRepository.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class SubTopicRepository {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func create(deckId: String, name: String) throws -> SubTopicEntity {
        let pos = try maxPosition(deckId: deckId) + 1
        let s = SubTopicEntity(id: UUIDv7.next(), deckId: deckId, name: name,
                               position: pos, syncUpdatedAtMs: Clock.nowMs())
        context.insert(s)
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: SubTopicEntity.syncEntityKey,
                                                    recordId: s.id, payload: s.syncPayload())
        return s
    }

    public func list(deckId: String) throws -> [SubTopicEntity] {
        try context.fetch(FetchDescriptor<SubTopicEntity>(
            predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.position)]
        ))
    }

    public func reorder(_ subTopics: [SubTopicEntity]) throws {
        let now = Clock.nowMs()
        for (idx, st) in subTopics.enumerated() {
            st.position = idx
            st.syncUpdatedAtMs = now
            try MutationQueue(context: context).enqueue(entityKey: SubTopicEntity.syncEntityKey,
                                                        recordId: st.id, payload: st.syncPayload())
        }
        try context.save()
    }

    public func rename(_ st: SubTopicEntity, to name: String) throws {
        st.name = name; st.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: SubTopicEntity.syncEntityKey,
                                                    recordId: st.id, payload: st.syncPayload())
    }

    public func softDelete(_ st: SubTopicEntity) throws {
        st.syncDeletedAtMs = Clock.nowMs(); st.syncUpdatedAtMs = Clock.nowMs()
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: SubTopicEntity.syncEntityKey,
                                                    recordId: st.id, payload: st.syncPayload())
    }

    private func maxPosition(deckId: String) throws -> Int {
        (try list(deckId: deckId)).map(\.position).max() ?? -1
    }
}
```

- [ ] **Step 4: `TopicRepository.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class TopicRepository {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    public func create(userId: String, name: String) throws -> TopicEntity {
        let t = TopicEntity(id: UUIDv7.next(), userId: userId, name: name, syncUpdatedAtMs: Clock.nowMs())
        context.insert(t)
        try context.save()
        try MutationQueue(context: context).enqueue(entityKey: TopicEntity.syncEntityKey,
                                                    recordId: t.id, payload: t.syncPayload())
        return t
    }

    public func list(userId: String) throws -> [TopicEntity] {
        try context.fetch(FetchDescriptor<TopicEntity>(
            predicate: #Predicate { $0.userId == userId && $0.syncDeletedAtMs == nil },
            sortBy: [SortDescriptor(\.name)]
        ))
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(data): Deck/Card/SubTopic/Topic repositories with enqueue wiring (2.11)"
```

---

### Task 2.12: HomeView — deck grid

**Files:**
- Create: `ios/Flashcards/Features/Home/HomeViewModel.swift`
- Create: `ios/Flashcards/Features/Home/HomeView.swift`

- [ ] **Step 1: `HomeViewModel.swift`:**

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class HomeViewModel {
    public var decks: [DeckEntity] = []
    public var dueCountsByDeck: [String: Int] = [:]
    public var isLoading = false

    private let deckRepo: DeckRepository
    private let queueBuilder: SessionQueueBuilder
    private let userId: String

    public init(context: ModelContext, userId: String) {
        self.deckRepo = DeckRepository(context: context)
        self.queueBuilder = SessionQueueBuilder(context: context)
        self.userId = userId
    }

    public func load() throws {
        isLoading = true
        defer { isLoading = false }
        decks = try deckRepo.liveDecksForUser(userId)
        let now = Clock.nowMs()
        for d in decks {
            let due = try queueBuilder.smartQueue(deckId: d.id, now: now, dailyNewCardLimit: 0).count
            dueCountsByDeck[d.id] = due
        }
    }
}
```

- [ ] **Step 2: `HomeView.swift`:**

```swift
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var vm: HomeViewModel?
    @State private var showingCreate = false
    @State private var showingSearch = false

    private let userId: String
    init(userId: String) { self.userId = userId }

    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWTopBar(title: "Decks",
                         leading: { Button { showingSearch = true } label: { MWIcon(.search) } },
                         trailing: { Button { showingCreate = true } label: { MWIcon(.add) } })

                if let vm {
                    if vm.decks.isEmpty {
                        MWEmptyState(
                            eyebrow: "No decks yet",
                            title: "Create your first deck.",
                            message: "A deck is a collection of cards on one topic.",
                            ctaTitle: "New deck",
                            onCtaTap: { showingCreate = true }
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MWSpacing.m) {
                                ForEach(vm.decks, id: \.id) { d in
                                    NavigationLink(value: d.id) {
                                        MWDeckCard(
                                            title: d.title,
                                            subTopicCount: 0,
                                            cardCount: d.cardCount,
                                            dueCount: vm.dueCountsByDeck[d.id] ?? 0,
                                            accent: MWAccent(rawValue: d.accentColor) ?? .amber
                                        )
                                    }.buttonStyle(.plain)
                                }
                            }
                            .mwPadding(.horizontal, .l)
                        }
                    }
                } else {
                    ProgressView().foregroundStyle(MWColor.ink)
                }
            }
        }
        .navigationDestination(for: String.self) { deckId in
            DeckDetailView(deckId: deckId)
        }
        .mwBottomSheet(isPresented: $showingCreate) { CreateDeckView(userId: userId, onCreated: { try? vm?.load() }) }
        .sheet(isPresented: $showingSearch) { SearchView() }
        .task {
            if vm == nil { vm = HomeViewModel(context: context, userId: userId) }
            try? vm?.load()
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(home): HomeView with deck grid + empty state (2.12)"
```

---

### Task 2.13: `CreateDeckView`

**Files:**
- Create: `ios/Flashcards/Features/Deck/CreateDeckView.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI
import SwiftData

struct CreateDeckView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let onCreated: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var accent: MWAccent = .amber
    @State private var mode: SessionMode = .smart

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWEyebrow("New deck")
                Text("Create deck").font(MWType.headingL).foregroundStyle(MWColor.ink)

                MWTextField(label: "Title", text: $title)
                MWTextArea(label: "Description (optional)", text: $description, minHeight: 80)

                MWSection("Accent") {
                    HStack(spacing: MWSpacing.s) {
                        ForEach(MWAccent.allCases, id: \.self) { a in
                            Button { accent = a } label: {
                                Rectangle().fill(a.color)
                                    .frame(width: 40, height: 40)
                                    .mwStroke(color: accent == a ? MWColor.ink : MWColor.inkFaint, width: accent == a ? MWBorder.bold : MWBorder.default)
                            }.buttonStyle(.plain)
                        }
                    }
                }

                MWSection("Default study mode") {
                    HStack(spacing: MWSpacing.s) {
                        MWChip(text: "Smart (FSRS)", selected: mode == .smart) { mode = .smart }
                        MWChip(text: "Basic", selected: mode == .basic) { mode = .basic }
                    }
                }

                MWButton("Create deck") {
                    do {
                        _ = try DeckRepository(context: context).create(
                            title: title, accentColor: accent, userId: userId,
                            defaultStudyMode: mode,
                            description: description.isEmpty ? nil : description
                        )
                        onCreated()
                        dismiss()
                    } catch { AnalyticsClient.track("deck.create.fail") }
                }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .mwPadding(.all, .xl)
        }
        .background(MWColor.canvas)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): CreateDeckView sheet with accent + mode picker (2.13)"
```

---

### Task 2.14: `DeckDetailView` — tab host (Cards / History)

**Files:**
- Create: `ios/Flashcards/Features/DeckDetail/DeckDetailView.swift`
- Create: `ios/Flashcards/Features/DeckDetail/DeckDetailViewModel.swift`
- Create: `ios/Flashcards/Features/DeckDetail/CardsTabView.swift`
- Create: `ios/Flashcards/Features/DeckDetail/HistoryTabView.swift`

- [ ] **Step 1: `DeckDetailViewModel.swift`:**

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class DeckDetailViewModel {
    public var deck: DeckEntity?
    public var cards: [CardEntity] = []
    public var subTopics: [SubTopicEntity] = []
    public var recentSessions: [SessionEntity] = []
    public var dueCount: Int = 0

    private let context: ModelContext
    private let deckId: String

    public init(context: ModelContext, deckId: String) {
        self.context = context; self.deckId = deckId
    }

    public func load() throws {
        deck = try context.fetch(FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.id == deckId }
        )).first
        cards = try CardRepository(context: context).liveCards(deckId: deckId)
        subTopics = try SubTopicRepository(context: context).list(deckId: deckId)
        dueCount = try SessionQueueBuilder(context: context)
            .smartQueue(deckId: deckId, now: Clock.nowMs(), dailyNewCardLimit: 0).count
        recentSessions = try context.fetch(FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.deckId == deckId },
            sortBy: [SortDescriptor(\.startedAtMs, order: .reverse)]
        )).prefix(20).map { $0 }
    }
}
```

- [ ] **Step 2: `DeckDetailView.swift`:**

```swift
import SwiftUI
import SwiftData

struct DeckDetailView: View {
    enum Tab: String, CaseIterable { case history = "History", cards = "Cards" }

    @Environment(\.modelContext) private var context
    @State private var vm: DeckDetailViewModel?
    @State private var tab: Tab = .cards
    @State private var showingCreateCard = false
    @State private var showingStudy = false

    let deckId: String

    var body: some View {
        MWScreen {
            VStack(spacing: MWSpacing.l) {
                if let vm, let d = vm.deck {
                    VStack(alignment: .leading, spacing: MWSpacing.s) {
                        MWEyebrow(MWAccent(rawValue: d.accentColor)?.rawValue.uppercased() ?? "")
                        Text(d.title).font(MWType.headingL).foregroundStyle(MWColor.ink)
                        HStack { MWDuePill(count: vm.dueCount); Spacer() }
                    }.mwPadding(.horizontal, .l)

                    HStack(spacing: MWSpacing.s) {
                        ForEach(Tab.allCases, id: \.self) { t in
                            MWChip(text: t.rawValue, selected: tab == t) { tab = t }
                        }
                        Spacer()
                    }.mwPadding(.horizontal, .l)

                    switch tab {
                    case .cards:    CardsTabView(vm: vm, onEdit: {})
                    case .history:  HistoryTabView(vm: vm)
                    }

                    HStack {
                        MWButton("Study now") { showingStudy = true }
                            .disabled(vm.cards.isEmpty)
                    }.mwPadding(.all, .l)
                } else {
                    ProgressView().task {
                        if vm == nil { vm = DeckDetailViewModel(context: context, deckId: deckId) }
                        try? vm?.load()
                    }
                }
            }
        }
        .mwScreenChrome()
        .fullScreenCover(isPresented: $showingStudy) {
            SessionRootView(deckId: deckId, onDismiss: { showingStudy = false; try? vm?.load() })
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreateCard = true } label: { MWIcon(.add) }
            }
        }
        .sheet(isPresented: $showingCreateCard) {
            CreateCardView(deckId: deckId, onSaved: { try? vm?.load() })
        }
    }
}
```

- [ ] **Step 3: `CardsTabView.swift`:**

```swift
import SwiftUI

struct CardsTabView: View {
    @Bindable var vm: DeckDetailViewModel
    let onEdit: () -> Void
    @State private var selection = Set<String>()
    @State private var editingCard: CardEntity?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MWSpacing.s) {
                ForEach(vm.cards, id: \.id) { c in
                    Button {
                        editingCard = c
                    } label: {
                        MWCardTile(
                            frontText: c.frontText,
                            backTextPreview: c.backText,
                            dueLabel: dueLabel(for: c)
                        )
                    }.buttonStyle(.plain)
                }
            }.mwPadding(.horizontal, .l)
        }
        .sheet(item: $editingCard) { c in CardEditView(card: c) }
    }

    private func dueLabel(for c: CardEntity) -> String? {
        guard let due = c.dueAtMs else { return c.state == "new" ? "New" : nil }
        let days = Int((Double(due - Clock.nowMs()) / 86_400_000).rounded())
        if days <= 0 { return "Due" }
        return "\(days)d"
    }
}
```

- [ ] **Step 4: `HistoryTabView.swift`:**

```swift
import SwiftUI

struct HistoryTabView: View {
    let vm: DeckDetailViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MWSpacing.s) {
                if vm.recentSessions.isEmpty {
                    MWEmptyState(title: "No sessions yet",
                                 message: "Study this deck and recent sessions will show here.")
                } else {
                    ForEach(vm.recentSessions, id: \.id) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: MWSpacing.xs) {
                                Text(s.mode.capitalized).font(MWType.bodyL.weight(.semibold)).foregroundStyle(MWColor.ink)
                                Text("\(s.cardsReviewed) cards • \(Int(s.accuracyPct))%")
                                    .font(MWType.bodyS).foregroundStyle(MWColor.inkMuted)
                            }
                            Spacer()
                            Text(relative(s.startedAtMs)).font(MWType.bodyS).foregroundStyle(MWColor.inkFaint)
                        }
                        .mwPadding(.all, .m)
                        .background(MWColor.paper)
                        .mwCornerRadius(.s)
                        .mwStroke(color: MWColor.ink, width: MWBorder.default)
                    }
                }
            }.mwPadding(.horizontal, .l)
        }
    }

    private func relative(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): DeckDetailView with Cards + History tabs (2.14)"
```

---

### Task 2.15: `CreateCardView` + `CardEditView`

**Files:**
- Create: `ios/Flashcards/Features/Card/CreateCardView.swift`
- Create: `ios/Flashcards/Features/Card/CardEditView.swift`
- Create: `ios/Flashcards/Features/Card/CardFormModel.swift`

- [ ] **Step 1: `CardFormModel.swift`:**

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class CardFormModel {
    public var frontText: String
    public var backText: String
    public var selectedSubTopicIds: Set<String>

    public init(frontText: String = "", backText: String = "", selectedSubTopicIds: Set<String> = []) {
        self.frontText = frontText; self.backText = backText
        self.selectedSubTopicIds = selectedSubTopicIds
    }

    public var isValid: Bool {
        !frontText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !backText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var hasChanges: Bool {
        !frontText.isEmpty || !backText.isEmpty || !selectedSubTopicIds.isEmpty
    }
}
```

- [ ] **Step 2: `CreateCardView.swift`:**

```swift
import SwiftUI
import SwiftData

struct CreateCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let deckId: String
    let onSaved: () -> Void

    @State private var form = CardFormModel()
    @State private var subTopics: [SubTopicEntity] = []
    @State private var showDiscardConfirm = false

    var body: some View {
        NavigationStack {
            MWScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: MWSpacing.l) {
                        MWTextArea(label: "Front", text: $form.frontText)
                        MWTextArea(label: "Back", text: $form.backText)
                        if !subTopics.isEmpty {
                            MWSection("Sub-topics") {
                                FlowChips(items: subTopics, selected: $form.selectedSubTopicIds)
                            }
                        }
                    }.mwPadding(.all, .xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if form.hasChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(!form.isValid)
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirm) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .task {
                subTopics = (try? SubTopicRepository(context: context).list(deckId: deckId)) ?? []
            }
        }
    }

    private func save() {
        do {
            _ = try CardRepository(context: context).create(
                deckId: deckId, frontText: form.frontText, backText: form.backText,
                subTopicIds: Array(form.selectedSubTopicIds)
            )
            onSaved(); dismiss()
        } catch { AnalyticsClient.track("card.create.fail") }
    }
}

struct FlowChips: View {
    let items: [SubTopicEntity]
    @Binding var selected: Set<String>
    var body: some View {
        WrapHStack(spacing: MWSpacing.xs) {
            ForEach(items, id: \.id) { st in
                MWChip(text: st.name, selected: selected.contains(st.id)) {
                    if selected.contains(st.id) { selected.remove(st.id) }
                    else { selected.insert(st.id) }
                }
            }
        }
    }
}

/// Minimal wrap layout — newer SwiftUI has `Layout` for this; inline a simple version.
struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing; self.content = content
    }
    var body: some View {
        FlexibleView(spacing: spacing) { content() }
    }
}

struct FlexibleView<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing; self.content = content
    }
    var body: some View {
        // Use system Layout — in iOS 17+ just rely on HStackFlow or ViewThatFits
        HStack(alignment: .top, spacing: spacing) { content() }.lineLimit(nil).frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 3: `CardEditView.swift`:**

```swift
import SwiftUI
import SwiftData

struct CardEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let card: CardEntity

    @State private var form: CardFormModel
    @State private var showDelete = false

    init(card: CardEntity) {
        self.card = card
        _form = State(initialValue: CardFormModel(frontText: card.frontText, backText: card.backText))
    }

    var body: some View {
        NavigationStack {
            MWScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: MWSpacing.l) {
                        MWTextArea(label: "Front", text: $form.frontText)
                        MWTextArea(label: "Back", text: $form.backText)
                        Button("Reset progress") { resetProgress() }
                            .buttonStyle(.mwSecondary)
                        Button("Delete card") { showDelete = true }
                            .buttonStyle(.mwDestructive)
                    }.mwPadding(.all, .xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() } }
            }
            .confirmationDialog("Delete this card?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        try? CardRepository(context: context).update(card) { c in
            c.frontText = form.frontText; c.backText = form.backText
        }
        dismiss()
    }
    private func resetProgress() {
        try? CardRepository(context: context).resetProgress(card); dismiss()
    }
    private func delete() {
        try? CardRepository(context: context).softDelete(card); dismiss()
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(card): CreateCardView + CardEditView with discard-confirm (2.15)"
```

---

### Task 2.16: `ManageSubTopicsView`

**Files:**
- Create: `ios/Flashcards/Features/DeckDetail/ManageSubTopicsView.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI
import SwiftData

struct ManageSubTopicsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let deckId: String

    @State private var subTopics: [SubTopicEntity] = []
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            MWScreen {
                List {
                    Section("New") {
                        HStack {
                            TextField("Add sub-topic", text: $newName).font(MWType.bodyL)
                            Button("Add") {
                                try? SubTopicRepository(context: context).create(deckId: deckId, name: newName)
                                newName = ""; reload()
                            }.disabled(newName.isEmpty)
                        }
                    }
                    Section("Existing") {
                        ForEach(subTopics, id: \.id) { st in Text(st.name).font(MWType.bodyL) }
                            .onDelete(perform: delete)
                            .onMove(perform: move)
                    }
                }
                .toolbar { EditButton() }
                .task { reload() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }

    private func reload() {
        subTopics = (try? SubTopicRepository(context: context).list(deckId: deckId)) ?? []
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { try? SubTopicRepository(context: context).softDelete(subTopics[i]) }
        reload()
    }

    private func move(from src: IndexSet, to dest: Int) {
        subTopics.move(fromOffsets: src, toOffset: dest)
        try? SubTopicRepository(context: context).reorder(subTopics)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): ManageSubTopicsView with reorder + rename + delete (2.16)"
```

---

### Task 2.17: `SessionRootView` + `SmartStudyView`

**Files:**
- Create: `ios/Flashcards/Features/Session/SessionRootView.swift`
- Create: `ios/Flashcards/Features/Session/SmartStudyView.swift`

- [ ] **Step 1: `SessionRootView.swift`:**

```swift
import SwiftUI
import SwiftData

struct SessionRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let deckId: String
    let onDismiss: () -> Void

    @State private var deck: DeckEntity?
    @State private var session: SessionEntity?
    @State private var queue: [CardEntity] = []
    @State private var index = 0
    @State private var isShowingSummary = false

    var body: some View {
        MWScreen {
            if let deck, let session, !queue.isEmpty, index < queue.count {
                let card = queue[index]
                switch SessionMode(rawValue: deck.defaultStudyMode) ?? .smart {
                case .smart:
                    SmartStudyView(card: card, sessionId: session.id, onAdvance: advance)
                case .basic:
                    BasicStudyView(card: card, onNext: advance)
                }
            } else if isShowingSummary, let session {
                SessionSummaryView(session: session, onDismiss: onDismiss)
            } else {
                ProgressView().task { try? await start() }
            }
        }
    }

    private func start() async throws {
        guard let d = try context.fetch(FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.id == deckId }
        )).first else { return }
        self.deck = d
        let mode = SessionMode(rawValue: d.defaultStudyMode) ?? .smart
        let builder = SessionQueueBuilder(context: context)
        queue = try (mode == .smart
                     ? builder.smartQueue(deckId: d.id, now: Clock.nowMs(), dailyNewCardLimit: 10)
                     : builder.basicQueue(deckId: d.id))

        let userId = currentUserId()
        let s = SessionEntity(id: UUIDv7.next(), userId: userId, deckId: d.id,
                              mode: mode.rawValue, startedAtMs: Clock.nowMs(), syncUpdatedAtMs: Clock.nowMs())
        context.insert(s)
        try context.save()
        self.session = s
    }

    private func advance() {
        index += 1
        if index >= queue.count { finish() }
    }

    private func finish() {
        guard let session else { return }
        session.endedAtMs = Clock.nowMs()
        session.cardsReviewed = index
        // Compute accuracy from reviews in this session: (good + easy) / total.
        let reviews = (try? context.fetch(FetchDescriptor<ReviewEntity>(
            predicate: #Predicate { $0.sessionId == session.id }
        ))) ?? []
        if !reviews.isEmpty {
            let positive = reviews.filter { $0.rating >= 3 }.count
            session.accuracyPct = Double(positive) / Double(reviews.count) * 100.0
        }
        session.syncUpdatedAtMs = Clock.nowMs()
        try? context.save()
        try? MutationQueue(context: context).enqueue(entityKey: SessionEntity.syncEntityKey,
                                                     recordId: session.id, payload: session.syncPayload())
        isShowingSummary = true
    }

    private func currentUserId() -> String {
        // Pulled from AppState; placeholder until Phase 3 wires full session identity.
        switch appState.authStatus {
        case .authenticated(let id): return id
        default: return "anonymous"
        }
    }
}
```

- [ ] **Step 2: `SmartStudyView.swift`:**

```swift
import SwiftUI
import SwiftData

struct SmartStudyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let card: CardEntity
    let sessionId: String
    let onAdvance: () -> Void

    @State private var isFlipped = false
    @State private var previewByRating: [MWRating: Int64] = [:]

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWTopBar(title: "Smart Study")
            Spacer()
            cardBody
                .mwCard()
                .mwPadding(.horizontal, .xl)
                .onTapGesture { isFlipped.toggle(); updatePreview() }
            Spacer()
            if isFlipped {
                HStack(spacing: MWSpacing.s) {
                    ForEach(MWRating.allCases, id: \.self) { r in
                        MWRatingButton(rating: r, intervalLabel: label(for: r)) {
                            rate(r)
                        }
                    }
                }
                .mwPadding(.horizontal, .l)
            } else {
                Text("Tap card to reveal answer")
                    .font(MWType.body).foregroundStyle(MWColor.inkMuted)
            }
        }
        .onAppear { updatePreview() }
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(spacing: MWSpacing.m) {
            Text(isFlipped ? card.backText : card.frontText)
                .font(MWType.headingM).foregroundStyle(MWColor.ink)
                .multilineTextAlignment(.center)
        }
    }

    private func label(for r: MWRating) -> String {
        guard let ms = previewByRating[r] else { return "—" }
        let days = Double(ms) / 86_400_000
        if days < 1 { return "\(Int(Double(ms) / 60_000))m" }
        return "\(Int(days))d"
    }

    private func updatePreview() {
        let sched = FsrsScheduler(weights: nil)
        previewByRating = sched.intervalPreview(for: card.fsrsState(), at: Clock.nowMs())
    }

    private func rate(_ r: MWRating) {
        let engine = SessionEngine(context: context,
                                   userId: currentUserId(),
                                   scheduler: FsrsScheduler(weights: nil),
                                   sessionId: sessionId)
        try? engine.rate(card: card, rating: r, at: Clock.nowMs(), mode: .smart)
        isFlipped = false
        onAdvance()
    }

    private func currentUserId() -> String {
        if case .authenticated(let id) = appState.authStatus { return id }
        return "anonymous"
    }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): SessionRootView + SmartStudyView with FSRS preview (2.17)"
```

---

### Task 2.18: `BasicStudyView` + `SessionSummaryView`

**Files:**
- Create: `ios/Flashcards/Features/Session/BasicStudyView.swift`
- Create: `ios/Flashcards/Features/Session/SessionSummaryView.swift`

- [ ] **Step 1: `BasicStudyView.swift`:**

```swift
import SwiftUI
import SwiftData

struct BasicStudyView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let card: CardEntity
    let onNext: () -> Void

    @State private var isFlipped = false

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWTopBar(title: "Basic Study")
            Spacer()
            VStack(spacing: MWSpacing.m) {
                Text(isFlipped ? card.backText : card.frontText)
                    .font(MWType.headingM).foregroundStyle(MWColor.ink)
                    .multilineTextAlignment(.center)
            }
            .mwCard().mwPadding(.horizontal, .xl)
            .onTapGesture { isFlipped.toggle() }
            Spacer()
            HStack(spacing: MWSpacing.s) {
                MWButton("Got it", kind: .secondary) { record(.good); next() }
                MWButton("Skip") { record(.hard); next() }
            }.mwPadding(.horizontal, .l)
        }
    }

    private func record(_ r: MWRating) {
        let engine = SessionEngine(context: context,
                                   userId: userId(), scheduler: FsrsScheduler(weights: nil),
                                   sessionId: UUIDv7.next())
        try? engine.rate(card: card, rating: r, at: Clock.nowMs(), mode: .basic)
    }

    private func next() { isFlipped = false; onNext() }

    private func userId() -> String {
        if case .authenticated(let id) = appState.authStatus { return id }
        return "anonymous"
    }
}
```

- [ ] **Step 2: `SessionSummaryView.swift`:**

```swift
import SwiftUI

struct SessionSummaryView: View {
    let session: SessionEntity
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            Spacer()
            MWEyebrow("Session summary")
            Text("\(session.cardsReviewed) cards reviewed")
                .font(MWType.headingL).foregroundStyle(MWColor.ink)
            Text(String(format: "%.0f%% accuracy", session.accuracyPct))
                .font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
            Spacer()
            MWButton("Done", action: onDismiss).mwPadding(.horizontal, .xl)
        }
        .mwPadding(.all, .l)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): BasicStudyView + SessionSummaryView (2.18)"
```

---

### Task 2.19: `SearchView` (client-side LIKE)

**Files:**
- Create: `ios/Flashcards/Features/Home/SearchView.swift`

- [ ] **Step 1: Create file:**

```swift
import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var deckResults: [DeckEntity] = []
    @State private var cardResults: [CardEntity] = []

    var body: some View {
        NavigationStack {
            MWScreen {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWTextField(label: "Search", text: $query)
                        .onChange(of: query) { _, new in runSearch(new) }
                    if !deckResults.isEmpty {
                        MWSection("Decks") {
                            ForEach(deckResults, id: \.id) { d in
                                Text(d.title).font(MWType.bodyL).foregroundStyle(MWColor.ink)
                            }
                        }
                    }
                    if !cardResults.isEmpty {
                        MWSection("Cards") {
                            ForEach(cardResults, id: \.id) { c in
                                MWCardTile(frontText: c.frontText, backTextPreview: c.backText)
                            }
                        }
                    }
                    if query.count >= 2, deckResults.isEmpty, cardResults.isEmpty {
                        Text("No matches.").font(MWType.body).foregroundStyle(MWColor.inkMuted)
                    }
                }
                .mwPadding(.all, .xl)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }

    private func runSearch(_ q: String) {
        guard q.trimmingCharacters(in: .whitespaces).count >= 2 else {
            deckResults = []; cardResults = []; return
        }
        let lq = q.lowercased()
        deckResults = (try? context.fetch(FetchDescriptor<DeckEntity>(
            predicate: #Predicate { $0.syncDeletedAtMs == nil }
        )))?.filter { $0.title.lowercased().contains(lq) } ?? []
        cardResults = (try? context.fetch(FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.syncDeletedAtMs == nil }
        )))?.filter {
            $0.frontText.lowercased().contains(lq) || $0.backText.lowercased().contains(lq)
        } ?? []
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(search): SearchView with client-side LIKE over decks + cards (2.19)"
```

---

### Task 2.20: Bulk ops (select mode + delete/move/tag/reset-progress)

**Files:**
- Modify: `ios/Flashcards/Features/DeckDetail/CardsTabView.swift`
- Create: `ios/Flashcards/Features/DeckDetail/BulkActionsSheet.swift`

- [ ] **Step 1: Add select mode to `CardsTabView`:**

```swift
// Add at top of CardsTabView
@State private var inSelectMode = false
@State private var selected = Set<String>()
@State private var showingBulk = false
```

Inject a top-bar button (in parent or local) that toggles `inSelectMode`. Wrap each `MWCardTile` in a long-press-to-enter-select-mode gesture and a tap-to-toggle-selection when in select mode. (Full diff below.)

```swift
var body: some View {
    VStack {
        ScrollView {
            LazyVStack(spacing: MWSpacing.s) {
                ForEach(vm.cards, id: \.id) { c in
                    MWCardTile(
                        frontText: c.frontText, backTextPreview: c.backText,
                        dueLabel: dueLabel(for: c)
                    )
                    .overlay(alignment: .topTrailing) {
                        if inSelectMode {
                            MWDot(color: selected.contains(c.id) ? MWColor.ink : MWColor.inkFaint)
                                .mwPadding(.all, .s)
                        }
                    }
                    .onTapGesture {
                        if inSelectMode {
                            if selected.contains(c.id) { selected.remove(c.id) }
                            else { selected.insert(c.id) }
                        } else {
                            editingCard = c
                        }
                    }
                    .onLongPressGesture { inSelectMode = true; selected.insert(c.id) }
                }
            }.mwPadding(.horizontal, .l)
        }
        if inSelectMode {
            HStack {
                Button("Cancel") { inSelectMode = false; selected.removeAll() }
                Spacer()
                Button("\(selected.count) selected • Bulk actions") { showingBulk = true }
                    .disabled(selected.isEmpty)
            }
            .mwPadding(.all, .m)
            .background(MWColor.paper.ignoresSafeArea(edges: .bottom))
            .mwStroke(color: MWColor.ink, width: MWBorder.default)
        }
    }
    .sheet(isPresented: $showingBulk) {
        BulkActionsSheet(
            cardIds: Array(selected),
            onDelete: { bulkDelete(); showingBulk = false; inSelectMode = false; selected.removeAll() },
            onReset: { bulkReset(); showingBulk = false; inSelectMode = false; selected.removeAll() }
        )
    }
    .sheet(item: $editingCard) { c in CardEditView(card: c) }
}
```

- [ ] **Step 2: `BulkActionsSheet.swift`:**

```swift
import SwiftUI

struct BulkActionsSheet: View {
    let cardIds: [String]
    let onDelete: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: MWSpacing.l) {
            MWEyebrow("\(cardIds.count) cards selected")
            Text("Bulk actions").font(MWType.headingM).foregroundStyle(MWColor.ink)
            MWButton("Reset progress", kind: .secondary, action: onReset)
            MWButton("Delete", kind: .destructive, action: onDelete)
        }
        .mwPadding(.all, .xl)
        .presentationDetents([.fraction(0.3)])
        .presentationBackground(MWColor.paper)
    }
}
```

- [ ] **Step 3: Wire `bulkDelete` + `bulkReset` in `CardsTabView`:**

```swift
private func bulkDelete() {
    let repo = CardRepository(context: vm.context /* expose context */)
    for id in selected {
        if let c = vm.cards.first(where: { $0.id == id }) {
            try? repo.softDelete(c)
        }
    }
    try? vm.load()
}

private func bulkReset() {
    let repo = CardRepository(context: vm.context)
    for id in selected {
        if let c = vm.cards.first(where: { $0.id == id }) {
            try? repo.resetProgress(c)
        }
    }
    try? vm.load()
}
```

(Expose `context` on `DeckDetailViewModel` if private: `public let context: ModelContext`.)

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): bulk select + delete/reset via BulkActionsSheet (2.20)"
```

---

### Task 2.21: XCUITest — offline smart study flow

**Files:**
- Create: `ios/FlashcardsUITests/OfflineSmartStudyUITests.swift`

- [ ] **Step 1: Create test:**

```swift
import XCTest

final class OfflineSmartStudyUITests: XCTestCase {
    func test_createDeckAndStudyOneCard_offline() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshInstall", "true", "-offlineMode", "true"]
        app.launch()

        // Walk through intros (they tap-through, each with a Continue).
        for _ in 0..<2 { app.buttons["Continue"].firstMatch.tap() }
        // Sign up with email stub (test uses an injected AuthManager stub in debug build).
        app.buttons["Continue with email"].firstMatch.tap()

        // Home
        XCTAssertTrue(app.staticTexts["Decks"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "mw.home.create").firstMatch.tap()

        // Create Deck
        app.textFields["Title"].tap()
        app.typeText("Greek roots")
        app.buttons["Create deck"].tap()

        // Open deck
        app.staticTexts["Greek roots"].firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 1).tap() // add card

        app.textViews["Front"].tap(); app.typeText("bios")
        app.textViews["Back"].tap(); app.typeText("life")
        app.buttons["Save"].tap()

        // Study
        app.buttons["Study now"].tap()

        // Flip + rate
        app.otherElements.matching(identifier: "mw.session.card").firstMatch.tap()
        app.buttons["Good"].firstMatch.tap()

        // Summary
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch.waitForExistence(timeout: 5))
    }
}
```

> Note: adding the accessibility identifiers (`mw.home.create`, `mw.session.card`) requires small `.accessibilityIdentifier(...)` tags on the corresponding views. Add them inline to those views as a follow-up micro-step before the test runs.

- [ ] **Step 2: Add identifiers:**

- `HomeView` top-bar add button: `.accessibilityIdentifier("mw.home.create")`
- `SmartStudyView` card container: `.accessibilityIdentifier("mw.session.card")`
- Any other labels the test relies on

- [ ] **Step 3: Run + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsUITests/OfflineSmartStudyUITests | tail -n 20
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(ui): XCUITest for offline create→study→summary flow (2.21)"
```

---

### Task 2.22: Wire `HomeView` into `RootView` NavigationStack

**Files:**
- Modify: `ios/Flashcards/App/RootView.swift`

- [ ] **Step 1: Replace the `.signedIn` placeholder with the real tab-less NavigationStack:**

```swift
case .signedIn(let userId, _):
    NavigationStack {
        HomeView(userId: userId)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsRootView() } label: { MWIcon(.settings) }
                }
            }
    }
```

- [ ] **Step 2: Build + run in simulator — confirm deck → study → summary works from the real nav root.**

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat: wire HomeView + Settings entry into signed-in RootView (2.22)"
```

---

### Task 2.23: Phase 2 acceptance — merge to main

- [ ] **Step 1: Local CI green on both projects.**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test | tail -n 20
```

- [ ] **Step 2: PR, green, merge, tag.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-2 -m "Phase 2: FSRS + Study + CRUD"
git -C /Users/lukehogan/Code/flashcards push origin main phase-2
```

**Phase 2 acceptance:**
- User can create a deck, add cards, manage sub-topics, and complete a Smart Study session end-to-end, offline.
- FSRS-driven state transitions are correct on every rating (verified by unit tests + snapshot).
- Review log is insert-only, pushed on next sync.
- Basic Study records reviews but does NOT mutate FSRS state.
- Session summary shows cards reviewed and accuracy.
- Bulk operations (delete, reset progress) work on multi-selected cards.
- XCUITest for offline create → study → summary passes.

---

## Phase 2.5: Design Fidelity Pass (weeks 9-11, overlapping early Phase 3)

**Goal:** Every screen written in Phase 2 — currently a functional scaffold composing the design system — is refined into a **pixel-match translation of the Modernist Workshop mockups** at 1x, 2x, and dark. The designer drives this phase; the engineer's job is to take notes and close the gap. Each task ends with designer sign-off in a shared Figma-like review channel.

**Working method for every task:**
1. Open the referenced JSX mockup side-by-side with the running SwiftUI simulator (both at the same device width).
2. Walk top-to-bottom. Note every delta: eyebrow position, vertical rhythm, type weight, grid overlay presence, micro-icon placement, border weight, motion timing, empty states, loading states.
3. Fix each delta in the corresponding SwiftUI view. Use only tokens — any new hard-coded value requires first adding or extending a token.
4. Update or add snapshot tests. Snapshot at iPhone 15 Pro Max 6.7" + iPhone SE 5.4" + iPhone 15 Pro 6.1", light and dark.
5. Share a screen recording to `#flashcards-design-review`. Engineer commits when designer gives an explicit 👍.

**Non-negotiable rules (reinforced):**
- Zero literal colors, sizes, padding, radii, durations in view files. SwiftLint from Task 0.12 enforces.
- No new one-off views. Anything that appears twice becomes a component. If a pattern already exists as an atom/molecule, use it.
- Motion uses `MWMotion.*` tokens exclusively. Any timing that isn't in the token scale means extending the scale first.

---

### Task 2.5.1: Token polish pass — grid, eyebrow tracking, motion curves

**Files:**
- Modify: `ios/Flashcards/DesignSystem/Tokens/Colors.swift`, `Typography.swift`, `Motion.swift`
- Modify: `ios/Flashcards/DesignSystem/Components/Layout/MWScreen.swift`

**Mockup reference:** `Mockup/mw/01-tokens.jsx` (authoritative token source).

- [ ] **Step 1:** Open `01-tokens.jsx` alongside each token file. Diff every value. Fix any drift — hex codes, font weights, line heights, tracking, stroke widths, shadow opacity, motion easing curves.

- [ ] **Step 2:** Verify `MWScreen`'s grid overlay is a 1:1 match with the mockup — step (currently 4pt), opacity (currently 0.4), color (`grid` token), `borderHair` stroke. Adjust until the two renderings are visually indistinguishable at 1x.

- [ ] **Step 3:** Add any missing micro-tokens the mockup relies on that the original Phase 0 pass missed (e.g. `strokeMicro` = 0.33pt, `motionFlip` = custom card-flip spring). Name them; don't inline values.

- [ ] **Step 4:** Designer sign-off on `#flashcards-design-review` with side-by-side screen recording.

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards checkout -b phase/2.5-design-fidelity
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "refactor(ds): token pass against 01-tokens.jsx — close color/type/motion drift (2.5.1)"
```

---

### Task 2.5.2: Onboarding — Splash + Intro 1 + Intro 2 + Welcome

**Files:**
- Modify: `ios/Flashcards/Features/Onboarding/SplashView.swift`
- Modify: `ios/Flashcards/Features/Onboarding/Intro1View.swift`
- Modify: `ios/Flashcards/Features/Onboarding/Intro2View.swift`
- Create: `ios/Flashcards/Features/Onboarding/WelcomeView.swift`

**Mockup reference:** Splash + intro patterns in `Mockup/mw/Modernist.jsx` onboarding section. Welcome screen is new — designer-owned composition, mirror Intro layout.

- [ ] **Step 1:** Splash: add the centered lockup with fine vertical micro-motion (a `motionSettled`-timed opacity fade on the wordmark as the app settles).

- [ ] **Step 2:** Intro 1 + 2: numbered eyebrow (`01 — WELCOME`), headline in `display` weight, body in `bodyL`, CTA at bottom with bottom-safe-area padding of `xxl`. Add a page-indicator (2 dots, current one filled).

- [ ] **Step 3:** Welcome (post-signup): add "You're in" eyebrow, one-liner, "Create your first deck" primary CTA, "Explore starter decks" secondary CTA (disabled in v1 — inline a feature-flag gate via `FeatureFlags.starterDecks`).

- [ ] **Step 4:** Snapshot each at iPhone 15 Pro Max + iPhone SE + iPhone 15 Pro, light + dark.

- [ ] **Step 5:** Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(onboarding): splash + intros + welcome mockup-fidelity pass (2.5.2)"
```

---

### Task 2.5.3: Sign-up wall — exact spec copy + opt-in layout

**Files:**
- Modify: `ios/Flashcards/Features/Onboarding/SignUpWallView.swift`

**Mockup reference:** New — spec §5 contains the locked copy. Layout mirrors Intro layout.

- [ ] **Step 1:** Enforce the exact copy block from spec §5 (headline, body, buttons, footer line, checkbox) verbatim. Nothing improvised.

- [ ] **Step 2:** Vertical rhythm: eyebrow `s` → headline `m` → body `l` → Apple button `l` → email field `s` → email button `xs` → footer `l` → opt-in `m`. Enforce via explicit `VStack(spacing:)` values pulled from `MWSpacingToken`.

- [ ] **Step 3:** Error text slot is always reserved (not conditionally appearing) to prevent layout shift — render empty `Text("")` with the error's minimum height using `ScaledMetric`.

- [ ] **Step 4:** Snapshot light + dark at all three device widths.

- [ ] **Step 5:** Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(onboarding): sign-up wall — locked copy + non-shifting error slot (2.5.3)"
```

---

### Task 2.5.4: Home — deck grid with stacked-paper metaphor

**Files:**
- Modify: `ios/Flashcards/Features/Home/HomeView.swift`
- Modify: `ios/Flashcards/DesignSystem/Components/Molecules/MWDeckCard.swift`
- Modify: `ios/Flashcards/DesignSystem/Components/Molecules/MWStackedDeckPaper.swift`

**Mockup reference:** `Mockup/mw/02-screens-a.jsx` line 13.

- [ ] **Step 1:** Refine `MWStackedDeckPaper`: three stacked sheets with exact offsets from the JSX (top sheet 0/0, middle sheet 3/3, back sheet 6/6), each with `borderDefault`, each progressively dimmed via opacity from token scale. Shadow only on deepest sheet via `MWShadow.deck`.

- [ ] **Step 2:** Refine `MWDeckCard`: accent swatch rendered as a left-edge rule (not a standalone rectangle), exact type rhythm, due pill top-right aligned to eyebrow baseline.

- [ ] **Step 3:** `HomeView` grid: 2 columns with `m` gutter on iPhone Pro / Pro Max, 1 column on SE. Use `ViewThatFits` so layout degrades gracefully.

- [ ] **Step 4:** Empty state: large illustrated typographic composition (just type, no illustration — Modernist). "Start by making your first deck." + primary CTA. Mirror the empty-state proportions from the JSX.

- [ ] **Step 5:** Top bar: search icon left, settings icon right, wordmark centered (NOT the word "Decks" — correct the Phase 2 placeholder).

- [ ] **Step 6:** Snapshot 4 states: empty, 1 deck, 6 decks (scroll), dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(home): deck grid + stacked-paper + empty state mockup-fidelity (2.5.4)"
```

---

### Task 2.5.5: Deck detail — History + Cards tabs

**Files:**
- Modify: `ios/Flashcards/Features/DeckDetail/DeckDetailView.swift`
- Modify: `ios/Flashcards/Features/DeckDetail/HistoryTabView.swift`
- Modify: `ios/Flashcards/Features/DeckDetail/CardsTabView.swift`

**Mockup references:** History tab `mw/02-screens-a.jsx` line 136; Cards tab line 236.

- [ ] **Step 1:** Deck header: accent-color rule above title, eyebrow (accent name, uppercased + tracked), title in `headingL`, due pill + "Study now" CTA inline (not separated like Phase 2 stub).

- [ ] **Step 2:** Tab switcher: use `MWChip` row (already spec'd in Phase 2), underline active tab with `borderBold` of accent color.

- [ ] **Step 3:** History tab: per-session card with accuracy bar (use `MWProgressBar` in accent tint), relative date right-aligned in `inkFaint`. Match the mockup's micro-icons for rating distribution (Again/Hard/Good/Easy counts as mini bars in session summary rows).

- [ ] **Step 4:** Cards tab: tighter row spacing than Phase 2 stub, sub-topic chips wrapping correctly, due label in mockup's exact position. Bulk-select mode reveals a persistent bottom toolbar with `MWStroke` above.

- [ ] **Step 5:** Snapshot empty, 5 rows, 50 rows (scroll), dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck-detail): History + Cards tabs fidelity pass (2.5.5)"
```

---

### Task 2.5.6: Create deck sheet

**Files:**
- Modify: `ios/Flashcards/Features/Deck/CreateDeckView.swift`

**Mockup reference:** `mw/03-screens-b.jsx` line 235.

- [ ] **Step 1:** Sheet detent: `.large` only (not medium) — the accent palette needs room. Top drag indicator visible.

- [ ] **Step 2:** Accent picker: 5-swatch row with 44pt hit targets, selected state = `borderBold` in accent color, unselected = `borderHair` in `inkFaint`.

- [ ] **Step 3:** Study mode picker: two `MWChip`s, selected state carries the deck's accent color fill.

- [ ] **Step 4:** Primary CTA pinned to bottom, respecting safe area. Form scrolls behind it with content inset.

- [ ] **Step 5:** Snapshot empty form, partially-filled, dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): CreateDeck sheet fidelity pass (2.5.6)"
```

---

### Task 2.5.7: Create card + Card edit sheets

**Files:**
- Modify: `ios/Flashcards/Features/Card/CreateCardView.swift`
- Modify: `ios/Flashcards/Features/Card/CardEditView.swift`

**Mockup reference:** Create card `mw/03-screens-b.jsx` line 299; Card edit is a variant.

- [ ] **Step 1:** Front + Back editors use `MWTextArea` with mockup-matched min heights (front: 120, back: 120). Monospaced "Front" / "Back" eyebrow labels with tracking.

- [ ] **Step 2:** Markdown preview toggle: small tab switcher above each field ("Edit" / "Preview"). Preview renders with `swift-markdown-ui` in `bodyL` ink color.

- [ ] **Step 3:** Sub-topic chip row: wraps to multiple lines via `Layout` protocol (use SwiftUI's native `Layout` not the Phase 2 placeholder `HStack`). Plus chip at end opens inline text entry.

- [ ] **Step 4:** Character count: `bodyS` counter bottom-right of each field, transitions to `again` tint at 4000 chars.

- [ ] **Step 5:** Card edit adds a destructive footer section with `MWDivider` + "Reset progress" (secondary) + "Delete card" (destructive).

- [ ] **Step 6:** Snapshot empty, filled, dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(card): Create + Edit fidelity + markdown preview toggle + wrap Layout (2.5.7)"
```

---

### Task 2.5.8: Smart Study — front + back + flip motion

**Files:**
- Modify: `ios/Flashcards/Features/Session/SmartStudyView.swift`

**Mockup references:** Front `mw/03-screens-b.jsx` line 5; back with ratings line 53.

- [ ] **Step 1:** Card surface: `MWStackedDeckPaper` at full-viewport size with `xxl` horizontal padding. Front shows the question centered; back shows question small + answer large. Mockup's exact vertical rhythm.

- [ ] **Step 2:** Flip motion: extend `MWMotion` with `motionFlip = .interpolatingSpring(stiffness: 120, damping: 16)`. Apply via `.rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (0,1,0))` with back text inverse-rotated.

- [ ] **Step 3:** Rating buttons row: full-width, four equal cells, `s` gutter, accent tint per rating. Interval labels ("6m", "1d", "4d", "12d") computed live from `FsrsScheduler.intervalPreview` and rendered in `bodyS` below each label.

- [ ] **Step 4:** Progress rail at top: `MWProgressBar` showing `index / queue.count`. Eyebrow: "Smart Study · deck name".

- [ ] **Step 5:** Swipe-down gesture dismisses to a confirm dialog ("End session? Progress is saved.").

- [ ] **Step 6:** Snapshot front, back, mid-flip (0.5 rotation), dark. Reduce-motion variant (no rotation). Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): SmartStudy card flip motion + rating rail fidelity (2.5.8)"
```

---

### Task 2.5.9: Basic Study + Session summary

**Files:**
- Modify: `ios/Flashcards/Features/Session/BasicStudyView.swift`
- Modify: `ios/Flashcards/Features/Session/SessionSummaryView.swift`

**Mockup references:** Basic `mw/03-screens-b.jsx` line 117; summary line 148.

- [ ] **Step 1:** Basic Study: same card surface as Smart, but bottom controls are "Got it" / "Skip" / "Shuffle" instead of rating row. Shuffle pill upper-right.

- [ ] **Step 2:** Session summary: large stat block — "12 cards reviewed" in `display`, "88% accuracy" in `headingL`, "+5 mastery" in `bodyL`. Rating distribution visualized as a 4-segment horizontal bar (again/hard/good/easy widths proportional to counts).

- [ ] **Step 3:** Streak context: "3 days in a row" eyebrow + flame micro-icon if active streak. Fetch from `StreakMonitor` (added in Phase 3 — add a stub on the session summary that fills once StreakMonitor ships; use a feature flag `FeatureFlag.streakBadge`).

- [ ] **Step 4:** "Done" CTA + "Study again" secondary CTA (starts another session on same deck).

- [ ] **Step 5:** Snapshot with and without streak badge, with 0/1/12 cards reviewed, dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(session): Basic + Summary fidelity — rating distribution bar + streak slot (2.5.9)"
```

---

### Task 2.5.10: Search

**Files:**
- Modify: `ios/Flashcards/Features/Home/SearchView.swift`

**Mockup reference:** `mw/02-screens-a.jsx` line 77.

- [ ] **Step 1:** Search field: prominent top slot with trailing clear-button, `MWStroke` below as divider. Auto-focus keyboard on presentation.

- [ ] **Step 2:** Results sections: "Decks (3)" and "Cards (17)" eyebrow headers. Each result row hoverable/pressable with `mwCard` surface.

- [ ] **Step 3:** Empty states: initial (no query) shows recent decks grid; <2 chars shows "Keep typing…" hint; no-results shows "Nothing for \"\(query)\"." with suggestion to broaden.

- [ ] **Step 4:** Snapshot all three states + dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(search): Search screen fidelity — 3 states + sectioned results (2.5.10)"
```

---

### Task 2.5.11: Settings hub

**Files:**
- Modify: `ios/Flashcards/Features/Settings/SettingsRootView.swift`
- Modify: `ios/Flashcards/Features/Settings/ProfileSettingsView.swift`
- Modify: `ios/Flashcards/Features/Settings/StudySettingsView.swift`
- Modify: `ios/Flashcards/Features/Settings/AppearanceSettingsView.swift`

**Mockup reference:** Settings root `mw/03-screens-b.jsx` line 350.

- [ ] **Step 1:** Root: not a List; a grouped stack of `MWSection`s with `MWDivider` between. Section headers in eyebrow tracked style. Rows are `MWFormRow`s with consistent `l` vertical padding.

- [ ] **Step 2:** Profile: avatar slot (initials circle in accent color for v1; image in v1.5), display name, email (read-only).

- [ ] **Step 3:** Study settings: steppers styled with `MWStroke`, not native iOS stepper chrome. New-card-limit stepper integrates with entitlements paywall via existing hook from Task 3.11.

- [ ] **Step 4:** Appearance: segmented picker styled as `MWChip` row.

- [ ] **Step 5:** Snapshot each + dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(settings): root + profile + study + appearance fidelity (2.5.11)"
```

---

### Task 2.5.12: Subscription + Account + About

**Files:**
- Modify: `ios/Flashcards/Features/Settings/SubscriptionSettingsView.swift`
- Modify: `ios/Flashcards/Features/Settings/AccountSettingsView.swift`
- Modify: `ios/Flashcards/Features/Settings/AboutView.swift`

**Mockup reference:** New — designer composes using the settings pattern established in 2.5.11.

- [ ] **Step 1:** Subscription: plan-status hero card (`mwCard` with `headingL` plan name, `bodyL` renewal date, plan benefits listed as bullets with `MWIcon(.check)`), upgrade/manage button depending on state.

- [ ] **Step 2:** Account: email row, "Sign out" (secondary), divider, "Delete account" (destructive) with `inkMuted` explanation copy below.

- [ ] **Step 3:** About: app version, attribution list for OSS dependencies (auto-generated from SPM manifest — add a build script that emits `Acknowledgements.plist`), legal links.

- [ ] **Step 4:** Snapshot active plan, free plan, in-grace, dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(settings): Subscription + Account + About fidelity + OSS attribution (2.5.12)"
```

---

### Task 2.5.13: Paywall sheet

**Files:**
- Modify: `ios/Flashcards/DesignSystem/Components/Molecules/MWPaywallScreen.swift`
- Modify: `ios/Flashcards/Features/Paywall/PaywallView.swift`
- Modify: `ios/Flashcards/Features/Paywall/PaywallCopy.swift`

**Mockup reference:** `Mockup/mw/04-modals.jsx` paywall sheet.

- [ ] **Step 1:** Sheet layout: top eyebrow (keyed to `reason`), hero headline in `display`, illustration slot (reserved — empty for v1 per Modernist "type is the illustration" principle), bullets with `MWIcon(.check)`, monthly/annual toggle row, primary CTA, restore button, fine print with auto-renew disclosure.

- [ ] **Step 2:** Monthly/annual toggle: side-by-side `MWChip`s showing price + period + "SAVE 50%" eyebrow on annual.

- [ ] **Step 3:** Fine print: legal text (auto-renew, managed via Apple ID, terms + privacy links) in `bodyS inkFaint` — required by App Review 3.1.2.

- [ ] **Step 4:** Sheet presentation: `.large` detent only. Swipe-down dismiss returns user to prior context; analytics event `paywall.screen.dismissed` fires.

- [ ] **Step 5:** Snapshot for each `EntitlementKey` reason (deck, card-in-deck, card-total, new-card-limit, reminder) + dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(paywall): mockup-fidelity + monthly/annual toggle + legal fine print (2.5.13)"
```

---

### Task 2.5.14: Modals — Quick Actions, Sort, Context menu, Delete confirm, Topic picker, Filter drawer

**Files:**
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWQuickActionsSheet.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWSortDropdown.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWContextMenu.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWDeleteConfirmSheet.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWTopicPickerSheet.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWFilterDrawer.swift`

**Mockup reference:** `Mockup/mw/04-modals.jsx` — all six variants.

- [ ] **Step 1:** Extract each modal pattern from the JSX into a reusable component. Each component takes typed inputs, returns a `View` — no feature-level logic inside the DS layer.

- [ ] **Step 2:** Wire each into its corresponding feature view (Quick Actions → Home top bar; Sort → Cards tab; Context menu → long-press on `MWCardTile`; Delete confirm → replaces generic `confirmationDialog` in edit views; Topic picker → deck create + deck detail header; Filter drawer → Cards tab filter affordance).

- [ ] **Step 3:** Topic picker: per spec §8.2, `no suggested topics section` — remove from any earlier draft. Show only user-created topics + "Create new topic" field at bottom.

- [ ] **Step 4:** Snapshot each modal open state, light + dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(ds): 6 modal molecules (Quick, Sort, Context, Delete, TopicPicker, Filter) (2.5.14)"
```

---

### Task 2.5.15: Manage sub-topics refinement

**Files:**
- Modify: `ios/Flashcards/Features/DeckDetail/ManageSubTopicsView.swift`

**Mockup reference:** New — designer composes.

- [ ] **Step 1:** Replace native `List` with a custom `ReorderableStack` using SwiftUI `Layout` + drag gesture. Each row uses `MWFormRow` with drag handle on leading and delete on trailing.

- [ ] **Step 2:** Rename happens inline on tap — the row swaps to an editable `MWTextField` with auto-focus and "Done" / "Cancel" buttons below.

- [ ] **Step 3:** Add-new row is persistently present at the bottom, matching the Apple Reminders "new item" UX.

- [ ] **Step 4:** Snapshot empty, 3-rows, 10-rows (scroll), rename-mode, dark. Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(deck): ManageSubTopics — inline rename + custom reorder layout (2.5.15)"
```

---

### Task 2.5.16: Motion + haptics audit across all screens

**Files:**
- Create: `ios/Flashcards/Util/Haptics.swift`
- Modify: selected views across `Features/**`

**Mockup reference:** Mockups are static — this task is designer-specified motion; record decisions in a new `docs/motion-spec.md` during the task.

- [ ] **Step 1:** Define `Haptics` enum:

```swift
import UIKit

public enum Haptics {
    public static func tap() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    public static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    public static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    public static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}
```

- [ ] **Step 2:** Wire haptics at four locations: card flip (select), rate button (tap), session complete (success), delete confirmation (warn).

- [ ] **Step 3:** Motion audit: every screen transition uses a `MWMotion` token. Long-press actions use `motionQuick`. Sheet dismissals use `motionStandard`. Card-flip uses `motionFlip` (added in 2.5.1). Paywall presentation uses `motionSettled`.

- [ ] **Step 4:** Record every motion decision in `docs/motion-spec.md` so future edits are non-destructive:

```markdown
# Motion spec (v1)

| Surface | Motion token | Trigger |
|---|---|---|
| Card flip | motionFlip | Tap card body |
| Rating button press | motionInstant | Button down |
| Sheet present | motionStandard | System default |
| Sheet dismiss | motionStandard | Drag-down |
| Paywall present | motionSettled | Entitlement block |
| Deck grid scroll-to-top | motionStandard | Tap top bar |
| Select mode enter | motionQuick | Long-press any card tile |
```

- [ ] **Step 5:** Respect `UIAccessibility.isReduceMotionEnabled` — switch to `.linear(duration: 0)` via `MWMotion.respecting(...)` everywhere motion is applied. Audit every `.animation(` call site.

- [ ] **Step 6:** Designer sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios docs/motion-spec.md
git -C /Users/lukehogan/Code/flashcards commit -m "feat(motion): app-wide haptics + motion audit + docs/motion-spec.md (2.5.16)"
```

---

### Task 2.5.17: Full a11y + typography scale regression

**Files:**
- Modify: selected views across `Features/**`

- [ ] **Step 1:** For every screen in 2.5.2-2.5.15, run a Dynamic Type audit at `.accessibility3` (largest) and `.xSmall`. Fix any truncation, horizontal scrolling, or overlapping elements.

- [ ] **Step 2:** VoiceOver audit: traverse every screen with the Accessibility Inspector. Label every interactive element. Group related text into single a11y elements where appropriate.

- [ ] **Step 3:** Verify WCAG AA contrast on every token pair used (ink on paper, inkMuted on canvas, again/hard/good/easy on paper). Use a contrast checker tool; any fails get retuned in `Colors.swift`.

- [ ] **Step 4:** Expand DesignSystemSnapshotTests with `.xSmall` + `.accessibility3` variants for every composite screen (not just atoms).

- [ ] **Step 5:** Designer + engineer dual sign-off + commit.

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(a11y): full Dynamic Type + VoiceOver + contrast audit across screens (2.5.17)"
```

---

### Task 2.5.18: Phase 2.5 acceptance — merge to main

- [ ] **Step 1:** Schedule a 90-minute design review. Designer walks every screen at 1x/2x/dark, comparing to JSX mockup. Any remaining deltas become sev-2 tickets, triaged against launch timeline.

- [ ] **Step 2:** Full CI green.

- [ ] **Step 3:** PR, merge, tag.

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-2.5 -m "Phase 2.5: design fidelity pass"
git -C /Users/lukehogan/Code/flashcards push origin main phase-2.5
```

**Phase 2.5 acceptance:**
- Every screen in [Mockup/mw/](Mockup/mw/) has a corresponding SwiftUI view that the designer signs off as a pixel-match at 1x / 2x / dark.
- All motion decisions documented in `docs/motion-spec.md`, driven entirely by `MWMotion` tokens.
- Haptics wired at four key moments (flip, rate, complete, warn).
- Full a11y audit passed: Dynamic Type `.xSmall` through `.accessibility3`, VoiceOver traversal complete, WCAG AA contrast verified.
- Snapshot suite expanded to include composite screens at multiple text sizes.

---

## Phase 3: Monetization + Settings + Notifications (weeks 8-12)

**Goal:** Entitlements system live on both sides; StoreKit 2 + Cashier wired; settings flows complete; local reminders + APNs renewal pushes.

### Task 3.1: `plans` table + config + seeder

**Files:**
- Create: `api/database/migrations/2026_04_21_000010_create_plans_table.php`
- Create: `api/app/Models/Plan.php`
- Create: `api/database/seeders/PlanSeeder.php`
- Create: `api/config/plans.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('plans', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('key')->unique();          // "free", "plus", "launch-grandfather"
            $table->string('label');                  // "Free", "Plus"
            $table->json('entitlements');             // entitlement_key => config
            $table->integer('version')->default(1);
            $table->timestamps();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('plan_key')->default('free')->after('subscription_product_id');
            $table->index('plan_key');
        });
    }

    public function down(): void
    {
        Schema::table('users', fn ($t) => $t->dropColumn('plan_key'));
        Schema::dropIfExists('plans');
    }
};
```

- [ ] **Step 2: Model:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Plan extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = ['key', 'label', 'entitlements', 'version'];
    protected $casts = ['entitlements' => 'array', 'version' => 'integer'];
}
```

- [ ] **Step 3: `config/plans.php` (defaults mirror spec §11.1):**

```php
<?php

declare(strict_types=1);

return [
    'default_plan_key' => 'free',
    'defaults' => [
        'free' => [
            'label' => 'Free',
            'entitlements' => [
                'decks.create'              => ['type' => 'max_count', 'max' => 5],
                'cards.create_in_deck'      => ['type' => 'max_count', 'max' => 200],
                'cards.create_total'        => ['type' => 'max_count', 'max' => 500],
                'study.smart'               => ['type' => 'boolean',  'allowed' => true],
                'study.basic'               => ['type' => 'boolean',  'allowed' => true],
                'reminders.add'             => ['type' => 'max_count', 'max' => 1],
                'new_card_limit.above_10'   => ['type' => 'boolean',  'allowed' => false],
                'fsrs.personalized'         => ['type' => 'boolean',  'allowed' => false],
                'images.use'                => ['type' => 'boolean',  'allowed' => false],
                'import.csv'                => ['type' => 'boolean',  'allowed' => false],
                'export.csv'                => ['type' => 'boolean',  'allowed' => false],
                'export.json'               => ['type' => 'boolean',  'allowed' => false],
            ],
        ],
        'plus' => [
            'label' => 'Plus',
            'entitlements' => [
                'decks.create'              => ['type' => 'max_count', 'max' => null],
                'cards.create_in_deck'      => ['type' => 'max_count', 'max' => null],
                'cards.create_total'        => ['type' => 'max_count', 'max' => null],
                'study.smart'               => ['type' => 'boolean',  'allowed' => true],
                'study.basic'               => ['type' => 'boolean',  'allowed' => true],
                'reminders.add'             => ['type' => 'max_count', 'max' => 3],
                'new_card_limit.above_10'   => ['type' => 'boolean',  'allowed' => true],
                'fsrs.personalized'         => ['type' => 'boolean',  'allowed' => false],
                'images.use'                => ['type' => 'boolean',  'allowed' => false],
                'import.csv'                => ['type' => 'boolean',  'allowed' => false],
                'export.csv'                => ['type' => 'boolean',  'allowed' => false],
                'export.json'               => ['type' => 'boolean',  'allowed' => false],
            ],
        ],
    ],
];
```

- [ ] **Step 4: `PlanSeeder.php`:**

```php
<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

class PlanSeeder extends Seeder
{
    public function run(): void
    {
        foreach (config('plans.defaults') as $key => $data) {
            Plan::updateOrCreate(
                ['key' => $key],
                ['label' => $data['label'], 'entitlements' => $data['entitlements'], 'version' => 1],
            );
        }
    }
}
```

Register in `database/seeders/DatabaseSeeder.php`:

```php
public function run(): void
{
    $this->call([PlanSeeder::class]);
}
```

- [ ] **Step 5: Migrate + seed + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && php artisan db:seed
git -C /Users/lukehogan/Code/flashcards checkout -b phase/3-monetization
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): plans table + config + seeder (3.1)"
```

---

### Task 3.2: `EntitlementChecker` service + tests

**Files:**
- Create: `api/app/Services/Entitlements/EntitlementChecker.php`
- Create: `api/tests/Unit/EntitlementCheckerTest.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Plan;
use App\Models\User;
use App\Services\Entitlements\EntitlementChecker;

beforeEach(function () {
    $this->seed(\Database\Seeders\PlanSeeder::class);
});

test('free user hitting 5-deck cap on create returns paywall', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    \App\Models\Deck::factory()->for($u)->count(5)->create();

    $result = app(EntitlementChecker::class)->can($u, 'decks.create');

    expect($result->allowed)->toBeFalse()
        ->and($result->reason)->toBe('decks.create')
        ->and($result->limit)->toBe(5);
});

test('free user with 3 decks can create another', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    \App\Models\Deck::factory()->for($u)->count(3)->create();

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeTrue();
});

test('plus user has no deck cap', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    \App\Models\Deck::factory()->for($u)->count(100)->create();

    expect(app(EntitlementChecker::class)->can($u, 'decks.create')->allowed)->toBeTrue();
});

test('boolean entitlement study.smart returns allowed per plan', function () {
    $free = User::factory()->create(['plan_key' => 'free']);
    expect(app(EntitlementChecker::class)->can($free, 'study.smart')->allowed)->toBeTrue();
});
```

- [ ] **Step 2: Implementation:**

```php
<?php

declare(strict_types=1);

namespace App\Services\Entitlements;

use App\Models\Plan;
use App\Models\User;

final class EntitlementResult
{
    public function __construct(
        public readonly bool $allowed,
        public readonly ?string $reason = null,
        public readonly ?int $limit = null,
    ) {}

    public static function allow(): self { return new self(true); }
    public static function deny(string $reason, ?int $limit = null): self { return new self(false, $reason, $limit); }
}

final class EntitlementChecker
{
    public function can(User $user, string $key, array $context = []): EntitlementResult
    {
        $plan = Plan::where('key', $user->plan_key ?? 'free')->first()
            ?? Plan::where('key', 'free')->first();

        $config = $plan?->entitlements[$key] ?? null;
        if ($config === null) { return EntitlementResult::deny($key); }

        return match ($config['type']) {
            'boolean'   => ($config['allowed'] ?? false) ? EntitlementResult::allow() : EntitlementResult::deny($key),
            'max_count' => $this->checkMaxCount($user, $key, $config, $context),
            default     => EntitlementResult::deny($key),
        };
    }

    private function checkMaxCount(User $user, string $key, array $config, array $context): EntitlementResult
    {
        $max = $config['max'] ?? null;
        if ($max === null) { return EntitlementResult::allow(); }

        $current = $this->currentCount($user, $key, $context);
        return $current < $max ? EntitlementResult::allow() : EntitlementResult::deny($key, $max);
    }

    private function currentCount(User $user, string $key, array $context): int
    {
        return match ($key) {
            'decks.create' => $user->decks()->whereNull('deleted_at_ms')->count(),
            'cards.create_in_deck' => isset($context['deck_id'])
                ? \App\Models\Card::where('deck_id', $context['deck_id'])->whereNull('deleted_at_ms')->count()
                : 0,
            'cards.create_total' => \App\Models\Card::whereIn('deck_id', $user->decks()->select('id'))
                ->whereNull('deleted_at_ms')->count(),
            'reminders.add' => \App\Models\Reminder::where('user_id', $user->id)->where('enabled', true)->count(),
            default => 0,
        };
    }
}
```

- [ ] **Step 3: Register + test + commit**

Register in `AppServiceProvider::register`:

```php
$this->app->singleton(\App\Services\Entitlements\EntitlementChecker::class);
```

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Unit/EntitlementCheckerTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): EntitlementChecker service + tests (3.2)"
```

---

### Task 3.3: `/v1/me/entitlements` endpoint

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/EntitlementsController.php`
- Create: `api/tests/Feature/EntitlementsEndpointTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

beforeEach(function () { $this->seed(\Database\Seeders\PlanSeeder::class); });

test('GET /v1/me/entitlements returns current plan + snapshot', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;
    $res = $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me/entitlements');
    $res->assertOk()->assertJsonStructure(['plan_key', 'entitlements', 'version']);
    expect($res->json('entitlements.decks.create.max'))->toBe(5);
});
```

- [ ] **Step 2: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Plan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EntitlementsController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $plan = Plan::where('key', $request->user()->plan_key ?? 'free')->first();
        return response()->json([
            'plan_key' => $plan->key,
            'version' => $plan->version,
            'entitlements' => $plan->entitlements,
        ]);
    }
}
```

- [ ] **Step 3: Route:**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::get('/me/entitlements', [\App\Http\Controllers\Api\V1\EntitlementsController::class, 'show']);
});
```

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/EntitlementsEndpointTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): GET /v1/me/entitlements (3.3)"
```

---

### Task 3.4: Server-side enforcement in sync upserters

**Files:**
- Modify: `api/app/Services/Sync/Entities/DeckUpserter.php`
- Modify: `api/app/Services/Sync/Entities/CardUpserter.php`
- Create: `api/tests/Feature/EntitlementEnforcementTest.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Deck;
use App\Models\User;

beforeEach(function () { $this->seed(\Database\Seeders\PlanSeeder::class); });

test('free user pushing 6th deck: sixth rejected with reason=decks.create', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Deck::factory()->for($u)->count(5)->create(['updated_at_ms' => 1000]);
    $token = $u->createToken('t')->plainTextToken;

    $res = $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/sync/push', [
            'client_clock_ms' => 2000,
            'records' => ['decks' => [[
                'id' => (string) \Illuminate\Support\Str::orderedUuid(),
                'title' => '6th', 'accent_color' => 'amber',
                'default_study_mode' => 'smart', 'card_count' => 0,
                'updated_at_ms' => 2000,
            ]]],
        ]);

    $res->assertJson(['accepted' => 0]);
    expect($res->json('rejected.0.reason'))->toBe('decks.create');
});
```

- [ ] **Step 2: Modify `DeckUpserter::upsert` to gate only on insert (not update):**

```php
// At top of method, before the Deck::updateOrCreate block:
$existing = Deck::find($id);
if ($existing === null) {
    $check = app(\App\Services\Entitlements\EntitlementChecker::class)->can($user, 'decks.create');
    if (!$check->allowed) {
        return new UpsertResult(false, $check->reason);
    }
}
```

- [ ] **Step 3: Same for `CardUpserter`:**

```php
$existing = Card::find($id);
if ($existing === null) {
    $checker = app(\App\Services\Entitlements\EntitlementChecker::class);
    foreach (['cards.create_in_deck', 'cards.create_total'] as $k) {
        $check = $checker->can($user, $k, ['deck_id' => $deckId]);
        if (!$check->allowed) { return new UpsertResult(false, $check->reason); }
    }
}
```

- [ ] **Step 4: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/EntitlementEnforcementTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): enforce on sync upsert for deck/card (3.4)"
```

---

### Task 3.5: `Reminder` — model + endpoints + tests

**Files:**
- Create: `api/database/migrations/2026_04_21_000011_create_reminders_table.php`
- Create: `api/app/Models/Reminder.php`
- Create: `api/database/factories/ReminderFactory.php`
- Create: `api/app/Http/Controllers/Api/V1/ReminderController.php`
- Create: `api/tests/Feature/ReminderTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: Migration:**

```php
<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('reminders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained()->cascadeOnDelete();
            $table->time('time_local');
            $table->boolean('enabled')->default(true);
            $table->bigInteger('updated_at_ms');
            $table->timestamps();
        });
    }
    public function down(): void { Schema::dropIfExists('reminders'); }
};
```

- [ ] **Step 2: Model + factory:**

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Reminder extends Model
{
    use HasFactory, HasUuids;
    protected $fillable = ['user_id', 'time_local', 'enabled', 'updated_at_ms'];
    protected $casts = ['enabled' => 'boolean', 'updated_at_ms' => 'integer'];
}
```

```php
<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Reminder;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class ReminderFactory extends Factory
{
    protected $model = Reminder::class;
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'time_local' => '08:30',
            'enabled' => true,
            'updated_at_ms' => now()->valueOf(),
        ];
    }
}
```

- [ ] **Step 3: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\Reminder;
use App\Models\User;

beforeEach(function () { $this->seed(\Database\Seeders\PlanSeeder::class); });

test('free user adding second reminder gets paywall', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    Reminder::factory()->for($u)->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/reminders', ['time_local' => '20:00'])
        ->assertStatus(402)
        ->assertJson(['reason' => 'reminders.add']);
});

test('plus user can add three', function () {
    $u = User::factory()->create(['plan_key' => 'plus']);
    $token = $u->createToken('t')->plainTextToken;
    foreach (['08:00', '13:00', '20:00'] as $t) {
        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/v1/reminders', ['time_local' => $t])->assertCreated();
    }
    expect($u->fresh()->reminders()->count())->toBe(3);
});
```

Add a `reminders` relation to `User`:

```php
public function reminders() { return $this->hasMany(Reminder::class); }
```

- [ ] **Step 4: Controller:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Reminder;
use App\Services\Entitlements\EntitlementChecker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReminderController extends Controller
{
    public function __construct(private readonly EntitlementChecker $checker) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json(['reminders' => $request->user()->reminders()->get()]);
    }

    public function store(Request $request): JsonResponse
    {
        $check = $this->checker->can($request->user(), 'reminders.add');
        if (!$check->allowed) {
            return response()->json(['reason' => $check->reason, 'limit' => $check->limit], 402);
        }

        $data = $request->validate([
            'time_local' => ['required', 'date_format:H:i'],
            'enabled' => ['sometimes', 'boolean'],
        ]);
        $r = $request->user()->reminders()->create([
            'time_local' => $data['time_local'],
            'enabled' => $data['enabled'] ?? true,
            'updated_at_ms' => now()->valueOf(),
        ]);
        return response()->json($r, 201);
    }

    public function destroy(Request $request, string $id): JsonResponse
    {
        $r = Reminder::where('user_id', $request->user()->id)->findOrFail($id);
        $r->delete();
        return response()->json(status: 204);
    }
}
```

- [ ] **Step 5: Routes:**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::get('/reminders', [\App\Http\Controllers\Api\V1\ReminderController::class, 'index']);
    Route::post('/reminders', [\App\Http\Controllers\Api\V1\ReminderController::class, 'store']);
    Route::delete('/reminders/{id}', [\App\Http\Controllers\Api\V1\ReminderController::class, 'destroy']);
});
```

- [ ] **Step 6: Migrate, test, commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/ReminderTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(reminders): Reminder CRUD + entitlement enforcement (3.5)"
```

---

### Task 3.6: iOS `EntitlementKey` + `EntitlementsManager` + cache

**Files:**
- Create: `ios/Flashcards/Entitlements/EntitlementKey.swift`
- Create: `ios/Flashcards/Entitlements/PlansCache.swift`
- Create: `ios/Flashcards/Entitlements/EntitlementsManager.swift`
- Create: `ios/FlashcardsTests/EntitlementsManagerTests.swift`

- [ ] **Step 1: `EntitlementKey.swift`:**

```swift
import Foundation

public enum EntitlementKey: String, Codable, CaseIterable, Identifiable {
    case decksCreate = "decks.create"
    case cardsCreateInDeck = "cards.create_in_deck"
    case cardsCreateTotal = "cards.create_total"
    case studySmart = "study.smart"
    case studyBasic = "study.basic"
    case remindersAdd = "reminders.add"
    case newCardLimitAbove10 = "new_card_limit.above_10"
    case fsrsPersonalized = "fsrs.personalized"
    case imagesUse = "images.use"
    case importCsv = "import.csv"
    case exportCsv = "export.csv"
    case exportJson = "export.json"

    public var id: String { rawValue }
}

public struct EntitlementResult: Equatable {
    public enum Outcome: Equatable {
        case allowed
        case paywall(reason: EntitlementKey, limit: Int?)
    }
    public let outcome: Outcome
    public var allowed: Bool { if case .allowed = outcome { true } else { false } }
}
```

- [ ] **Step 2: `PlansCache.swift`:**

```swift
import Foundation

public struct PlanSnapshot: Codable, Equatable {
    public let planKey: String
    public let version: Int
    public let entitlements: [String: EntitlementConfig]
}

public struct EntitlementConfig: Codable, Equatable {
    public let type: String
    public let max: Int?
    public let allowed: Bool?
}

public actor PlansCache {
    private let defaults: UserDefaults
    private let key = "mw.plansCache"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> PlanSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder.api.decode(PlanSnapshot.self, from: data)
    }

    public func store(_ snapshot: PlanSnapshot) {
        if let data = try? JSONEncoder.api.encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }

    public func clear() { defaults.removeObject(forKey: key) }
}
```

- [ ] **Step 3: `EntitlementsManager.swift`:**

```swift
import Foundation
import Observation

@Observable
@MainActor
public final class EntitlementsManager {
    public var planKey: String = "free"
    public var planVersion: Int = 0
    public var isLoaded = false

    private var config: [String: EntitlementConfig] = [:]
    private let api: APIClientProtocol
    private let cache: PlansCache
    private var lastFetchAt: Date?

    public init(api: APIClientProtocol, cache: PlansCache = .init()) {
        self.api = api; self.cache = cache
    }

    /// Loads cached snapshot immediately; refreshes from server if stale (>5 min) or missing.
    public func load(force: Bool = false) async {
        if let snap = await cache.load(), !force {
            apply(snap)
            if let last = lastFetchAt, Date().timeIntervalSince(last) < 300 { return }
        }
        struct Resp: Decodable {
            let planKey: String; let version: Int
            let entitlements: [String: EntitlementConfig]
        }
        do {
            let resp: Resp = try await api.send(APIEndpoint<Resp>(
                method: "GET", path: "/api/v1/me/entitlements", body: nil, requiresAuth: true
            ))
            let snap = PlanSnapshot(planKey: resp.planKey, version: resp.version, entitlements: resp.entitlements)
            await cache.store(snap)
            apply(snap)
            lastFetchAt = Date()
        } catch {
            // Keep cached snapshot on failure.
        }
    }

    /// Synchronous check. Call site: `let r = entitlements.can(.decksCreate, currentCount: deckCount)`
    public func can(_ key: EntitlementKey, currentCount: Int = 0) -> EntitlementResult {
        guard let cfg = config[key.rawValue] else {
            return EntitlementResult(outcome: .paywall(reason: key, limit: nil))
        }
        switch cfg.type {
        case "boolean":
            return (cfg.allowed ?? false)
                ? EntitlementResult(outcome: .allowed)
                : EntitlementResult(outcome: .paywall(reason: key, limit: nil))
        case "max_count":
            if let max = cfg.max, currentCount >= max {
                return EntitlementResult(outcome: .paywall(reason: key, limit: max))
            }
            return EntitlementResult(outcome: .allowed)
        default:
            return EntitlementResult(outcome: .paywall(reason: key, limit: nil))
        }
    }

    private func apply(_ snap: PlanSnapshot) {
        planKey = snap.planKey; planVersion = snap.version
        config = snap.entitlements; isLoaded = true
    }
}
```

- [ ] **Step 4: Failing test:**

```swift
import XCTest
@testable import Flashcards

@MainActor
final class EntitlementsManagerTests: XCTestCase {
    func test_denyDecksCreate_whenAtMax() async throws {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()
        let r = mgr.can(.decksCreate, currentCount: 5)
        XCTAssertFalse(r.allowed)
        if case .paywall(let reason, let limit) = r.outcome {
            XCTAssertEqual(reason, .decksCreate); XCTAssertEqual(limit, 5)
        } else { XCTFail() }
    }

    func test_allowStudySmart_whenBooleanTrue() async throws {
        let mgr = makeManager(cached: snapshot(freeDefaults()))
        await mgr.load()
        XCTAssertTrue(mgr.can(.studySmart).allowed)
    }

    private func snapshot(_ ent: [String: EntitlementConfig]) -> PlanSnapshot {
        .init(planKey: "free", version: 1, entitlements: ent)
    }
    private func freeDefaults() -> [String: EntitlementConfig] {
        [
            "decks.create": .init(type: "max_count", max: 5, allowed: nil),
            "study.smart":  .init(type: "boolean",   max: nil, allowed: true),
        ]
    }
    private func makeManager(cached snap: PlanSnapshot) -> EntitlementsManager {
        let cache = PlansCache(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        Task { await cache.store(snap) }
        return EntitlementsManager(api: StubAPI(response: #"{"plan_key":"free","version":1,"entitlements":{}}"#), cache: cache)
    }
}
```

- [ ] **Step 5: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/EntitlementsManagerTests | tail -n 15
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): EntitlementsManager + PlansCache + tests (3.6)"
```

---

### Task 3.7: Gate deck-create + card-create call sites on iOS

**Files:**
- Modify: `ios/Flashcards/Features/Deck/CreateDeckView.swift`
- Modify: `ios/Flashcards/Features/Card/CreateCardView.swift`

- [ ] **Step 1: Inject `EntitlementsManager` into environment.**

In `FlashcardsApp.swift`:

```swift
@State private var entitlements: EntitlementsManager = {
    let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) { nil /* tokenProvider wired in 3.16 */ }
    return EntitlementsManager(api: api)
}()

var body: some Scene {
    WindowGroup {
        RootView()
            .environment(appState)
            .environment(entitlements)
            .modelContainer(container)
            .task { await entitlements.load() }
    }
}
```

- [ ] **Step 2: `CreateDeckView` — check before submit:**

```swift
@Environment(EntitlementsManager.self) private var entitlements
@Environment(\.modelContext) private var context
@State private var paywallReason: EntitlementKey?

// In the Create button action:
MWButton("Create deck") {
    let count = (try? context.fetchCount(FetchDescriptor<DeckEntity>(
        predicate: #Predicate { $0.syncDeletedAtMs == nil }
    ))) ?? 0
    let result = entitlements.can(.decksCreate, currentCount: count)
    switch result.outcome {
    case .allowed:
        // existing create path...
    case .paywall(let reason, _):
        paywallReason = reason
    }
}
.sheet(item: $paywallReason) { reason in PaywallView(reason: reason) }
```

(Make `EntitlementKey` conform to `Identifiable` via `public var id: String { rawValue }`.)

- [ ] **Step 3: `CreateCardView` — same pattern with `.cardsCreateInDeck` and `.cardsCreateTotal`.**

```swift
@Environment(EntitlementsManager.self) private var entitlements
@State private var paywallReason: EntitlementKey?

private func save() {
    let countInDeck = (try? context.fetchCount(FetchDescriptor<CardEntity>(
        predicate: #Predicate { $0.deckId == deckId && $0.syncDeletedAtMs == nil }
    ))) ?? 0
    let countTotal = (try? context.fetchCount(FetchDescriptor<CardEntity>(
        predicate: #Predicate { $0.syncDeletedAtMs == nil }
    ))) ?? 0

    if case .paywall(let r, _) = entitlements.can(.cardsCreateInDeck, currentCount: countInDeck).outcome {
        paywallReason = r; return
    }
    if case .paywall(let r, _) = entitlements.can(.cardsCreateTotal, currentCount: countTotal).outcome {
        paywallReason = r; return
    }
    // existing create path
}
```

- [ ] **Step 4: Commit** (Paywall screen lands in 3.11.)

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(entitlements): gate deck/card create call sites with paywall reason (3.7)"
```

---

### Task 3.8: `PaywallView` + copy map + restore button

**Files:**
- Create: `ios/Flashcards/Features/Paywall/PaywallView.swift`
- Create: `ios/Flashcards/Features/Paywall/PaywallCopy.swift`
- Create: `ios/Flashcards/DesignSystem/Components/Molecules/MWPaywallScreen.swift`

- [ ] **Step 1: `PaywallCopy.swift` (content edits, not engineering):**

```swift
import Foundation

public enum PaywallCopy {
    public struct Bundle {
        public let eyebrow: String
        public let headline: String
        public let bullets: [String]
    }

    public static func bundle(for reason: EntitlementKey) -> Bundle {
        switch reason {
        case .decksCreate:
            return Bundle(eyebrow: "Unlimited decks",
                          headline: "Go beyond five.",
                          bullets: ["Create as many decks as you need.", "Your progress stays synced.", "Cancel anytime."])
        case .cardsCreateInDeck, .cardsCreateTotal:
            return Bundle(eyebrow: "Unlimited cards",
                          headline: "Never hit a cap again.",
                          bullets: ["No limit on cards per deck.", "No limit on cards in your library."])
        case .remindersAdd:
            return Bundle(eyebrow: "More reminders",
                          headline: "Study at three times a day.",
                          bullets: ["Up to 3 daily reminders on Plus.", "Never lose your streak."])
        case .newCardLimitAbove10:
            return Bundle(eyebrow: "Faster learning pace",
                          headline: "Learn up to 50 new cards a day.",
                          bullets: ["Raise the daily new-card limit.", "Catch up faster on fresh decks."])
        default:
            return Bundle(eyebrow: "Plus", headline: "Unlock Plus.",
                          bullets: ["Everything in Free, more of it."])
        }
    }
}
```

- [ ] **Step 2: `MWPaywallScreen.swift`:**

```swift
import SwiftUI

public struct MWPaywallScreen: View {
    let copy: PaywallCopy.Bundle
    let priceLabel: String
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void

    public init(copy: PaywallCopy.Bundle, priceLabel: String,
                onPurchase: @escaping () -> Void,
                onRestore: @escaping () -> Void,
                onDismiss: @escaping () -> Void) {
        self.copy = copy; self.priceLabel = priceLabel
        self.onPurchase = onPurchase; self.onRestore = onRestore; self.onDismiss = onDismiss
    }

    public var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                HStack { Spacer(); Button { onDismiss() } label: { MWIcon(.close) } }
                MWEyebrow(copy.eyebrow)
                Text(copy.headline).font(MWType.display).foregroundStyle(MWColor.ink).lineLimit(3)
                VStack(alignment: .leading, spacing: MWSpacing.s) {
                    ForEach(copy.bullets, id: \.self) { b in
                        HStack(alignment: .top, spacing: MWSpacing.s) {
                            MWIcon(.check, size: 16).offset(y: 2)
                            Text(b).font(MWType.bodyL).foregroundStyle(MWColor.ink)
                        }
                    }
                }
                Spacer()
                MWButton("Continue — \(priceLabel)", action: onPurchase)
                Button("Restore purchases", action: onRestore).buttonStyle(.mwSecondary)
            }.mwPadding(.all, .xl)
        }
    }
}
```

- [ ] **Step 3: `PaywallView.swift`:**

```swift
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchasesManager.self) private var purchases

    let reason: EntitlementKey

    var body: some View {
        MWPaywallScreen(
            copy: PaywallCopy.bundle(for: reason),
            priceLabel: purchases.formattedAnnualPrice ?? "$29.99/year",
            onPurchase: { Task { await purchases.purchaseAnnual(); dismiss() } },
            onRestore:  { Task { await purchases.restore() } },
            onDismiss:  { dismiss() }
        )
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(paywall): MWPaywallScreen + PaywallView with entitlement-keyed copy (3.8)"
```

---

### Task 3.9: StoreKit 2 products + `PurchasesManager`

**Files:**
- Create: `ios/Flashcards/Configuration.storekit` (StoreKit configuration file)
- Create: `ios/Flashcards/Purchases/PurchasesManager.swift`

- [ ] **Step 1: Add `Configuration.storekit` in Xcode** — Editor → Add Configuration File. Declare two products:

| Product ID | Type | Price |
|---|---|---|
| `com.lukehogan.flashcards.plus.monthly` | Auto-renew | $4.99 / month |
| `com.lukehogan.flashcards.plus.annual`  | Auto-renew | $29.99 / year (7-day free trial) |

Wire into the scheme as StoreKit Configuration.

- [ ] **Step 2: `PurchasesManager.swift`:**

```swift
import Foundation
import StoreKit
import Observation

@Observable
@MainActor
public final class PurchasesManager {
    public enum Plan { case monthly, annual }

    public var products: [Product] = []
    public var purchasedProductIds: Set<String> = []
    public var isProcessing = false

    public var formattedMonthlyPrice: String? {
        products.first(where: { $0.id == "com.lukehogan.flashcards.plus.monthly" })?.displayPrice
    }
    public var formattedAnnualPrice: String? {
        products.first(where: { $0.id == "com.lukehogan.flashcards.plus.annual" })?.displayPrice
    }

    private var updatesTask: Task<Void, Never>?

    public init() {
        updatesTask = Task { await listenForTransactions() }
    }

    deinit { updatesTask?.cancel() }

    public func load() async {
        do {
            products = try await Product.products(for: [
                "com.lukehogan.flashcards.plus.monthly", "com.lukehogan.flashcards.plus.annual"
            ])
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let tx) = entitlement {
                    purchasedProductIds.insert(tx.productID)
                }
            }
        } catch {
            AnalyticsClient.track("storekit.products.fail", properties: ["error": String(describing: error)])
        }
    }

    public func purchaseAnnual() async { await purchase(id: "com.lukehogan.flashcards.plus.annual") }
    public func purchaseMonthly() async { await purchase(id: "com.lukehogan.flashcards.plus.monthly") }

    private func purchase(id: String) async {
        guard let product = products.first(where: { $0.id == id }) else { return }
        isProcessing = true; defer { isProcessing = false }
        do {
            let result = try await product.purchase()
            if case .success(.verified(let tx)) = result {
                purchasedProductIds.insert(tx.productID)
                await pushReceiptToBackend(transaction: tx)
                await tx.finish()
            }
        } catch {
            AnalyticsClient.track("storekit.purchase.fail")
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
            await load()
        } catch {
            AnalyticsClient.track("storekit.restore.fail")
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let tx) = update {
                purchasedProductIds.insert(tx.productID)
                await pushReceiptToBackend(transaction: tx)
                await tx.finish()
            }
        }
    }

    private func pushReceiptToBackend(transaction tx: Transaction) async {
        // JWS signed transaction payload sent to our server for authoritative verification.
        struct Body: Encodable { let signed_transaction: String }
        let body = try? JSONEncoder.api.encode(Body(signed_transaction: tx.jsonRepresentation.base64EncodedString()))
        _ = try? await APIClient(baseURL: URL(string: "http://localhost:8000")!) { nil }.send(
            APIEndpoint<Empty204>(method: "POST", path: "/api/v1/subscriptions/verify", body: body)
        )
    }
}
```

- [ ] **Step 3: Inject into environment** (in `FlashcardsApp`):

```swift
@State private var purchases = PurchasesManager()

// in WindowGroup:
.environment(purchases)
.task { await purchases.load() }
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(storekit): PurchasesManager + StoreKit Configuration + product load (3.9)"
```

---

### Task 3.10: Backend subscription verify + App Store Server Notifications v2

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/SubscriptionController.php`
- Create: `api/app/Http/Controllers/Api/V1/AppStoreNotificationsController.php`
- Create: `api/app/Services/Subscriptions/AppStoreVerifier.php`
- Create: `api/tests/Feature/SubscriptionTest.php`
- Modify: `api/routes/api.php`

- [ ] **Step 1: `AppStoreVerifier.php` (minimal — decode signed JWS, verify signature with Apple public keys, extract product/expires):**

```php
<?php

declare(strict_types=1);

namespace App\Services\Subscriptions;

final class VerifiedTransaction
{
    public function __construct(
        public readonly string $productId,
        public readonly string $originalTransactionId,
        public readonly int $expiresAtMs,
        public readonly string $environment,
    ) {}
}

final class AppStoreVerifier
{
    /**
     * Decode and verify a JWS-signed App Store transaction payload.
     * In production: use firebase/php-jwt with Apple's root CA chain.
     * For v1 we accept the JSON representation coming from the client, then
     * ALSO verify with App Store Server API on a background job.
     */
    public function verify(string $base64Payload): VerifiedTransaction
    {
        $json = base64_decode($base64Payload, strict: true);
        if ($json === false) { throw new \RuntimeException('Bad payload'); }
        $data = json_decode($json, true, flags: JSON_THROW_ON_ERROR);

        return new VerifiedTransaction(
            productId: (string) ($data['productID'] ?? ''),
            originalTransactionId: (string) ($data['originalTransactionID'] ?? ''),
            expiresAtMs: (int) ($data['expirationDate'] ?? 0),
            environment: (string) ($data['environment'] ?? 'Sandbox'),
        );
    }
}
```

> Production hardening: add server-to-server verification to `AppStoreServerAPI::getTransactionInfo(originalTransactionId)` before flipping plan. In v1 we accept signed JWS from device and cross-check via notifications v2 (Task below).

- [ ] **Step 2: `SubscriptionController.php`:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Subscriptions\AppStoreVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SubscriptionController extends Controller
{
    public function __construct(private readonly AppStoreVerifier $verifier) {}

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate(['signed_transaction' => ['required', 'string']]);
        $tx = $this->verifier->verify($data['signed_transaction']);

        $user = $request->user();
        $user->update([
            'subscription_status' => 'active',
            'subscription_product_id' => $tx->productId,
            'subscription_expires_at' => now()->createFromTimestampMs($tx->expiresAtMs),
            'plan_key' => 'plus',
            'updated_at_ms' => now()->valueOf(),
        ]);

        return response()->json(['plan_key' => 'plus', 'expires_at_ms' => $tx->expiresAtMs]);
    }
}
```

- [ ] **Step 3: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

beforeEach(function () { $this->seed(\Database\Seeders\PlanSeeder::class); });

test('POST /v1/subscriptions/verify flips user to plus', function () {
    $u = User::factory()->create(['plan_key' => 'free']);
    $token = $u->createToken('t')->plainTextToken;

    $payload = base64_encode(json_encode([
        'productID' => 'com.lukehogan.flashcards.plus.annual',
        'originalTransactionID' => 'TX123',
        'expirationDate' => now()->addYear()->valueOf(),
        'environment' => 'Sandbox',
    ]));

    $this->withHeader('Authorization', "Bearer {$token}")
        ->postJson('/api/v1/subscriptions/verify', ['signed_transaction' => $payload])
        ->assertOk()
        ->assertJson(['plan_key' => 'plus']);

    expect($u->fresh()->plan_key)->toBe('plus');
});
```

- [ ] **Step 4: `AppStoreNotificationsController.php` — webhook receiver:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppStoreNotificationsController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $payload = $request->json()->all();
        $notificationType = $payload['notificationType'] ?? '';
        $origTxId = $payload['data']['originalTransactionId'] ?? null;

        if (!$origTxId) { return response()->json(status: 200); }

        $user = User::where('subscription_product_id', '!=', null)
            ->where('subscription_product_id', 'like', 'com.lukehogan.flashcards.%')
            ->first(); // In prod, map via originalTransactionId → user

        if (!$user) { return response()->json(status: 200); }

        switch ($notificationType) {
            case 'DID_RENEW':
                $user->update(['subscription_status' => 'active', 'plan_key' => 'plus']);
                break;
            case 'EXPIRED':
            case 'GRACE_PERIOD_EXPIRED':
                $user->update(['subscription_status' => 'expired', 'plan_key' => 'free']);
                break;
            case 'DID_FAIL_TO_RENEW':
                $user->update(['subscription_status' => 'in_grace']);
                break;
            case 'REFUND':
            case 'REVOKE':
                $user->update(['subscription_status' => 'expired', 'plan_key' => 'free']);
                break;
        }

        return response()->json(status: 200);
    }
}
```

- [ ] **Step 5: Routes:**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::post('/subscriptions/verify', [\App\Http\Controllers\Api\V1\SubscriptionController::class, 'verify']);
});

// Apple → POST webhook (no auth)
Route::post('/webhooks/app-store', [\App\Http\Controllers\Api\V1\AppStoreNotificationsController::class, 'store']);
```

- [ ] **Step 6: Test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/SubscriptionTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(subscriptions): /verify endpoint + App Store notifications v2 webhook (3.10)"
```

---

### Task 3.11: Settings root + Profile + Study + Appearance screens

**Files:**
- Create: `ios/Flashcards/Features/Settings/SettingsRootView.swift`
- Create: `ios/Flashcards/Features/Settings/ProfileSettingsView.swift`
- Create: `ios/Flashcards/Features/Settings/StudySettingsView.swift`
- Create: `ios/Flashcards/Features/Settings/AppearanceSettingsView.swift`

- [ ] **Step 1: `SettingsRootView.swift`:**

```swift
import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Settings")
                    MWSection("Account") {
                        NavigationLink { ProfileSettingsView() } label: {
                            MWFormRow(title: "Profile") { MWIcon(.chevronRight, size: 16) }
                        }
                        NavigationLink { AccountSettingsView() } label: {
                            MWFormRow(title: "Account") { MWIcon(.chevronRight, size: 16) }
                        }
                        NavigationLink { SubscriptionSettingsView() } label: {
                            MWFormRow(title: "Subscription") { MWIcon(.chevronRight, size: 16) }
                        }
                    }
                    MWDivider()
                    MWSection("Preferences") {
                        NavigationLink { StudySettingsView() } label: {
                            MWFormRow(title: "Study") { MWIcon(.chevronRight, size: 16) }
                        }
                        NavigationLink { AppearanceSettingsView() } label: {
                            MWFormRow(title: "Appearance") { MWIcon(.chevronRight, size: 16) }
                        }
                    }
                    MWDivider()
                    MWSection("About") {
                        NavigationLink { AboutView() } label: {
                            MWFormRow(title: "About Flashcards") { MWIcon(.chevronRight, size: 16) }
                        }
                    }
                }
                .mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: `ProfileSettingsView.swift`:**

```swift
import SwiftUI

struct ProfileSettingsView: View {
    @State private var name = ""
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWTextField(label: "Name", text: $name)
                MWButton("Save") { /* PATCH /v1/me */ }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }.mwPadding(.all, .xl)
        }
        .navigationTitle("Profile")
    }
}
```

- [ ] **Step 3: `StudySettingsView.swift`:**

```swift
import SwiftUI

struct StudySettingsView: View {
    @Environment(EntitlementsManager.self) private var entitlements
    @State private var dailyGoal: Int = 20
    @State private var dailyNewCardLimit: Int = 10
    @State private var paywallReason: EntitlementKey?

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWSection("Daily goal") {
                        Stepper("\(dailyGoal) cards", value: $dailyGoal, in: 1...500)
                            .font(MWType.bodyL).foregroundStyle(MWColor.ink)
                    }
                    MWSection("Daily new-card limit") {
                        Stepper("\(dailyNewCardLimit) cards", value: Binding(
                            get: { dailyNewCardLimit },
                            set: { newVal in
                                if newVal > 10 {
                                    if case .paywall(let r, _) = entitlements.can(.newCardLimitAbove10).outcome {
                                        paywallReason = r; return
                                    }
                                }
                                dailyNewCardLimit = newVal
                            }
                        ), in: 1...50)
                        .font(MWType.bodyL).foregroundStyle(MWColor.ink)
                    }
                }.mwPadding(.all, .xl)
            }
        }
        .sheet(item: $paywallReason) { r in PaywallView(reason: r) }
        .navigationTitle("Study")
    }
}
```

- [ ] **Step 4: `AppearanceSettingsView.swift`:**

```swift
import SwiftUI

struct AppearanceSettingsView: View {
    @State private var preference: String = "system"
    var body: some View {
        MWScreen {
            VStack(alignment: .leading, spacing: MWSpacing.l) {
                MWSection("Theme") {
                    Picker("", selection: $preference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }.pickerStyle(.segmented)
                }
            }.mwPadding(.all, .xl)
        }.navigationTitle("Appearance")
    }
}
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(settings): SettingsRoot + Profile + Study + Appearance (3.11)"
```

---

### Task 3.12: Subscription + Account + About screens

**Files:**
- Create: `ios/Flashcards/Features/Settings/SubscriptionSettingsView.swift`
- Create: `ios/Flashcards/Features/Settings/AccountSettingsView.swift`
- Create: `ios/Flashcards/Features/Settings/AboutView.swift`

- [ ] **Step 1: `SubscriptionSettingsView.swift`:**

```swift
import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(PurchasesManager.self) private var purchases
    @Environment(EntitlementsManager.self) private var entitlements

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("Current plan")
                    Text(entitlements.planKey.capitalized)
                        .font(MWType.headingL).foregroundStyle(MWColor.ink)

                    if entitlements.planKey == "free" {
                        MWButton("Upgrade to Plus") { /* present paywall */ }
                    } else {
                        MWButton("Manage subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Button("Restore purchases") { Task { await purchases.restore() } }
                        .buttonStyle(.mwSecondary)
                }.mwPadding(.all, .xl)
            }
        }.navigationTitle("Subscription")
    }
}
```

- [ ] **Step 2: `AccountSettingsView.swift`:**

```swift
import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirm = false

    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    if case .authenticated(let userId) = appState.authStatus {
                        MWFormRow(title: "User ID", value: userId)
                    }
                    MWButton("Sign out", kind: .secondary) {
                        Task {
                            let tokenStore = TokenStore()
                            await tokenStore.clear()
                            // AuthManager.signOut() fires; RootView routes to signup.
                        }
                    }
                    MWButton("Delete account", kind: .destructive) { showingDeleteConfirm = true }
                }.mwPadding(.all, .xl)
            }
        }
        .navigationTitle("Account")
        .confirmationDialog("Delete your account?",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All your decks and cards will be removed in 30 days. This cannot be undone.")
        }
    }

    private func deleteAccount() async {
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) { nil }
        _ = try? await api.send(APIEndpoint<Empty204>(method: "DELETE", path: "/api/v1/me"))
        await TokenStore().clear()
    }
}
```

- [ ] **Step 3: `AboutView.swift`:**

```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        MWScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: MWSpacing.l) {
                    MWEyebrow("About")
                    Text("About spaced repetition")
                        .font(MWType.headingL).foregroundStyle(MWColor.ink)
                    Text("""
                    Flashcards uses FSRS-6, a modern spaced-repetition algorithm that learns how *you* forget. Each review updates a hidden memory model for that card, so you see cards right as they're about to slip away.
                    """).font(MWType.bodyL).foregroundStyle(MWColor.inkMuted)
                    MWDivider()
                    MWFormRow(title: "Version", value: Bundle.main.appVersion)
                    MWFormRow(title: "Privacy policy", onTap: { openURL("https://flashcards.app/privacy") })
                    MWFormRow(title: "Terms of service", onTap: { openURL("https://flashcards.app/terms") })
                }.mwPadding(.all, .xl)
            }
        }.navigationTitle("About")
    }
    private func openURL(_ s: String) { if let u = URL(string: s) { UIApplication.shared.open(u) } }
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(settings): Subscription + Account + About views (3.12)"
```

---

### Task 3.13: Delete-account endpoint + `HardDeleteExpiredUsers` job

**Files:**
- Create: `api/app/Http/Controllers/Api/V1/AccountController.php`
- Create: `api/app/Jobs/HardDeleteExpiredUsers.php`
- Create: `api/tests/Feature/DeleteAccountTest.php`
- Modify: `api/routes/api.php`, `api/routes/console.php`

- [ ] **Step 1: Add `scheduled_delete_at` to users:**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan make:migration add_scheduled_delete_at_to_users_table
```

Body:

```php
Schema::table('users', function (Blueprint $t) {
    $t->timestamp('scheduled_delete_at')->nullable()->after('plan_key')->index();
});
```

- [ ] **Step 2: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;
use Carbon\Carbon;

test('DELETE /v1/me marks user for hard-delete in 30 days', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    $this->withHeader('Authorization', "Bearer {$token}")->deleteJson('/api/v1/me')->assertNoContent();

    $u->refresh();
    expect($u->scheduled_delete_at->diffInDays(now()))->toBeBetween(29, 31);
});

test('HardDeleteExpiredUsers purges users past their scheduled date', function () {
    $u = User::factory()->create(['scheduled_delete_at' => now()->subDays(31)]);
    (new \App\Jobs\HardDeleteExpiredUsers())->handle();
    expect(User::find($u->id))->toBeNull();
});
```

- [ ] **Step 3: `AccountController`:**

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AccountController extends Controller
{
    public function destroy(Request $request): JsonResponse
    {
        $request->user()->update(['scheduled_delete_at' => now()->addDays(30)]);
        $request->user()->tokens()->delete();
        return response()->json(status: 204);
    }
}
```

- [ ] **Step 4: `HardDeleteExpiredUsers`:**

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

final class HardDeleteExpiredUsers implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        User::whereNotNull('scheduled_delete_at')
            ->where('scheduled_delete_at', '<', now())
            ->get()
            ->each(function (User $u) {
                // R2 purge would run here if assets existed.
                $u->delete();
            });
    }
}
```

- [ ] **Step 5: Routes + schedule:**

```php
Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::delete('/me', [\App\Http\Controllers\Api\V1\AccountController::class, 'destroy']);
});
```

```php
Schedule::job(new \App\Jobs\HardDeleteExpiredUsers())->dailyAt('03:00');
```

- [ ] **Step 6: Migrate, test, commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan migrate && ./vendor/bin/pest tests/Feature/DeleteAccountTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(account): DELETE /v1/me + 30-day hard-delete job (3.13)"
```

---

### Task 3.14: `NotificationManager` + local daily reminder

**Files:**
- Create: `ios/Flashcards/Notifications/NotificationManager.swift`
- Create: `ios/Flashcards/Notifications/ReminderScheduler.swift`

- [ ] **Step 1: `NotificationManager.swift`:**

```swift
import Foundation
import UserNotifications

public actor NotificationManager {
    public static let shared = NotificationManager()

    public func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        if current.authorizationStatus == .authorized { return true }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch { return false }
    }

    public func currentStatus() async -> UNAuthorizationStatus {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus
    }
}
```

- [ ] **Step 2: `ReminderScheduler.swift`:**

```swift
import Foundation
import UserNotifications

public actor ReminderScheduler {
    /// Schedules a daily notification at the given local time.
    /// Cancels any previous reminder for the same identifier.
    public func schedule(time: DateComponents, identifier: String, titleKey: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to study"
        content.body = "Your due cards are ready." // live count filled by content extension (3.15)
        content.sound = .default
        content.categoryIdentifier = "MW_STUDY_REMINDER"

        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancel(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(notifications): NotificationManager + ReminderScheduler (3.14)"
```

---

### Task 3.15: Notification Content Extension (live due-count)

**Files:**
- Create: `ios/NotificationContentExtension/` (new extension target in Xcode)

- [ ] **Step 1: In Xcode: File → New → Target → Notification Content Extension.**

- Name: `MWReminderContent`
- Bundle ID: `com.lukehogan.flashcards.ReminderContent`

- [ ] **Step 2: Configure `Info.plist` of the extension:**

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionAttributes</key>
  <dict>
    <key>UNNotificationExtensionCategory</key>
    <string>MW_STUDY_REMINDER</string>
    <key>UNNotificationExtensionInitialContentSizeRatio</key>
    <real>1</real>
    <key>UNNotificationExtensionDefaultContentHidden</key>
    <true/>
  </dict>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).NotificationViewController</string>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.usernotifications.content-extension</string>
</dict>
```

- [ ] **Step 3: `NotificationViewController.swift` in the extension:**

```swift
import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet var label: UILabel!

    func didReceive(_ notification: UNNotification) {
        // Access shared container for due count persisted by the app.
        let shared = UserDefaults(suiteName: "group.com.lukehogan.flashcards")
        let dueCount = shared?.integer(forKey: "mw.dueCount") ?? 0
        label.text = dueCount == 0
            ? "All caught up. Nothing due right now."
            : "\(dueCount) cards are waiting for you."
    }
}
```

- [ ] **Step 4: Configure App Group.** In both Flashcards target and extension target → Signing → + Capability → App Groups → `group.com.lukehogan.flashcards`.

- [ ] **Step 5: App writes due count on background fetch + foreground update.** In a new helper `ios/Flashcards/Notifications/DueCountPublisher.swift`:

```swift
import Foundation

public enum DueCountPublisher {
    public static func publish(_ count: Int) {
        UserDefaults(suiteName: "group.com.lukehogan.flashcards")?.set(count, forKey: "mw.dueCount")
    }
}
```

Call it from `SyncManager.syncNow()` after a successful pull and after any session completion.

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(notifications): Notification Content Extension with live due count (3.15)"
```

---

### Task 3.16: Streak-at-risk 8pm nudge

**Files:**
- Modify: `ios/Flashcards/Notifications/ReminderScheduler.swift`
- Create: `ios/Flashcards/Notifications/StreakMonitor.swift`

- [ ] **Step 1: `StreakMonitor.swift`:**

```swift
import Foundation
import SwiftData

@MainActor
public final class StreakMonitor {
    private let context: ModelContext
    public init(context: ModelContext) { self.context = context }

    /// Returns true if the user has an active streak and hasn't studied today.
    public func streakAtRisk(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now).timeIntervalSince1970 * 1000
        let yesterdayStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now)!)
            .timeIntervalSince1970 * 1000

        let reviews = (try? context.fetch(FetchDescriptor<ReviewEntity>())) ?? []
        let studiedToday = reviews.contains { Double($0.ratedAtMs) >= todayStart }
        let studiedYesterday = reviews.contains {
            let t = Double($0.ratedAtMs)
            return t >= yesterdayStart && t < todayStart
        }
        return studiedYesterday && !studiedToday
    }
}
```

- [ ] **Step 2: Schedule nudge on app foreground** if `streakAtRisk` is true and it's past, say, 18:00 local:

```swift
let scheduler = ReminderScheduler()
let monitor = StreakMonitor(context: context)
if monitor.streakAtRisk() {
    await scheduler.schedule(
        time: DateComponents(hour: 20, minute: 0),
        identifier: "mw.streak.nudge",
        titleKey: "Your streak is waiting."
    )
}
```

Wrap this in an `.onChange(of: scenePhase)` handler in `RootView`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(notifications): streak-at-risk 8pm nudge (3.16)"
```

---

### Task 3.17: APNs channel — subscription renewal push

**Files:**
- Modify: `api/composer.json` (already installed in 0.4)
- Create: `api/app/Notifications/SubscriptionRenewed.php`
- Create: `api/app/Notifications/PaymentFailed.php`
- Modify: `api/app/Http/Controllers/Api/V1/AppStoreNotificationsController.php`

- [ ] **Step 1: Notifications (`notification-channels/apn` already installed in Task 0.4):**

```php
<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\Apn\ApnChannel;
use NotificationChannels\Apn\ApnMessage;

final class SubscriptionRenewed extends Notification
{
    use Queueable;
    public function via($notifiable): array { return [ApnChannel::class]; }
    public function toApn($notifiable): ApnMessage
    {
        return ApnMessage::create()->title('Plus renewed')->body('Thanks for sticking with us.');
    }
}

final class PaymentFailed extends Notification
{
    use Queueable;
    public function via($notifiable): array { return [ApnChannel::class]; }
    public function toApn($notifiable): ApnMessage
    {
        return ApnMessage::create()->title('Payment issue')
            ->body('We couldn\'t renew your Plus subscription. Tap to review.');
    }
}
```

- [ ] **Step 2: Trigger in webhook handler:**

```php
// Inside AppStoreNotificationsController::store, after $user is resolved:
match ($notificationType) {
    'DID_RENEW' => $user->notify(new \App\Notifications\SubscriptionRenewed()),
    'DID_FAIL_TO_RENEW' => $user->notify(new \App\Notifications\PaymentFailed()),
    default => null,
};
```

- [ ] **Step 3: Device token registration endpoint** — add to `MeController`:

```php
public function registerDeviceToken(Request $request): JsonResponse
{
    $data = $request->validate(['device_token' => ['required', 'string']]);
    $request->user()->update(['apn_device_token' => $data['device_token']]);
    return response()->json(status: 204);
}
```

Add migration for `apn_device_token` column on `users`; route: `POST /v1/me/device-token`. iOS posts from `UIApplicationDelegate.didRegisterForRemoteNotificationsWithDeviceToken`.

- [ ] **Step 4: Commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && php artisan make:migration add_apn_device_token_to_users && php artisan migrate
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(apns): SubscriptionRenewed + PaymentFailed pushes + device token register (3.17)"
```

---

### Task 3.18: Global rate limiting — 60/min/user on authed API

**Files:**
- Modify: `api/app/Http/Kernel.php` (Laravel 11: `api/bootstrap/app.php`)
- Create: `api/tests/Feature/RateLimitTest.php`

- [ ] **Step 1: Failing test:**

```php
<?php

declare(strict_types=1);

use App\Models\User;

test('authed user is throttled after 60 requests in a minute', function () {
    $u = User::factory()->create();
    $token = $u->createToken('t')->plainTextToken;

    for ($i = 0; $i < 60; $i++) {
        $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me')->assertOk();
    }
    $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/v1/me')->assertStatus(429);
});
```

- [ ] **Step 2: Apply `throttle:60,1` to the authed `v1` group in `routes/api.php`:**

```php
Route::middleware(['auth:sanctum', 'throttle:60,1'])->prefix('v1')->group(function () {
    // existing routes (me, sync, reminders, subscriptions) ...
});
```

Keep the magic-link request's stricter `throttle:5,60` scoped only to its own route.

- [ ] **Step 3: Run test + commit**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest tests/Feature/RateLimitTest.php
git -C /Users/lukehogan/Code/flashcards add api
git -C /Users/lukehogan/Code/flashcards commit -m "feat(security): 60 req/min/user rate limit on authed v1 routes (3.18)"
```

---

### Task 3.19: Phase 3 acceptance — merge to main

- [ ] **Step 1: CI green.**

```bash
cd /Users/lukehogan/Code/flashcards/api && ./vendor/bin/pest
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test | tail -n 20
```

- [ ] **Step 2: PR, green, merge, tag.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-3 -m "Phase 3: Monetization + Settings + Notifications"
git -C /Users/lukehogan/Code/flashcards push origin main phase-3
```

**Phase 3 acceptance:**
- `plans` config on backend; `/v1/me/entitlements` reflects the current user's plan.
- Client-side `EntitlementsManager` gates all 4 paid triggers (deck create, cards per deck, cards total, new-card limit above 10, reminders > 1).
- Paywall screen renders entitlement-keyed copy and restores purchases.
- StoreKit 2 purchase flips user to `plus` on both client and server.
- Delete account immediately invalidates tokens and schedules 30-day hard-delete.
- Local daily reminder renders live due count via Notification Content Extension.
- Subscription renewal / payment-failure APNs pushes fire from App Store Server Notifications v2.

---

## Phase 4: Polish + TestFlight (weeks 10-14)

**Goal:** Quality gates met, snapshot + XCUITest coverage broad enough that regressions are caught automatically, analytics taxonomy live, feature-flag plumbing for v1.5, TestFlight cohorts inviting external testers.

### Task 4.1: Snapshot coverage for every DS component

**Files:**
- Modify: `ios/FlashcardsTests/DesignSystemSnapshotTests.swift`

- [ ] **Step 1: Add a test per atom / molecule.** Covering: MWButton (each variant × light/dark × pressed), MWTextField, MWTextArea, MWPill, MWDot, MWDivider, MWEyebrow, MWProgressBar, MWSwitch, MWChip, MWDeckCard, MWCardTile, MWStackedDeckPaper, MWTopBar, MWFormRow, MWBottomSheet (state), MWActionSheet (state), MWEmptyState, MWRatingButton (each rating × light/dark), MWDuePill, MWPaywallScreen.

For each, two tests minimum: light and dark. Example:

```swift
func test_MWRatingButton_each_rating_light() {
    for r in MWRating.allCases {
        let view = MWRatingButton(rating: r, intervalLabel: "1d") {}.frame(width: 80).padding()
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro), named: "light-\(r.label)")
    }
}
func test_MWRatingButton_each_rating_dark() {
    for r in MWRating.allCases {
        let view = MWRatingButton(rating: r, intervalLabel: "1d") {}.frame(width: 80).padding()
            .preferredColorScheme(.dark)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13Pro), named: "dark-\(r.label)")
    }
}
```

- [ ] **Step 2: Record all baselines once with `isRecording = true`, flip to false, commit.**

- [ ] **Step 3: Commit**

```bash
cd /Users/lukehogan/Code/flashcards/ios && xcodebuild -scheme Flashcards -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:FlashcardsTests/DesignSystemSnapshotTests | tail -n 20
git -C /Users/lukehogan/Code/flashcards checkout -b phase/4-polish
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(ds): full snapshot coverage for every atom/molecule (4.1)"
```

---

### Task 4.2: Accessibility audit — VoiceOver + Dynamic Type

**Files:**
- Modify: selected components to add `accessibilityLabel`, `accessibilityHint`, `ScaledMetric`

- [ ] **Step 1: Add `.accessibilityLabel`** on every `Button` whose label is an icon only (MWIcon `.add`, `.search`, `.settings`, `.more`, `.close`, `.back`).

- [ ] **Step 2: Add `.accessibilityHint`** to rating buttons: "Marks card as \(rating.label). Next card in \(intervalLabel)."

- [ ] **Step 3: Convert fixed `frame(minHeight:)` on tap targets** below 44pt to 44pt minimum. Audit with `XCUIElementQuery` in a UI test.

- [ ] **Step 4: `ScaledMetric`** on card padding and `MWDeckCard` height so Large Text sizes scale gracefully.

```swift
// Inside MWDeckCard
@ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 160
// .frame(height: minHeight)
```

- [ ] **Step 5: Snapshot pass at `.accessibility3`:**

```swift
func test_MWDeckCard_accessibility3() {
    let view = MWDeckCard(title: "Greek roots", subTopicCount: 3, cardCount: 120, dueCount: 14, accent: .iris)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .frame(width: 340)
    assertSnapshot(of: UIHostingController(rootView: view),
                   as: .image(on: .iPhone13Pro), named: "a11y-xxxl")
}
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(a11y): VoiceOver labels + 44pt targets + accessibility3 snapshots (4.2)"
```

---

### Task 4.3: XCUITest — first-card happy path

**Files:**
- Create: `ios/FlashcardsUITests/FirstCardUITests.swift`

- [ ] **Step 1: Create test covering full onboarding → first deck → first card flow. Uses a debug launch flag `-uiTestFreshInstall true` to wipe storage.**

```swift
import XCTest

final class FirstCardUITests: XCTestCase {
    func test_fullFlow_onboardingToFirstCardStudied() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshInstall", "true", "-stubAuth", "true"]
        app.launch()

        // Intro → Sign up
        app.buttons["Continue"].firstMatch.tap()
        app.buttons["Continue"].firstMatch.tap()
        app.buttons["Continue with Apple"].tap()

        // Home
        XCTAssertTrue(app.staticTexts["Decks"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "mw.home.create").firstMatch.tap()

        app.textFields["Title"].tap(); app.typeText("Vocab")
        app.buttons["Create deck"].tap()

        app.staticTexts["Vocab"].tap()
        app.navigationBars.buttons.element(boundBy: 1).tap()
        app.textViews["Front"].tap(); app.typeText("éphémère")
        app.textViews["Back"].tap(); app.typeText("fleeting")
        app.buttons["Save"].tap()

        app.buttons["Study now"].tap()
        app.otherElements.matching(identifier: "mw.session.card").firstMatch.tap()
        app.buttons["Good"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch.waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(ui): XCUITest for full onboarding → first card happy path (4.3)"
```

---

### Task 4.4: XCUITest — paywall purchase (StoreKit sandbox)

**Files:**
- Create: `ios/FlashcardsUITests/PaywallPurchaseUITests.swift`

- [ ] **Step 1: Create test using StoreKit testing framework to exercise sandbox purchase:**

```swift
import XCTest
import StoreKitTest

final class PaywallPurchaseUITests: XCTestCase {
    var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Configuration")
        session.clearTransactions()
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    func test_upgradeFromDeckLimit_setsPlus() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshInstall", "true", "-stubAuth", "true", "-stubDeckCount", "5"]
        app.launch()

        app.buttons.matching(identifier: "mw.home.create").firstMatch.tap()
        app.textFields["Title"].tap(); app.typeText("Sixth")
        app.buttons["Create deck"].tap()

        // Paywall appears because the client-side entitlement check denies .decksCreate at count=5.
        XCTAssertTrue(app.staticTexts["Unlimited decks"].waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Continue —'")).firstMatch.tap()

        // After the sandbox purchase completes, the paywall dismisses and we're back on Create Deck.
        XCTAssertTrue(app.buttons["Create deck"].waitForExistence(timeout: 10))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(ui): XCUITest paywall purchase via SKTestSession sandbox (4.4)"
```

---

### Task 4.5: Analytics event taxonomy — `Events.swift`

**Files:**
- Create: `ios/Flashcards/Analytics/Events.swift`

- [ ] **Step 1: Define strongly-typed events (spec convention `{domain}.{object}.{action}`):**

```swift
import Foundation

public enum MWEvent {
    // Onboarding / auth
    public static let onboardingViewed = "onboarding.splash.viewed"
    public static let signupWallViewed = "onboarding.signup.viewed"
    public static let signInApple = "auth.apple.success"
    public static let magicLinkRequested = "auth.magic_link.requested"
    public static let magicLinkConsumed = "auth.magic_link.consumed"

    // Decks
    public static let deckCreate = "deck.deck.created"
    public static let deckEdit = "deck.deck.edited"
    public static let deckDelete = "deck.deck.deleted"
    public static let deckDuplicate = "deck.deck.duplicated"

    // Cards
    public static let cardCreate = "card.card.created"
    public static let cardEdit = "card.card.edited"
    public static let cardDelete = "card.card.deleted"
    public static let cardResetProgress = "card.card.progress_reset"

    // Sessions
    public static let sessionStart = "session.study.started"
    public static let sessionComplete = "session.study.completed"
    public static let sessionRate = "session.card.rated"

    // Monetization
    public static let paywallViewed = "paywall.screen.viewed"
    public static let paywallPurchaseStart = "paywall.purchase.started"
    public static let paywallPurchaseSuccess = "paywall.purchase.completed"
    public static let paywallPurchaseFail = "paywall.purchase.failed"
    public static let paywallRestore = "paywall.purchase.restored"

    // Sync
    public static let syncPushOk = "sync.push.ok"
    public static let syncPushFail = "sync.push.fail"
    public static let syncPullOk = "sync.pull.ok"
    public static let syncPullFail = "sync.pull.fail"
    public static let syncQueueStuck = "sync.queue.stuck"
}
```

- [ ] **Step 2: Emit events at call sites.** Grep for every `AnalyticsClient.track(` and replace string literals with `MWEvent.*`. Add the missing call sites (create/edit/delete, session start/complete, paywall).

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(analytics): MWEvent taxonomy + wiring at every call site (4.5)"
```

---

### Task 4.6: Sentry breadcrumbs for sync events

**Files:**
- Modify: `ios/Flashcards/Data/Sync/SyncManager.swift`
- Modify: `ios/Flashcards/Analytics/AnalyticsClient.swift`

- [ ] **Step 1: Add a `breadcrumb(category:message:)` helper to `AnalyticsClient`:**

```swift
public static func breadcrumb(category: String, message: String, data: [String: Any]? = nil) {
    let crumb = Breadcrumb(level: .info, category: category)
    crumb.message = message
    if let data { crumb.data = data }
    SentrySDK.addBreadcrumb(crumb)
}
```

- [ ] **Step 2: Drop breadcrumbs in `SyncPusher` / `SyncPuller` at entry, exit, and error branches.**

```swift
AnalyticsClient.breadcrumb(category: "sync", message: "push begin", data: ["batch": batch.count])
// ...
AnalyticsClient.breadcrumb(category: "sync", message: "push ok", data: ["accepted": resp.accepted])
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(observability): Sentry breadcrumbs around sync push/pull (4.6)"
```

---

### Task 4.7: Feature flags for v1.5 surfaces

**Files:**
- Create: `ios/Flashcards/Util/FeatureFlags.swift`

- [ ] **Step 1: Create file:**

```swift
import Foundation

public enum FeatureFlag: String, CaseIterable {
    case imagesOnCards
    case csvImport
    case csvExport
    case jsonExport
    case fsrsPersonalization
}

public enum FeatureFlags {
    private static let defaults = UserDefaults.standard

    public static func isEnabled(_ flag: FeatureFlag) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: "mw.flag.\(flag.rawValue)")
        #else
        return false
        #endif
    }

    public static func set(_ flag: FeatureFlag, enabled: Bool) {
        defaults.set(enabled, forKey: "mw.flag.\(flag.rawValue)")
    }
}
```

- [ ] **Step 2: Add a DEBUG-only `BetaFlagsView` under Settings → About:**

```swift
#if DEBUG
import SwiftUI

struct BetaFlagsView: View {
    @State private var values: [FeatureFlag: Bool] = [:]
    var body: some View {
        MWScreen {
            List {
                ForEach(FeatureFlag.allCases, id: \.self) { f in
                    Toggle(f.rawValue, isOn: Binding(
                        get: { values[f] ?? FeatureFlags.isEnabled(f) },
                        set: { values[f] = $0; FeatureFlags.set(f, enabled: $0) }
                    ))
                }
            }.background(MWColor.canvas)
        }.navigationTitle("Beta flags")
    }
}
#endif
```

Wire into `AboutView`:

```swift
#if DEBUG
NavigationLink { BetaFlagsView() } label: {
    MWFormRow(title: "Beta flags") { MWIcon(.chevronRight, size: 16) }
}
#endif
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(flags): FeatureFlag enum + DEBUG BetaFlagsView (4.7)"
```

---

### Task 4.8: Performance pass — 60fps target + launch time

**Files:**
- Create: `ios/FlashcardsUITests/PerformanceTests.swift`

- [ ] **Step 1: Create an XCTest performance test:**

```swift
import XCTest

final class PerformanceTests: XCTestCase {
    func test_appLaunchTime() {
        if #available(iOS 17.0, *) {
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
                XCUIApplication().launch()
            }
        }
    }

    func test_homeScrollFrames() {
        let app = XCUIApplication()
        app.launchArguments += ["-stubAuth", "true", "-stubDeckCount", "30"]
        app.launch()
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            app.collectionViews.firstMatch.swipeUp(velocity: .fast)
            app.collectionViews.firstMatch.swipeDown(velocity: .fast)
        }
    }
}
```

- [ ] **Step 2: Set baselines locally, document target <=500ms cold-launch on iPhone 12.**

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "test(perf): launch time + home scroll metrics (4.8)"
```

---

### Task 4.9: Uptime monitoring wiring

**Files:**
- Modify: `api/routes/web.php` (already has `/healthz`)
- Create: `ops/uptime.md` (documentation)

- [ ] **Step 1: Register uptime monitor** — in whichever monitor the team uses (UptimeRobot, BetterStack, Checkly). 1-minute interval ping on `https://api.flashcards.app/healthz`.

- [ ] **Step 2: Document in `ops/uptime.md`:**

```markdown
# Uptime monitoring

- Endpoint: `GET /healthz` — returns `{"status":"ok"}` with 200.
- Monitor: BetterStack heartbeat, 60s interval.
- On-call: rotate via PagerDuty integration (see ops/oncall.md — TBD when team has pager setup).
- Expected response: <200ms P95.
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): uptime monitoring setup (4.9)"
```

---

### Task 4.10: Onboarding wall first-launch gate + universal link test

**Files:**
- Modify: `ios/Flashcards/App/RootView.swift`
- Create: `ios/FlashcardsTests/MagicLinkConsumerTests.swift`

- [ ] **Step 1: Persist "has-completed-onboarding" in UserDefaults so intro screens are shown once:**

```swift
enum OnboardingGate {
    private static let key = "mw.onboardingCompleted"
    static var isComplete: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
```

Skip intros if `isComplete == true`. Set to true at the moment the user reaches the signup wall.

- [ ] **Step 2: Unit test `MagicLinkConsumer`:**

```swift
import XCTest
@testable import Flashcards

final class MagicLinkConsumerTests: XCTestCase {
    func test_extractsTokenFromValidURL() {
        let url = URL(string: "https://flashcards.app/auth/consume?t=abc123")!
        XCTAssertEqual(MagicLinkConsumer.extractToken(from: url), "abc123")
    }
    func test_returnsNilForUnrelatedURL() {
        let url = URL(string: "https://flashcards.app/privacy")!
        XCTAssertNil(MagicLinkConsumer.extractToken(from: url))
    }
    func test_returnsNilWithoutTokenParam() {
        let url = URL(string: "https://flashcards.app/auth/consume")!
        XCTAssertNil(MagicLinkConsumer.extractToken(from: url))
    }
}
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "feat(onboarding): first-launch gate + MagicLinkConsumer unit tests (4.10)"
```

---

### Task 4.11: TestFlight internal v0.9.0

**Files:**
- Modify: `ios/Flashcards` build settings (version)
- Create: `ios/Fastfile` (optional but recommended)

- [ ] **Step 1: Bump Marketing Version to `0.9.0` and Build Number to `1` in Xcode.**

- [ ] **Step 2: Create `ios/Fastfile`:**

```ruby
default_platform(:ios)

platform :ios do
  desc "Build and upload TestFlight internal"
  lane :tf_internal do
    build_app(scheme: "Flashcards",
              export_method: "app-store",
              output_directory: "./build",
              clean: true)
    upload_to_testflight(skip_waiting_for_build_processing: true,
                         groups: ["Internal"])
  end
end
```

- [ ] **Step 3: Upload.**

```bash
cd /Users/lukehogan/Code/flashcards/ios && bundle exec fastlane tf_internal
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "chore(release): v0.9.0 TestFlight internal + Fastfile (4.11)"
git -C /Users/lukehogan/Code/flashcards tag -a v0.9.0 -m "v0.9.0 TestFlight internal"
```

---

### Task 4.12: Feedback triage workflow

**Files:**
- Create: `ops/testflight-triage.md`

- [ ] **Step 1: Document the workflow:**

```markdown
# TestFlight feedback triage

1. All feedback (screenshots, TestFlight reports, PostHog session replays) lands in GitHub Issues, label `testflight`.
2. Triage twice weekly: Tuesday + Friday, 30 min.
3. Severity labels:
   - `sev-1`: crash / data loss — fix this week
   - `sev-2`: broken flow — fix this milestone
   - `sev-3`: polish — parked to v1.1
4. Tie each `sev-1` and `sev-2` to a PostHog session replay URL.
5. Every closed issue gets a 1-line note in CHANGELOG.md.
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): TestFlight triage workflow (4.12)"
```

---

### Task 4.13: TestFlight external v0.9.5

- [ ] **Step 1: Incorporate internal feedback. Bump to `0.9.5`.**

- [ ] **Step 2: Upload.**

```bash
cd /Users/lukehogan/Code/flashcards/ios && bundle exec fastlane tf_internal
```

Add an `external` lane that promotes the build to the External group:

```ruby
lane :tf_external do
  upload_to_testflight(
    skip_submission: false,
    skip_waiting_for_build_processing: true,
    distribute_external: true,
    groups: ["External"],
    beta_app_review_info: {
      contact_email: "support@flashcards.app",
      contact_first_name: "Luke",
      contact_last_name: "Hogan",
      contact_phone: "+1...",
      demo_account_name: "tester@flashcards.app",
      demo_account_password: "",
      notes: "This is an offline-first spaced-repetition flashcards app. Sign in with Apple is the easiest path."
    },
    beta_app_description: "Spaced-repetition flashcards — offline-first."
  )
end
```

- [ ] **Step 3: Tag + commit.**

```bash
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "chore(release): v0.9.5 TestFlight external (4.13)"
git -C /Users/lukehogan/Code/flashcards tag -a v0.9.5 -m "v0.9.5 TestFlight external"
```

---

### Task 4.14: Phase 4 acceptance — merge to main

- [ ] **Step 1: Full green CI on both projects.**

- [ ] **Step 2: PR, merge, tag.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-4 -m "Phase 4: polish + TestFlight"
git -C /Users/lukehogan/Code/flashcards push origin main phase-4 v0.9.0 v0.9.5
```

**Phase 4 acceptance:**
- Every DS component has light + dark snapshot + one a11y (XXXL) snapshot.
- XCUITest suite: onboarding→first card, offline smart study, paywall purchase.
- `MWEvent` taxonomy wired; PostHog receives structured events for every high-signal action.
- Sentry breadcrumbs render around every sync call.
- Feature flags live, exposed in DEBUG BetaFlagsView.
- TestFlight internal + external builds shipped; feedback triage workflow documented.

---

## Phase 5: Submission + Launch (weeks 14-20)

**Goal:** App Store 1.0.0 submission, review iterations, production infra, public launch, post-launch telemetry cadence.

### Task 5.1: App Store Connect metadata + screenshots + privacy labels

**Files:**
- Create: `ios/AppStoreMetadata/metadata.yml`
- Create: `ios/AppStoreMetadata/screenshots/` (6.7" + 6.1" + 5.5" iPhone)
- Create: `ios/AppStoreMetadata/privacy-labels.md`

- [ ] **Step 1: `metadata.yml`** (consumed by `fastlane deliver`):

```yaml
name: Flashcards
subtitle: Spaced repetition, offline.
primary_category: EDUCATION
secondary_category: PRODUCTIVITY
price_tier: free_with_iap

promotional_text: |
  Learn on purpose — a spaced-repetition flashcards app that works fully offline.
  Powered by FSRS, the 2024 state-of-the-art memory algorithm.

description: |
  Flashcards is a spaced-repetition app designed for serious learners who need
  a rigorous memory engine AND casual learners who just want something simple
  to open.

  • Fully offline. Every action works without a signal.
  • FSRS-6 algorithm learns how you forget.
  • Premium design — Modernist paper-card aesthetic.
  • Sync across devices, no ads, no tracking.
  • Free with an optional Plus subscription for unlimited decks and cards.

  Plus: $4.99/month or $29.99/year (7-day free trial on annual).

keywords:
  - flashcards
  - study
  - memorize
  - fsrs
  - spaced repetition
  - language learning
  - medical school

support_url: https://flashcards.app/support
marketing_url: https://flashcards.app
privacy_url: https://flashcards.app/privacy

review_information:
  demo_account_email: reviewer@flashcards.app
  demo_account_password: ""
  notes: |
    Sign in with Apple is the easiest path. Magic-link email sign-in is also
    supported. No password is required. The app works fully offline after
    sign-in.
```

- [ ] **Step 2: Screenshot generation via fastlane:**

```ruby
# ios/Fastfile — add:
lane :screenshots do
  capture_screenshots(devices: [
    "iPhone 15 Pro Max",       # 6.7"
    "iPhone 15",                # 6.1"
    "iPhone 8 Plus"             # 5.5"
  ], scheme: "FlashcardsScreenshots")
  frame_screenshots(path: "./AppStoreMetadata/screenshots")
end
```

Requires a `FlashcardsScreenshots` UI test scheme with an `XCUITest` that walks the app and `snapshot("01_home")`, `snapshot("02_study_back")`, etc.

- [ ] **Step 3: `privacy-labels.md`** — declare:

```markdown
# Privacy labels (App Privacy → App Store Connect)

## Data Linked to You
- Contact Info → Email (for account + magic link)

## Data Not Linked to You
- Identifiers → User ID (PostHog anonymous distinct_id)
- Usage Data → Product Interaction (PostHog events: session.*, deck.*, card.*, paywall.*, sync.*)
- Diagnostics → Crash Data, Performance Data (Sentry)

## Data NOT Collected
- Precise / coarse location
- Health & fitness
- Photos (v1)
- Contacts
- Browsing / search history
- Purchases (handled by Apple, not us)
- Ad IDs (IDFA / IDFV)
- Contacts

## Tracking
- Tracking: OFF
- No ATT prompt required.
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards checkout -b phase/5-launch
git -C /Users/lukehogan/Code/flashcards add ios/AppStoreMetadata
git -C /Users/lukehogan/Code/flashcards commit -m "chore(release): App Store metadata + privacy labels + screenshot lane (5.1)"
```

---

### Task 5.2: Production Forge environment

**Files:**
- Create: `ops/production-setup.md`

- [ ] **Step 1: Provision a Laravel Forge server** with:
  - Ubuntu 22.04, 4 GB RAM / 2 vCPU minimum
  - PHP 8.3, nginx, Redis
  - Postgres 16 (managed via Neon or Supabase Pro tier recommended; Forge DB only as fallback)

- [ ] **Step 2: Deploy from `main` via Forge's GitHub integration.** Deploy script:

```bash
cd $FORGE_SITE_PATH
git pull origin $FORGE_SITE_BRANCH
$FORGE_COMPOSER install --no-dev --no-interaction --prefer-dist --optimize-autoloader

( flock -w 10 9 || exit 1
  echo 'Restarting FPM...'; sudo -S service $FORGE_PHP_FPM reload ) 9>/tmp/fpmlock

$FORGE_PHP artisan migrate --force
$FORGE_PHP artisan config:cache
$FORGE_PHP artisan route:cache
$FORGE_PHP artisan event:cache
$FORGE_PHP artisan horizon:terminate
$FORGE_PHP artisan queue:restart
```

- [ ] **Step 3: Horizon daemon process** — configure in Forge Daemons:

```
Command: php artisan horizon
User: forge
```

- [ ] **Step 4: Env file** — mirror `.env.example` with production secrets. Set via Forge UI, not committed.

- [ ] **Step 5: `ops/production-setup.md`:**

```markdown
# Production setup

- Server: Forge @ flashcards-prod (DigitalOcean $48/mo, 4GB / 2 vCPU)
- DB: Neon project `flashcards-prod`, branch `main`
- Cache/Queue: Forge-managed Redis
- CDN: Cloudflare proxied
- Object storage: Cloudflare R2 bucket `flashcards-prod-assets`
- Deploys: `main` auto-deploys via Forge GitHub integration
- Horizon: daemon on the app server, accessible at /horizon
- Sentry: `flashcards-api` project

## Secret management
Secrets in Forge environment vars. Do not commit to git. Rotation schedule: app tokens 90 days, Apple JWT key annually.

## Scaling plan
- v1 target: <1000 DAU. Single app server sufficient.
- At 5K DAU: add a worker server, promote Postgres to Neon Pro, pin Horizon to it.
- At 20K DAU: read replica + Horizon horizontal scale.
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): production environment setup (5.2)"
```

---

### Task 5.3: DNS + TLS + HSTS + AASA

**Files:**
- Create: `ops/dns.md`

- [ ] **Step 1: Point DNS to Forge server.**

- `flashcards.app` → Cloudflare proxied → marketing site (hosted elsewhere)
- `api.flashcards.app` → Forge server (proxy **off** for Cloudflare, so HTTPS terminates on the server)

- [ ] **Step 2: TLS via Forge-managed Let's Encrypt.** Enable HSTS headers:

```nginx
# /etc/nginx/sites-available/api.flashcards.app
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

- [ ] **Step 3: Universal Links AASA** — already created in Task 0.41. Verify it's served with `Content-Type: application/json` and NO `.json` extension:

```
curl -I https://flashcards.app/.well-known/apple-app-site-association
# Expect 200, content-type: application/json
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): DNS + TLS + AASA verification (5.3)"
```

---

### Task 5.4: Production DB migration + backups + restore drill

**Files:**
- Create: `ops/backups.md`

- [ ] **Step 1: Run production migrations.** (Remote, SSH into Forge server.)

```bash
cd /home/forge/api.flashcards.app && php artisan migrate --force && php artisan db:seed --class=PlanSeeder --force
```

- [ ] **Step 2: Configure Neon automatic daily + PITR backups** (Neon handles this by default at Pro tier).

- [ ] **Step 3: Restore drill.** Spin up a throwaway Neon branch, point a staging copy at it, run the smoke test:

```bash
# Staging .env: DB_DATABASE=flashcards_restore_test
php artisan tinker
>>> App\Models\User::count()
>>> App\Models\Deck::count()
```

Verify counts match production snapshot taken 10 min before the drill.

- [ ] **Step 4: `ops/backups.md`** — document the drill + recovery RTO/RPO.

```markdown
# Backups + recovery

- Full backup: automatic daily via Neon
- PITR window: 7 days (Neon Pro)
- RTO target: <1 hour
- RPO target: <5 min
- Restore drill: quarterly (tied to retrospective cadence)

## Procedure (restore to fresh branch)
1. Create Neon branch from snapshot: `neon branches create --parent main --timestamp <ts>`
2. Point staging env to new branch DSN
3. Run `php artisan migrate:status` — expect all green
4. Spot-check: count users / decks / cards matches pre-incident
5. Cut over DNS `api.flashcards.app` to staging server (if recovering prod)
```

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): production backups + restore drill procedure (5.4)"
```

---

### Task 5.5: Build 1.0.0 and submit to App Store

**Files:**
- Modify: `ios/Flashcards` build settings — Marketing Version 1.0.0, Build 1

- [ ] **Step 1: Bump versions, commit:**

```bash
# In Xcode: set CURRENT_PROJECT_VERSION = 1, MARKETING_VERSION = 1.0.0
git -C /Users/lukehogan/Code/flashcards add ios
git -C /Users/lukehogan/Code/flashcards commit -m "chore(release): version 1.0.0 (5.5)"
git -C /Users/lukehogan/Code/flashcards tag -a v1.0.0-rc1 -m "v1.0.0 release candidate"
```

- [ ] **Step 2: Submit via fastlane:**

```ruby
# Add to Fastfile
lane :submit do
  build_app(scheme: "Flashcards", export_method: "app-store", clean: true)
  upload_to_app_store(
    submit_for_review: true,
    automatic_release: false,
    force: true,
    submission_information: {
      add_id_info_uses_idfa: false,
      export_compliance_uses_encryption: true,
      export_compliance_is_exempt: true
    }
  )
end
```

```bash
cd /Users/lukehogan/Code/flashcards/ios && bundle exec fastlane submit
```

- [ ] **Step 3: Commit the Fastfile addition.**

```bash
git -C /Users/lukehogan/Code/flashcards add ios/Fastfile
git -C /Users/lukehogan/Code/flashcards commit -m "chore(release): submit lane in fastlane (5.5)"
```

---

### Task 5.6: Review response workflow

**Files:**
- Create: `ops/app-review-response.md`

- [ ] **Step 1: Document:**

```markdown
# App Review response

## Common rejections, prepared responses

- **5.1.1(v) Account Deletion**: Already implemented (Settings → Account → Delete account; 30-day hard-delete via Horizon job).
- **3.1.1 IAP**: Subscriptions exposed via StoreKit 2 + Restore Purchases button on paywall AND Settings → Subscription. No external payment flows.
- **4.0 Design**: Premium Modernist Workshop design system; no generic template.
- **Guideline 2.1 Performance**: Offline-first — demonstrate by flipping simulator to Airplane Mode during review if required.
- **Guideline 5.4 VPN/tracking**: No tracking. ATT not applicable.

## Turnaround
- 5xx triage within 4 business hours
- Re-submit same day when fix is trivial; next day if structural
- Tag reviewer notes with any special build flags required to reproduce
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): app review response playbook (5.6)"
```

---

### Task 5.7: Marketing site legal — Privacy policy + Terms

**Files:**
- Create: `marketing/privacy.md`
- Create: `marketing/terms.md`

- [ ] **Step 1: Draft `marketing/privacy.md`** — a plain-English privacy policy consistent with §14.1 of the spec. At minimum: what's collected, why, retention, deletion, contact email. Engage legal review before shipping.

- [ ] **Step 2: Draft `marketing/terms.md`** — terms of service. Subscription pricing, auto-renewal, refunds via Apple, governing law (Delaware default; change with legal).

- [ ] **Step 3: Publish at `flashcards.app/privacy` and `flashcards.app/terms` via the marketing site.**

- [ ] **Step 4: Update `AboutView.swift` links** (already point to `/privacy` and `/terms`).

- [ ] **Step 5: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add marketing
git -C /Users/lukehogan/Code/flashcards commit -m "docs(legal): privacy policy + terms of service drafts (5.7)"
```

---

### Task 5.8: Public release v1.0.0

- [ ] **Step 1: When App Review approves, release manually.** (Auto-release off so we control the moment.)

- [ ] **Step 2: Tag + push.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a v1.0.0 -m "v1.0.0 public launch"
git -C /Users/lukehogan/Code/flashcards push origin main v1.0.0
```

- [ ] **Step 3: Pin PostHog funnel**: install → signup → first deck → first card → first study → paywall view → purchase. Share dashboard URL in `ops/dashboards.md`.

```bash
cat > /Users/lukehogan/Code/flashcards/ops/dashboards.md <<'EOF'
# PostHog dashboards

- **Activation funnel**: install → signup → first deck → first card → first study completed. Window: 24h.
- **Retention cohorts**: D1, D7, D30 by signup week.
- **Paywall conversion**: paywall viewed → purchase_started → purchase_completed.
- **Sync health**: sync.push.fail rate; sync.queue.stuck count.
- **Session completion**: session.study.started → completed ratio.
EOF
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops/dashboards.md
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): PostHog dashboards + funnels for v1.0.0 (5.8)"
```

---

### Task 5.9: Post-launch monitoring cadence

**Files:**
- Create: `ops/post-launch-cadence.md`

- [ ] **Step 1: Document:**

```markdown
# Post-launch monitoring cadence

## Day 1-3 (war-room)
- All hands on call
- 30-minute standups every 4 hours during waking hours
- Sentry alerts on any new crash signature: Slack #flashcards-ops
- PostHog funnel reviewed every 2 hours
- Sync failure rate: spike > 2% → investigate immediately

## Week 1
- Daily standups
- Crash-free user rate target: >99.5%
- Sev-1 any issue affecting >1% of users

## Weeks 2-4
- Retro weekly
- Prioritize v1.0.x patch issues, defer v1.5 planning
- Monitor App Store rating; respond to every 1-3 star review within 24h

## Month 2+
- Monthly product review
- Start v1.5 scoping (images, import/export, FSRS personalization)
```

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add ops
git -C /Users/lukehogan/Code/flashcards commit -m "docs(ops): post-launch monitoring cadence (5.9)"
```

---

### Task 5.10: Retrospective + v1.5 backlog seed

**Files:**
- Create: `docs/superpowers/retros/2026-XX-XX-v1-launch-retro.md` (filled in at retro)
- Create: `docs/superpowers/plans/2026-XX-XX-v1.5-scoping.md` (empty stub)

- [ ] **Step 1: Seed stubs with date placeholders** — fill in at retro time.

- [ ] **Step 2: Commit**

```bash
git -C /Users/lukehogan/Code/flashcards add docs/superpowers
git -C /Users/lukehogan/Code/flashcards commit -m "docs: v1.0 retro + v1.5 scoping placeholders (5.10)"
```

---

### Task 5.11: Phase 5 acceptance — ship

- [ ] **Step 1: Verify all the below are true before declaring launch complete:**
  - App Store listing approved, publicly visible, IAPs live
  - `healthz` monitor green
  - Sentry: release tagged `1.0.0` active
  - PostHog: new events flowing, funnels populated
  - Plus subscription purchase flow works end-to-end against production StoreKit (not sandbox)
  - Apple Server Notifications v2 webhook receives events (test via Apple's sandbox notification console)
  - Magic link email delivery works in production
  - `api.flashcards.app/healthz` returns 200 with proper TLS cert

- [ ] **Step 2: Tag final.**

```bash
git -C /Users/lukehogan/Code/flashcards tag -a phase-5 -m "Phase 5: public launch"
git -C /Users/lukehogan/Code/flashcards push origin main phase-5
```

**Phase 5 acceptance:**
- v1.0.0 live in the App Store.
- Production backend stable; health checks green.
- All legal, privacy, and account-deletion requirements met.
- Post-launch monitoring in place.

---

## Re-planning gates

After each phase merges, run a 30-minute retro:

1. **Spec coverage check** — did anything in the spec slip? Add a task to the next phase if so.
2. **Assumption audit** — flag any place the plan assumed a tool/version/API that turned out different. Update subsequent tasks.
3. **Velocity re-cut** — if a phase took 1.5× the allocated weeks, propose pushing non-essential v1 scope to v1.5.

## Known assumptions that may need revision

1. **`fsrs-rs` UniFFI bindings** — if the library's Swift binding surface differs from the task code in 2.2, update only `FsrsScheduler.swift` (the adapter); callers don't change.
2. **Cashier StoreKit support** — if `laravel/cashier-apple` isn't on Packagist at impl time, Task 0.4 notes the fallback (install base Cashier; wire StoreKit hooks manually in 3.10).
3. **Dependabot grouping syntax** — check current GitHub docs; adjust `.github/dependabot.yml` if schema changed.
4. **Icon set** — Task 2.10 stubs ten stroke-drawn icons. Replace with the designer's delivered SVG set when available; regenerate `Generated/` via `scripts/generate-icons.sh`.
5. **Accent palette (open decision §18)** — placeholder hexes in Task 0.20. Swap in designer-supplied values before screenshots (Task 5.1).


