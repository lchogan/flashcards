# Flashcards

A native iOS spaced-repetition study app with an offline-first sync model and a Laravel backend for auth, sync, and subscription billing. Built for people who want short, daily study sessions that adapt to their memory instead of their schedule.

This README is written for contributors (or a founder checking in) who have some software background but aren't yet fluent in Swift, SwiftUI, or the Laravel ecosystem. It covers what the codebase is, how to run it, how we work, and where to go for depth.

---

## Table of contents

1. [What this app does](#what-this-app-does)
2. [Repository layout](#repository-layout)
3. [Technology stack](#technology-stack)
4. [Architecture at a glance](#architecture-at-a-glance)
5. [Getting started](#getting-started)
6. [Development workflow](#development-workflow)
7. [Testing](#testing)
8. [Continuous integration (CI)](#continuous-integration-ci)
9. [Code conventions](#code-conventions)
10. [Design system](#design-system)
11. [Authentication](#authentication)
12. [Data model](#data-model)
13. [Deployment](#deployment)
14. [Phases and the implementation plan](#phases-and-the-implementation-plan)
15. [Glossary](#glossary)

---

## What this app does

Flashcards is a spaced-repetition learning tool. A user creates decks of cards, studies them in short sessions, and the app uses an FSRS-family algorithm to decide when to show each card next — roughly: cards you nearly-forgot come back soon, cards you remember easily come back later.

Key product choices:

- **Offline-first.** Every action (creating a card, answering a review) works without network. A sync engine reconciles with the server in the background.
- **Two sign-in options:** Sign in with Apple (native to iOS) and email magic-link (no passwords).
- **Subscription monetization.** Free tier with limits, Plus tier unlocked via Apple In-App Purchase.
- **Modernist Weekly design system** (`MW`): ink-on-paper, border-first, shadow-averse. Every visual is a token so the brand stays coherent as the app grows.

The full product spec and week-by-week implementation plan live in `docs/superpowers/plans/2026-04-21-flashcards-implementation-plan.md`.

---

## Repository layout

```
flashcards/
├── api/                      # Laravel 11 backend (PHP 8.3+)
│   ├── app/                  # Application code (Models, Controllers, Services, Jobs)
│   ├── config/               # Laravel config files
│   ├── database/             # Migrations and factories
│   ├── routes/               # HTTP routes (api.php is the one we care about)
│   ├── tests/                # Pest tests (Feature + Unit)
│   ├── composer.json         # PHP dependencies
│   ├── phpstan.neon          # Static analysis config (level 6)
│   └── pint.json             # Code style config
├── ios/                      # Native iOS app
│   ├── Flashcards/           # App source
│   │   ├── App/              # @main entry + AppState + RootView
│   │   ├── Analytics/        # PostHog + Sentry facade
│   │   ├── DesignSystem/     # Tokens, modifiers, atoms (MW-prefixed)
│   │   ├── Features/         # Feature folders (Auth/, Onboarding/, later: Decks/, Study/)
│   │   ├── Networking/       # APIClient + APIError + APIEndpoint
│   │   └── Assets.xcassets   # Color sets (light + dark variants)
│   ├── FlashcardsTests/      # Unit + snapshot tests
│   ├── FlashcardsUITests/    # UI tests (minimal; most coverage is unit+snapshot)
│   ├── project.yml           # xcodegen source of truth (see "xcodegen" below)
│   └── Flashcards.xcodeproj/ # Generated from project.yml — don't hand-edit
├── docs/                     # Plans, ADRs, specs
│   └── superpowers/plans/    # Week-by-week implementation plan
├── Mockup/                   # Design mockups (excluded from source builds)
└── .github/workflows/        # GitHub Actions CI definitions (api.yml + ios.yml)
```

Two top-level projects live in this monorepo because the iOS app and the API co-evolve — changing an API response shape often needs a paired iOS change, and keeping them in one repo means one PR covers both sides.

---

## Technology stack

### iOS (`ios/`)

| Tech | What it is | Why we use it |
|---|---|---|
| Swift 6 (strict concurrency) | Apple's language, newest version | Compile-time data-race safety — the compiler catches threading bugs before they ship |
| SwiftUI | Apple's declarative UI framework | Modern, composable, plays well with the `@Observable` state model |
| `@Observable` + `@Environment` | Observation framework (iOS 17+) | Replaces the older `ObservableObject`/`@StateObject` pattern; cleaner and more efficient |
| `actor` types | Swift's concurrency primitive for shared state | Used for `TokenStore` (Keychain) and `APIClient` — prevents data races on mutable state |
| SwiftData | Apple's persistence framework | Will be wired in Phase 1 for the local database |
| [xcodegen](https://github.com/yonaskolb/XcodeGen) | Generates `.xcodeproj` from YAML | Keeps the Xcode project file diff-able and mergeable; no more `project.pbxproj` merge conflicts |
| [SwiftLint](https://github.com/realm/SwiftLint) | Style + custom-rule enforcer | Runs as a pre-build script; strict mode means any violation fails the build |
| [swift-format](https://github.com/swiftlang/swift-format) | Apple's official formatter | Authoritative on whitespace/commas; integrated with SwiftLint |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Keychain wrapper | Stores auth tokens securely |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | pointfree's snapshot library | Renders views to PNG and asserts against committed baselines |
| [PostHog](https://posthog.com/) iOS SDK | Product analytics | Event tracking for retention/funnel analysis |
| [Sentry](https://sentry.io/) iOS SDK | Crash + error reporting | Production error surface |

### Backend (`api/`)

| Tech | What it is | Why we use it |
|---|---|---|
| PHP 8.3+ | Server-side language | Laravel's runtime; modern type system |
| [Laravel 11](https://laravel.com/) | PHP framework | Familiar, batteries-included, excellent ecosystem |
| [Sanctum](https://laravel.com/docs/sanctum) | Laravel's first-party API-token auth | Issues/validates the bearer tokens iOS uses |
| [Pest](https://pestphp.com/) v3 | Testing framework | Test-runner that sits on PHPUnit with better ergonomics |
| [PHPStan](https://phpstan.org/) level 6 (via Larastan) | Static analysis | Type-checks PHP before runtime |
| [Pint](https://laravel.com/docs/pint) | Laravel's opinionated style formatter | Zero-config formatter, runs in CI |
| [firebase/php-jwt](https://github.com/firebase/php-jwt) v7 | JWT library | Used to verify Apple ID tokens against Apple's JWKS |
| [Cashier](https://laravel.com/docs/billing) | Laravel's billing wrapper (Phase 2+) | Will handle App Store Server notifications |
| [Horizon](https://laravel.com/docs/horizon) | Redis queue dashboard (Phase 2+) | Background job monitoring |
| PostgreSQL 14+ | Production database | Strict types, robust migrations, production-proven |
| SQLite (tests only) | In-memory test database | Fast, hermetic test runs |

### Infrastructure

| Tech | Purpose |
|---|---|
| [GitHub Actions](https://docs.github.com/en/actions) | CI — see [`.github/workflows/`](.github/workflows/) |
| GitHub Pull Requests | Code review + merge gate |
| Apple Developer Program (Team ID `UWK6JHFFGJ`) | iOS code signing, App Store distribution |
| Bundle ID `com.lukehogan.flashcards` | iOS app identifier |

---

## Architecture at a glance

```
┌──────────────────┐                 ┌──────────────────┐
│   iOS app        │                 │   Laravel API    │
│                  │                 │                  │
│  SwiftUI views   │                 │  Controllers     │
│       │          │                 │       │          │
│   AuthManager ───┼─ HTTPS ────────►│  Services        │
│   SyncManager    │  Bearer token   │       │          │
│       │          │                 │  Models          │
│  SwiftData       │                 │       │          │
│  (local DB)      │                 │  PostgreSQL      │
│       │          │                 │                  │
│  TokenStore      │                 │  Redis (jobs)    │
│  (Keychain)      │                 │                  │
└──────────────────┘                 └──────────────────┘
```

**The iOS app is the primary experience.** The API exists to:
1. Authenticate users (Apple Sign In + magic link).
2. Sync each user's local database to the server so they never lose data.
3. Verify App Store receipts for paid subscriptions.
4. Send transactional email (magic-link delivery, reminders).

**Offline-first** means the iOS app reads and writes its local SwiftData store immediately, then queues a background sync to the server. If the network is unavailable, nothing in the UI cares — the sync queue drains when connectivity returns.

---

## Getting started

### Prerequisites

- **macOS 14+** with **Xcode 16+** (for Swift 6 + iOS 17+ APIs)
- **PHP 8.3+**: `brew install php`
- **Composer**: `brew install composer`
- **xcodegen**: `brew install xcodegen`
- **SwiftLint**: `brew install swiftlint`
- **PostgreSQL 14+** (optional for tests, required for real dev): `brew install postgresql@16 && brew services start postgresql@16`
- **GitHub CLI** (`gh`) for PR work: `brew install gh`, then `gh auth login`

### Clone and set up

```bash
git clone git@github.com:lchogan/flashcards.git
cd flashcards
```

### Backend (api/)

```bash
cd api
composer install
cp .env.example .env                    # if it doesn't exist, see note below
php artisan key:generate                # generates APP_KEY in .env
php artisan migrate                     # runs migrations against whatever DB_CONNECTION is set
php artisan serve                       # starts dev server at http://localhost:8000
```

> **About `.env`**: Laravel loads environment variables from `api/.env`. The `.env.example` file is the template. For local dev, the defaults work for SQLite; switch `DB_CONNECTION=pgsql` to use PostgreSQL. The `.env` file is git-ignored — never commit secrets.

To verify the backend:

```bash
curl http://localhost:8000/healthz
# => 200 OK
```

### iOS (ios/)

```bash
cd ios
xcodegen generate        # regenerates Flashcards.xcodeproj from project.yml
open Flashcards.xcodeproj
```

In Xcode:
- Select the **Flashcards** scheme and an iPhone simulator.
- Press **⌘R** to build and run.
- Press **⌘U** to run tests.

> **About `project.yml`**: This YAML file is the source of truth for the Xcode project — dependencies, build settings, file groups. If you add a new Swift file, just drop it in the right folder; running `xcodegen generate` picks it up automatically. **Never hand-edit `Flashcards.xcodeproj`** — your changes will be overwritten the next time anyone runs xcodegen.

---

## Development workflow

### Branches

- **`main`** is the deployable branch. Never commit directly to it.
- **`phase/N-name`** branches track major implementation phases (e.g. `phase/0-foundation`, `phase/1-data-sync`).
- **Feature branches** use descriptive names: `fix/token-rotation`, `feat/deck-importer`.

### Commits

We follow a loose [Conventional Commits](https://www.conventionalcommits.org/) style:

```
<type>(<scope>): <what> (<task-id>)

<why, in prose if non-trivial>

Co-Authored-By: <collaborator>
```

Types used in this repo:
- `feat` — new feature
- `fix` — bug fix
- `refactor` — code restructure, no behavior change
- `test` — test-only changes
- `docs` — documentation-only changes
- `chore` — tooling, config, housekeeping
- `ci` — CI workflow changes

The scope in parens is the affected subsystem: `ds` (design system), `auth`, `net` (networking), `onboarding`, `test`. The `(0.xx)` suffix references the implementation plan task.

Example:
```
feat(auth): POST /v1/auth/apple endpoint (0.33)

Verifies an Apple identity token via AppleIdentityVerifier,
firstOrCreates the user on (apple, subject), and returns a
15-min access token + 90-day refresh token.
```

### Pull requests

**Every change lands via a PR, never direct to `main`.** This is true even for solo-developer stretches. The PR is where CI runs, where the diff is reviewable, and where the change becomes revertible as a unit.

To open a PR:

```bash
git checkout -b feat/my-change
# ... commits ...
git push -u origin feat/my-change
gh pr create --base main --title "feat: my change" --body "Summary..."
```

Or use the GitHub web UI after pushing.

The PR triggers two CI workflows (`API` and `iOS`). Both must pass before merge. Use the merge button on the GitHub PR page, or:

```bash
gh pr merge <number> --merge       # merge commit (preserves individual commits)
gh pr merge <number> --squash      # squash to one commit (good for small PRs)
gh pr merge <number> --rebase      # linear history, no merge commit
```

We use `--merge` for big phase branches (preserves granular history) and `--squash` for small feature/fix PRs (keeps `main` linear).

### Tags

Major milestones are tagged. Phase 0's completion is tagged `phase-0`. To see all tags:

```bash
git tag -l
```

To find what commit a tag points at:

```bash
git show phase-0
```

---

## Testing

### Backend

```bash
cd api
./vendor/bin/pest                          # run all tests
./vendor/bin/pest tests/Feature/AppleAuthTest.php     # run one file
./vendor/bin/pest --filter="valid token"   # filter by test name
./vendor/bin/pint --test                   # style check (no auto-fix)
./vendor/bin/pint                          # style check + fix
./vendor/bin/phpstan analyse --memory-limit=1G   # static analysis
```

Tests run against an in-memory SQLite database (configured in `phpunit.xml`), so they're fast and don't require PostgreSQL to be running.

### iOS

```bash
cd ios
xcodebuild -project Flashcards.xcodeproj \
  -scheme Flashcards \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test

swiftlint --config .swiftlint.yml --strict Flashcards
```

Or in Xcode: **⌘U** runs the full test suite; **⌃⌘U** reruns the most recent test.

**Snapshot tests** capture rendered views as PNGs and compare against committed baselines. The baselines live in `ios/FlashcardsTests/__Snapshots__/`. When a view legitimately changes, delete the stale PNG and re-run the test in record mode — see `DesignSystemSnapshotTests.swift` for the pattern.

---

## Continuous integration (CI)

**What CI is:** a robot that runs your tests automatically on every push and PR, in a clean environment on GitHub's servers. It posts pass/fail results back to the PR as a green check or red X. Merging is blocked until the checks pass (once branch protection is enabled).

**Two workflows** live in `.github/workflows/`:

- **`api.yml`** — sets up PHP 8.3, runs `pint --test`, `phpstan analyse`, and `pest` against a clean install.
- **`ios.yml`** — on a macOS runner, installs Xcode + SwiftLint, runs `swiftlint --strict` and `xcodebuild test`.

**Why CI matters:**

1. **Catches environment drift.** Code that works on your machine may fail on a fresh install because of a cached dependency or stale env var. CI starts from zero every time.
2. **Tests the merged state.** GitHub creates a hypothetical merge commit (your branch + latest main) and tests *that* — catches merge-induced breakage your branch alone can't see.
3. **Provides enforcement surface.** Branch protection rules rely on CI results; without CI, protection can't gate anything useful.

**Watching CI:**

```bash
gh run list --limit 5           # recent runs
gh run view <run-id>            # drill into one run's logs
gh pr checks <pr-number>        # see the checks on a specific PR
```

Each workflow run is also linked from the PR page on GitHub.

**Cost:** GitHub Actions is free on public repos. Private repos get 2000 minutes/month free on personal plans. macOS runners cost 10× Linux minutes — this is why the iOS workflow is the budget driver.

---

## Code conventions

### Universal (both sides)

- **Every non-trivial file opens with a module-level docblock** naming its purpose, dependencies, and key concepts. This is enforced by convention, not by a linter — reviewers call it out.
- **Comments explain *why*, not *what*.** Well-named identifiers document behavior; comments document intent, business rules, workarounds, or non-obvious constraints.
- **No dead code.** Unused imports, functions, or variables get removed, not commented out.
- **Domain language over programming jargon.** `issuedAt` beats `timestamp1`. `MWButton` names the button atom, not `ReusableStyledButtonComponent`.

### Backend

- `declare(strict_types=1);` at the top of every PHP file.
- Pint handles formatting (run automatically in CI).
- PHPStan level 6 enforces types — resolve all errors, don't add `@phpstan-ignore` unless truly necessary.
- Pest for tests. Prefer `test('descriptive name', function () { ... })` over `it()` for new tests.
- Controllers stay thin: validate → delegate to a Service or Action → return a Response. Business logic lives in services.
- FormRequests (`app/Http/Requests/`) handle input validation so controllers never `$request->validate(...)` inline.

### iOS

- **Swift 6 strict concurrency is on.** Expect isolation boundaries to matter: `@MainActor` for anything that touches UI, `actor` for shared mutable state, `Sendable` conformances where generic types cross actor boundaries.
- **The design-system invariant:** views in `Features/**` never reference raw colors, fonts, or literal padding. Everything routes through `MWColor`, `MWType`, `mwPadding`, etc. A SwiftLint rule (`no_literal_color_hex`, `no_system_color_literals`, `no_literal_padding`) enforces this at build time — violations fail the build.
- SwiftLint strict (`--strict`) is wired into the Xcode pre-build script — every build fails on warnings, not just errors.
- swift-format is authoritative on formatting disagreements (currently only affects trailing-comma placement).

---

## Design system

The **Modernist Weekly** (`MW`) design system sits in `ios/Flashcards/DesignSystem/`:

```
DesignSystem/
├── Tokens/           # Raw design constants
│   ├── Colors.swift      (MWColor.ink, MWColor.paper, MWAccent enum)
│   ├── Typography.swift  (MWType.display, MWType.bodyL, etc.)
│   ├── Spacing.swift     (MWSpacing.xs through .xxxl, plus .mwPadding modifier)
│   ├── Radii.swift       (MWRadius.xs/.s/.m/.l)
│   ├── Borders.swift     (MWBorder.hair/.defaultWidth/.bold, .mwStroke modifier)
│   ├── Shadows.swift     (MWShadow — used sparingly; border-first aesthetic)
│   ├── Motion.swift      (MWMotion.instant/.quick/.standard; reduce-motion wrapper)
│   └── Control.swift     (MWControl.Height.primary/.compact — button hit targets)
├── Modifiers/        # Reusable SwiftUI view modifiers
│   ├── MWCard.swift        (.mwCard())
│   ├── MWButtonPress.swift (.mwButtonPress(isPressed:) — reduce-motion-safe)
│   └── MWScreenChrome.swift (.mwScreenChrome() — navigation-bar styling)
├── Styles/           # ButtonStyles
│   ├── MWPrimaryButtonStyle.swift
│   ├── MWSecondaryButtonStyle.swift
│   └── MWDestructiveButtonStyle.swift
├── Components/
│   ├── Atoms/        # Small composable UI pieces
│   │   ├── MWButton.swift
│   │   ├── MWTextField.swift
│   │   ├── MWPill.swift
│   │   ├── MWDot.swift
│   │   ├── MWDivider.swift
│   │   └── MWEyebrow.swift
│   └── Layout/
│       └── MWScreen.swift  (root screen container with optional grid overlay)
└── EnvironmentKeys/
    └── MWAccentKey.swift   (per-deck accent color via @Environment(\.mwAccent))
```

**Key rules:**
- All color values live in the Asset Catalog (`Assets.xcassets/mw/*.colorset`) with light + dark variants. `MWColor.ink` resolves to `Color("mw/ink")`.
- Every button style (`.mwPrimary`, `.mwSecondary`, `.mwDestructive`) delegates press feedback to `.mwButtonPress` — this is the one place that reads `@Environment(\.accessibilityReduceMotion)` and collapses the scale animation when Reduce Motion is on.
- Snapshot baselines in `FlashcardsTests/__Snapshots__/` pin the visual state of the atoms; any regression surfaces as a failing test.

---

## Authentication

The app supports two sign-in paths, both producing Sanctum bearer tokens for the API:

### Sign in with Apple

1. iOS: `AppleSignInService` presents `ASAuthorizationController`, returns an Apple identity token (JWT).
2. iOS: `AuthManager` POSTs the identity token to `/api/v1/auth/apple`.
3. API: `AppleIdentityVerifier` fetches Apple's JWKS, verifies the token signature + audience + issuer, extracts `sub` and `email`.
4. API: `User::firstOrCreate` on `(auth_provider='apple', auth_provider_id=sub)`.
5. API: Issues a 15-minute access token + 90-day refresh token.
6. iOS: `TokenStore` persists both in the Keychain.

### Magic link

1. User enters email on `SignUpWallView`. iOS POSTs `/api/v1/auth/magic-link/request`.
2. API: `MagicLinkService` generates a 64-hex-char token, stores `sha256(token)` + email in `pending_email_auths` with 15-min TTL.
3. API: `SendMagicLinkEmail` job sends the user a URL like `https://flashcards.app/auth/consume?t={token}`.
4. User taps the link on their iPhone. iOS receives it as a **universal link** (validated against the app's `Associated Domains` entitlement + the `apple-app-site-association` file served from `api/public/.well-known/`).
5. iOS: `MagicLinkConsumer.extractToken(from:)` parses the URL, posts a `Notification`. `RootView` observer calls `AuthManager.consumeMagicLink(token:)`.
6. iOS: POSTs `/api/v1/auth/magic-link/consume`, which returns the same access/refresh pair.

### Token refresh

When the access token expires (15 min), iOS posts the refresh token to `/api/v1/auth/refresh`. The API validates the token's `auth:refresh` ability, issues a fresh pair, and **deletes the old refresh token** (rotation). This is wrapped in a DB transaction so partial failure doesn't leave orphaned tokens.

### Relevant files

| Concern | File |
|---|---|
| Apple token verification | `api/app/Services/Auth/AppleIdentityVerifier.php` |
| Apple endpoint | `api/app/Http/Controllers/Api/V1/AppleAuthController.php` |
| Magic-link endpoints | `api/app/Http/Controllers/Api/V1/MagicLinkController.php` |
| Magic-link token issuance | `api/app/Services/Auth/MagicLinkService.php` |
| Magic-link email job | `api/app/Jobs/SendMagicLinkEmail.php` |
| Token refresh | `api/app/Http/Controllers/Api/V1/TokenController.php` |
| iOS auth orchestration | `ios/Flashcards/Features/Auth/AuthManager.swift` |
| iOS Apple sign-in wrapper | `ios/Flashcards/Features/Auth/AppleSignInService.swift` |
| iOS Keychain storage | `ios/Flashcards/Features/Auth/TokenStore.swift` |
| Universal-link parser | `ios/Flashcards/Features/Auth/MagicLinkConsumer.swift` |

### Known follow-ups (before real traffic)

- JWKS response caching (currently re-fetches Apple's keys on every sign-in).
- Structured error mapping: `RuntimeException` → HTTP 401 with error codes.
- Account linking when the same email arrives via both Apple and magic-link paths.
- Per-email rate-limiting on `/magic-link/request` (currently per-IP).

---

## Data model

Phase 0 shipped only the `User` table. Phase 1 will add: `decks`, `topics`, `sub_topics`, `cards`, `card_sub_topics`, `reviews`, `sessions`.

### `users` table (current)

```
users
├── id                         UUID, primary key
├── email                      string, unique
├── name                       string, nullable
├── avatar_url                 string, nullable
├── auth_provider              enum('apple', 'email')
├── auth_provider_id           string, nullable (composite unique with auth_provider)
├── daily_goal_cards           unsigned smallint, default 20
├── reminder_time_local        time, nullable
├── reminder_enabled           boolean, default false
├── theme_preference           enum('system', 'light', 'dark'), default 'system'
├── fsrs_weights               json, nullable
├── subscription_status        enum('free', 'active', 'in_grace', 'expired'), default 'free'
├── subscription_expires_at    timestamp, nullable
├── subscription_product_id    string, nullable
├── image_quota_used_bytes     unsigned bigint, default 0
├── marketing_opt_in           boolean, default false
├── updated_at_ms              bigint (millisecond sync clock)
├── deleted_at_ms              bigint, nullable (tombstone)
├── created_at                 timestamp (Laravel default)
└── updated_at                 timestamp (Laravel default)
```

Migration: `api/database/migrations/0001_01_01_000000_create_users_table.php`.

**Why two `updated_at` columns?** The Laravel defaults (`created_at`, `updated_at`) are human-readable timestamps for debugging. The `updated_at_ms` / `deleted_at_ms` pair are millisecond integers used by the sync engine — they give a monotonic per-row clock that's trivial to compare across devices.

Additional tables exist for framework plumbing: `personal_access_tokens` (Sanctum), `password_reset_tokens` + `sessions` (Laravel defaults, kept for session middleware even though API auth doesn't use them), `pending_email_auths` (magic-link state).

---

## Deployment

> **Not yet set up.** Phase 0 is local-dev only. Deployment wiring lands in a later phase.

When we do deploy, the target looks like:

- **Backend:** Laravel Forge or a PaaS on an AWS/Digital Ocean VPS with PostgreSQL + Redis.
- **Apple app-site-association** (`api/public/.well-known/apple-app-site-association`) must be served at `https://flashcards.app/.well-known/apple-app-site-association` with HTTPS and a valid cert for universal links to work.
- **iOS:** TestFlight for internal builds; App Store Connect for public releases.
- **Secrets:** `APPLE_CLIENT_ID`, `SENTRY_DSN`, `POSTHOG_KEY`, database credentials — injected via environment, never committed.

The iOS app reads `POSTHOG_KEY`, `POSTHOG_HOST`, and `SENTRY_DSN` from the bundle's `Info.plist`. Real values are injected via xcconfig at build time; local dev builds have empty strings, which the `AnalyticsClient.configure()` function treats as "SDK disabled."

---

## Phases and the implementation plan

Development follows a phased plan. Each phase gets its own branch (`phase/N-name`), and the phase's completion is tagged (`phase-N`).

| Phase | Scope | Status |
|---|---|---|
| **Phase 0: Foundation** | Design system tokens + atoms, auth endpoints, iOS networking, onboarding, CI | ✅ Merged (tag `phase-0`) |
| Phase 1: Data model + sync | All 9 entities, bidirectional sync, offline-first write queue | Up next |
| Phase 2: Study + FSRS | Scheduling algorithm, review flow, daily goals | Planned |
| Phase 2.5: Content authoring | Deck/card creation UX | Planned |
| Phase 3: Subscription | Apple IAP, paywall, feature gating | Planned |
| Phase 4: Polish + accessibility | VoiceOver audit, Dynamic Type, contrast | Planned |
| Phase 5: Launch | App Store submission, marketing site | Planned |

The full plan with per-task acceptance criteria is at `docs/superpowers/plans/2026-04-21-flashcards-implementation-plan.md` (~13,000 lines; skim the table of contents at the top).

---

## Glossary

Selected terms that might be unfamiliar:

- **Actor** — Swift's concurrency primitive. An `actor` is a reference type that serializes access to its state, preventing data races by construction. Used here for `APIClient` and `TokenStore`.
- **Bearer token** — A string passed in the `Authorization: Bearer <token>` HTTP header to authenticate a request. No magic — possessing the string is the authentication. Must be kept secret.
- **FSRS** — Free Spaced Repetition Scheduler. A modern memory algorithm used to decide when to show a card next. Replaces the older SM-2 algorithm used by Anki.
- **JWKS** — JSON Web Key Set. A URL (like Apple's `https://appleid.apple.com/auth/keys`) that publishes the public keys used to verify signed tokens.
- **JWT** — JSON Web Token. A compact, signed token format used for identity. Apple's identity tokens are JWTs.
- **PAT (Personal Access Token)** — What Laravel Sanctum calls its API tokens. Not the same as a JWT — these are opaque random strings stored hashed in the database.
- **Sanctum** — Laravel's built-in API auth package. Issues, validates, and revokes PATs.
- **Sendable** — A Swift protocol marking types safe to pass across concurrency boundaries. The Swift 6 compiler enforces this.
- **Snapshot test** — A test that renders a view to a PNG and compares against a committed baseline. Fails if pixels drift.
- **Universal link** — An Apple mechanism that associates an HTTPS URL with an installed app. Tapping the link opens the app directly (instead of Safari) if the app is installed and the domain association is valid.
- **xcodegen** — A tool that generates `.xcodeproj` files from a YAML definition, so the Xcode project file is diff-able in git.

---

## Contributing

1. Branch off `main`: `git checkout -b feat/my-thing`.
2. Make changes; run tests locally.
3. Push and open a PR: `gh pr create`.
4. Wait for CI to go green.
5. Request review (or self-review), then merge via the GitHub UI or `gh pr merge`.

For larger changes (anything that touches architecture or introduces a new dependency), open a draft PR early so the conversation can happen alongside the code.

---

## Where to go next

- Code questions → start with the module-level docblock at the top of the relevant file.
- Design questions → `Mockup/` has the visual references; the `Modernist Weekly` aesthetic is documented throughout `DesignSystem/` docblocks.
- Product questions → `docs/superpowers/plans/2026-04-21-flashcards-implementation-plan.md` opens with the full spec.
- Git/GitHub workflow → the [Development workflow](#development-workflow) section above.

Welcome aboard.
