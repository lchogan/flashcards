# Flashcards — v1 Product & Technical Design Spec

**Date:** 2026-04-21
**Status:** Approved for implementation planning
**Target launch:** ~5 months from kickoff, iOS only

---

## 1. Product summary

A spaced-repetition flashcard app for iOS. Positioned as "Anki-quality engine under a Quizlet-simple surface" — rigorous for serious learners, accessible for casual ones.

**Core value propositions:**
1. An engine that actually learns you (FSRS, the 2024 state-of-the-art spaced-repetition algorithm).
2. Works fully offline; syncs when online.
3. A design system rigorous enough to feel like a serious tool without being intimidating.

**Target audience:** Dual — serious learners who'd otherwise use Anki (medical students, language learners, bar-exam prep) and general consumers who'd use Quizlet. Design hides complexity behind smart defaults.

**Differentiation from Anki:** Modern iOS-native polish, zero parameter-tuning UX, cloud sync by default, delightful design.

**Differentiation from Quizlet:** FSRS > Quizlet's simpler algorithms, true offline-first, ad-free, no social pressure features, premium design.

---

## 2. Platform & surface strategy

**v1:** Native iOS only (Swift 6 + SwiftUI).

**Platform decision rationale:** With an iOS-first launch ("Android maybe later") and a $1M build budget, native iOS yields the best quality per dollar. SwiftUI in 2026 delivers premium polish (gestures, haptics, animations, accessibility) that cross-platform frameworks cannot match at equivalent effort. If Android becomes a commitment later, we build a native Kotlin client against the same backend (~$300-500K incremental) — the backend and data model are already designed to support it.

**Not chosen:** React Native, Flutter. Both viable if Android becomes a launch-blocker; neither beats native iOS for this specific quality bar.

**Roadmap optionality:** The backend is platform-agnostic. Adding Android (native) or web (React) later is new front-end work, not a rewrite.

---

## 3. Architecture

### 3.1 System topology

```
iOS client (SwiftUI + SwiftData + on-device FSRS)
           │
           ├── APNs (push notifications)
           └── HTTPS (TLS 1.3)
                 │
             Laravel API (PHP 8.3, Laravel 11)
             ├── Postgres (managed, encrypted at rest)
             ├── Redis (queues, cache)
             ├── Horizon (queue workers)
             └── Cloudflare R2 (image object storage, signed URLs)

Third-party services:
  - Postmark / Resend — transactional email (magic links)
  - Apple App Store — subscriptions (Cashier integration)
  - Sentry — crash + error reporting (iOS + backend)
  - PostHog — product analytics
```

### 3.2 Offline-first is a core requirement

**Every user action completes with zero network.** The iOS app is the product; the backend exists to sync and persist.

Concrete rules:
- SwiftData is the source of truth on-device.
- All writes generate events in a local `PendingMutation` queue drained opportunistically.
- Client-generated UUIDs for every record — no server-assigned IDs.
- Field-level updates with record-level last-writer-wins by `updated_at`.
- Tombstones retained 90 days.
- FSRS runs on-device; server stores review history but doesn't compute schedules.
- Images uploaded via pre-signed R2 URLs directly from the client.

### 3.3 Technology choices

| Layer | Choice | Rationale |
|---|---|---|
| iOS language/UI | Swift 6, SwiftUI + UIKit drop-downs | Platform-native, best quality ceiling |
| iOS persistence | SwiftData | First-class SwiftUI integration; SQLite under the hood |
| Backend framework | Laravel 11 / PHP 8.3 | Owner familiarity; excellent scaffolding (Sanctum, Cashier, Horizon) |
| Database | Postgres (managed: Neon / Supabase / RDS) | Boring, relational, correct for this data model |
| Object storage | Cloudflare R2 | S3-compatible; cheaper egress than S3; simple signed URLs |
| Queue | Redis + Horizon | Laravel-standard |
| Auth | Sanctum JWTs | Laravel-standard token management |
| Payments | StoreKit 2 + Laravel Cashier | Native iOS + Laravel-canonical subscription handling |
| Hosting | Laravel Forge | Minimal ops overhead; can migrate to AWS later |

**Guiding principle (per owner directive): prefer integrating well-maintained packages over building from scratch. Custom code lives only where off-the-shelf doesn't fit, and only with explicit justification.**

---

## 4. Data model

### 4.1 Entities (v1)

Nine entities, all sharing common sync fields: `id (uuid, client-generated)`, `updated_at`, `deleted_at (nullable)`.

**User**
- `email`, `name`, `avatar_url`
- `auth_provider` ∈ {apple, email}, `auth_provider_id`
- `daily_goal_cards` (default 20), `reminder_time_local` (HH:MM), `reminder_enabled`
- `theme_preference` ∈ {system, light, dark}
- `fsrs_weights` (json, nullable — null = community defaults)
- `subscription_status` ∈ {free, active, in_grace, expired}
- `subscription_expires_at`, `subscription_product_id`
- `image_quota_used_bytes` (reserved; images deferred in v1)

**Deck**
- `user_id`, `title`, `description` (nullable)
- `accent_color` (token key from curated palette)
- `default_study_mode` ∈ {smart, basic}
- `topic_id` (FK to Topic, nullable)
- `card_count` (denormalized), `last_studied_at`

**Topic**
- `user_id`, `name`, `color_hint` (nullable)
- User-created only. No pre-populated system topics.

**SubTopic**
- `deck_id`, `name`, `position` (int, sortable), `color_hint` (nullable)
- First-class entity (not string tags) for rename propagation and ordering.

**Card**
- `deck_id`, `front_text`, `back_text` (markdown)
- `front_image_asset_id`, `back_image_asset_id` (reserved; v1 has no image UI)
- `position` (int)
- FSRS state: `stability` (float, nullable), `difficulty` (float, nullable), `state` ∈ {new, learning, review, relearning}
- `last_reviewed_at`, `due_at` (nullable)
- `lapses`, `reps`

**CardSubTopic** (join)
- `card_id`, `sub_topic_id`
- Composite sync-capable record.

**Review** (immutable, append-only)
- `card_id`, `user_id`, `session_id`
- `rating` ∈ {1=again, 2=hard, 3=good, 4=easy}
- `review_duration_ms`, `rated_at` (client timestamp)
- `state_before`, `state_after` (json snapshots)
- `scheduler_version` (e.g., "fsrs-6")

**Session**
- `user_id`, `deck_id`, `mode` ∈ {smart, basic}
- `started_at`, `ended_at`
- `cards_reviewed`, `accuracy_pct`, `mastery_delta` (denormalized)

**Asset** (reserved for v1.5 image support)
- `user_id`, `mime_type`, `width`, `height`, `bytes`
- `r2_key`, `local_path` (iOS-only), `upload_status` ∈ {pending, uploaded, failed}

### 4.2 Derived (not stored)

- Streak — computed from distinct review dates.
- Mastery % — computed from card state distribution within a deck.
- Weak areas — computed from sub-topic-aggregated recent accuracy.

### 4.3 Key schema decisions

1. Client-generated UUIDs everywhere. Offline deck/card creation Just Works.
2. Reviews immutable. FSRS needs the full log; we never update/delete.
3. Card FSRS state is a cache; the review log is the source of truth. A Horizon job replays reviews in timestamp order on sync.
4. Sub-topics promoted to first-class entity (not string tags). Schema cost minimal; gains are rename propagation, ordering, future per-sub-topic metadata.
5. Markdown for card content via `swift-markdown-ui` — no custom parser.
6. Soft deletes with 90-day tombstone retention.

---

## 5. Authentication

**Two methods, passwordless:**

1. **Sign in with Apple** (primary) — native `AuthenticationServices`. One tap, Face ID.
2. **Email magic link** — user enters email, receives tappable link, returns to app via Universal Link.

**No Google, no password-based sign-in.**

**Token model (Laravel Sanctum):**
- 15-minute access JWT + 90-day rotating refresh token.
- Stored in iOS Keychain via `KeychainAccess` SPM package.
- Silent refresh on access expiry.

**Onboarding wall — required sign-up at install.** Two intro screens → sign-up wall → first deck CTA.

**Sign-up wall copy (locked):**

> **Save your progress — no password required.**
>
> We ask for your email so your flashcards live in your account, not just this device. If you lose your phone, you won't lose a single card.
>
> [ Continue with Apple ]
> [ Continue with email ]
>
> *Free to use. No payment needed. We won't sell your data or email you marketing.*
>
> ☐ Send me occasional product updates (unchecked by default)

**Account deletion** — Settings → Account → Delete account. Re-auth required. Soft-delete immediately; hard-delete + R2 purge 30 days later via scheduled Horizon job. Required for App Review 5.1.1(v).

---

## 6. Sync engine

**Boring by design.** Standard REST delta sync. Five rules constitute the entire mental model:

1. Every record has `id` (client UUID), `updated_at`, `deleted_at`.
2. Pull: `GET /v1/{entity}?since={timestamp}` via `spatie/laravel-query-builder`.
3. Push: `POST /v1/sync/push` with an array of records per entity; server upserts by `id`. Incoming records with older `updated_at` than server's are ignored.
4. Reviews are insert-only (`INSERT IGNORE` on duplicate `id`).
5. Card FSRS state is recomputed by a Horizon job that replays reviews in timestamp order when reviews sync in.

**Client-side mechanics:**
- One `PendingMutation` SwiftData model (entity_type, payload, retry_count).
- Background task drains it: batched pushes of up to 100 records, exponential-backoff retries (2s, 8s, 30s, 2m, 15m cap).
- Pull triggered on foreground + reachability + 5-minute timer.
- `URLSession` + `async/await` + `Codable`. No third-party networking.

**What's explicitly NOT in the design:**
- No vector/Lamport clocks.
- No CRDTs.
- No custom version counters beyond `updated_at`.
- No WebSockets or realtime.
- No bespoke sync framework.

**Observability:** PostHog events `sync.push.ok|fail`, `sync.pull.ok|fail`, `sync.queue.stuck` (queue > 100 and no success in 10 minutes).

---

## 7. FSRS integration

**Algorithm:** FSRS-6 via OpenSpacedRepetition's `fsrs-rs` Rust reference implementation, compiled for iOS via UniFFI Swift bindings.

**Runs on-device.** Per-card scheduling has ~5ms latency; sessions feel instant.

**Card lifecycle states:** `new` → `learning` → `review` ↔ `relearning`.

**On every rating:**
1. Compute new `(stability, difficulty, state, due_at)` via FSRS.
2. Write a `Review` record (immutable).
3. Update `Card` with new state.
4. Enqueue sync mutation.
5. Advance UI.

**Rating buttons:** Again (1), Hard (2), Good (3), Easy (4) — mockup labels already correct. Interval sub-labels ("6m", "1d", "4d") computed live from FSRS for each possible rating when card is flipped.

**Smart Study session queue:**
1. Due cards from the deck (state ∈ {learning, review, relearning} AND `due_at ≤ now`), ordered by how overdue.
2. New cards up to daily new-card limit (default 10/deck).
3. Stops when queue empty, daily goal hit, or user ends session.

**Basic Study:** Linear, does NOT mutate FSRS state. Records reviews for log completeness but leaves `stability` / `difficulty` / `state` untouched. Lets casual users drill without wrecking their Smart Study schedule.

**v1 ships with community-average FSRS weights.** Per-user optimization deferred to v1.5 (on-device; `User.fsrs_weights` field already reserved).

**Mockup change:** Remove the "Smart Study algorithm: SM-2" row from Settings. FSRS is the only algorithm. Add an "About spaced repetition" entry in Help/About.

---

## 8. Screens & information architecture

**No tab bar.** Single `NavigationStack` rooted at Home. Top-left = Search; top-right = Settings.

### 8.1 Modal semantics

- **Full-screen cover** — study sessions, onboarding.
- **Sheet** (detent-capable) — create/edit flows, filter drawers, action sheets, paywall.
- **Push** — deck detail, card edit, settings.

### 8.2 Screen inventory (v1)

**Onboarding & auth** (new vs current mockups)
- Splash, Intro 1, Intro 2, Sign-up wall, Magic link sent, Welcome.

**Home**
- Home/Deck grid (mw/02-screens-a.jsx:13).
- Search (mw/02-screens-a.jsx:77).

**Deck**
- Deck detail — History tab (mw/02-screens-a.jsx:136).
- Deck detail — Cards tab (mw/02-screens-a.jsx:236).
- Manage sub-topics (new).
- Card edit (new variant of Create Card).

**Create flows**
- Create deck (mw/03-screens-b.jsx:235).
- Create card (mw/03-screens-b.jsx:299).

**Study sessions**
- Smart Study — front (mw/03-screens-b.jsx:5).
- Smart Study — back with ratings (mw/03-screens-b.jsx:53).
- Basic Study (mw/03-screens-b.jsx:117).
- Session summary (mw/03-screens-b.jsx:148).

**Settings**
- Settings root (mw/03-screens-b.jsx:350) — sections: Profile, Study, Appearance, Subscription, Account, About. "Smart Study algorithm" row removed.
- Subscription (new) — plan state, upgrade/manage, restore purchases.
- Account (new) — email display, sign-out, delete account flow.
- Export data (reserved for v1.5).

**Modals**
- Quick Actions bottom sheet, Sort dropdown, Card context menu, Delete confirmation, Topic picker (updated — no suggested topics section), Filter drawer, Paywall sheet (new), Image source picker (reserved for v1.5).

### 8.3 State management

- **App-level `@Observable`** — current user, subscription status, today's progress, sync state. SwiftUI environment injection.
- **Per-session `@Observable`** — queue, current index, accumulated ratings. Scoped to study session lifetime.
- **Navigation** — native SwiftUI `NavigationStack` + sheet/fullScreenCover bindings. No coordinator pattern.

---

## 9. Design system

**Visual direction: Modernist Workshop** (mw/01-tokens.jsx). Bauhaus restraint; grid background; 1.5px borders; stacked-paper deck metaphor; confidence colors as semantic accents.

### 9.1 Tokens (single source of truth)

**Colors** — Asset Catalog sets with light/dark variants: `paper`, `canvas`, `ink`, `inkMuted`, `inkFaint`, `grid`, `again`, `hard`, `good`, `easy`, `accent` (per-deck via environment).

**Typography** — SF Pro. Scale: `mwDisplay` (40), `mwHeadingL` (28), `mwHeadingM` (20), `mwBodyL` (16), `mwBody` (14), `mwBodyS` (12), `mwEyebrow` (10, tracked 0.8px), `mwMono` (13).

**Spacing** — 4pt grid: `xxs` (2), `xs` (4), `s` (8), `m` (12), `l` (16), `xl` (24), `xxl` (32), `xxxl` (48).

**Radii** — `radiusXs` (2), `radiusS` (4), `radiusM` (8), `radiusL` (16).

**Borders** — `borderHair` (0.5), `borderDefault` (1.5), `borderBold` (2.5).

**Motion** — `motionInstant` (120ms easeOut), `motionQuick` (220ms easeInOut), `motionStandard` (320ms spring), `motionCard` (420ms spring), `motionSettled` (560ms easeInOut).

**Shadows** — `shadowDeck` only (for stacked-paper illusion). Modernist uses borders, not shadows.

### 9.2 Enforcement (SwiftLint rules, CI-failing)

Banned in view files:
- `Color(hex:)` or literal colors
- `.font(.system(size:))` with literals
- `.padding(...)` with literal CGFloat (must use token)
- `.cornerRadius(...)` with literal
- Literal animation durations
- `.foregroundColor(.black/.white)` — warning

**Principle (per owner directive):** the design system is mechanically enforced, not relied on vigilance.

### 9.3 Style architecture

Three patterns, strictly applied:
1. `ViewModifier` for reusable style bundles (`.mwCard()`).
2. `ButtonStyle` / `LabelStyle` / `TextFieldStyle` for interactive controls.
3. `EnvironmentValues` for scoped styling (per-deck accent color via `@Environment(\.mwAccent)`).

### 9.4 Component library

**Atoms:** `MWButton`, `MWPill`, `MWDot`, `MWIcon`, `MWTextField`, `MWTextArea`, `MWDivider`, `MWEyebrow`, `MWProgressBar`, `MWSwitch`, `MWChip`.

**Molecules:** `MWDeckCard`, `MWCardTile`, `MWStackedDeckPaper`, `MWTopBar`, `MWTabBar`, `MWSection`, `MWFormRow`, `MWRatingButton`, `MWBottomSheet`, `MWActionSheet`, `MWEmptyState`, `MWDuePill`, `MWPaywallScreen`.

**Layout:** `MWScreen` (root container with canvas bg + safe area + optional grid), `MWVStack` / `MWHStack` (spacing-token-aware stacks).

Each component: one file, docblock, `#Preview` covering all variants (default/disabled/pressed/dark-mode/XXL dynamic type).

### 9.5 Icons

Custom stroke icon set from mw/01-tokens.jsx rendered as SwiftUI `Shape` structs generated from SVG source. SF Symbols used only for iOS-native moments (share sheets) where brand consistency is less important than system legibility.

### 9.6 Per-deck accent color

Curated 5-swatch palette (from mockup). Flows through via `@Environment(\.mwAccent)` — one injection point at the deck detail view tree root.

### 9.7 Accessibility

- Dynamic Type via `ScaledMetric` through `accessibility3`.
- WCAG AA contrast audited at token creation time.
- 44pt minimum touch target on all interactive components.
- `UIAccessibility.isReduceMotionEnabled` honored via motion tokens.
- VoiceOver labels shipped with components.

### 9.8 File structure

```
App/
  DesignSystem/
    Tokens/{Colors,Typography,Spacing,Radii,Borders,Motion,Shadows}.swift
    Modifiers/MWCard.swift, MWScreenChrome.swift, ...
    ButtonStyles/MWPrimaryButtonStyle.swift, ...
    Components/
      Atoms/, Molecules/, Layout/
    Icons/MWIcon.swift, Generated/
  Features/
    Home/, DeckDetail/, Session/, Settings/, ...
```

Rules: Features import DesignSystem; DesignSystem never imports Features.

---

## 10. Content management (v1 scope)

### 10.1 What ships in v1

- Card authoring: text front/back (markdown), sub-topic chips, delete.
- Deck authoring: create/edit/duplicate/delete.
- Search: client-side LIKE scan over deck titles + card text.
- Bulk ops: select mode + bulk delete / move / tag / reset progress.

### 10.2 Deferred but architecturally reserved

| Feature | Reserved infra | v1 UI state |
|---|---|---|
| Images | `Asset` entity, image FK fields on Card, R2 disk configured | No image picker, no upload pipeline |
| CSV import | Generic create-deck + bulk-create-card code paths | No entry point |
| CSV/JSON export | None — read-only serialization, Horizon job template | No entry point |

Plug-in mechanism: feature flag (`Features.images`), `ImportSource` protocol, `ExportFormat` enum.

### 10.3 Card & deck flows

- Create/edit card sheet: front (markdown, 4000-char soft limit), back (same), sub-topic chip selector with "+ New" affordance, destructive delete in edit mode.
- Draft safety: swipe-dismiss with changes → action sheet "Keep editing / Discard."
- Create deck sheet: title, optional description, optional topic, accent color swatch, default study mode.
- Duplicate deck: copies deck + cards + sub-topics; does NOT copy FSRS state or review history.

---

## 11. Monetization

### 11.1 Plans

| | Free | Plus |
|---|---|---|
| Decks | 5 max | Unlimited |
| Cards per deck | 200 max | Unlimited |
| Total cards | 500 max | Unlimited |
| Smart Study (FSRS) | ✓ | ✓ |
| Basic Study | ✓ | ✓ |
| Cloud sync | ✓ | ✓ |
| Daily reminders | 1/day | Up to 3/day |
| Daily new-card limit | 10/deck | Up to 50/deck |
| FSRS personalization (v1.5+) | — | ✓ |
| Priority support | — | ✓ |

**Note on v1 Plus value:** v1 Plus is primarily volume-based (more decks, more cards, higher new-card throughput, more reminders). The premium feature set grows meaningfully with v1.5 (personalized FSRS weights) and v2 (advanced stats, images-beyond-quota). Early Plus subscribers are buying into the roadmap commitment; we communicate this honestly in the paywall copy.

**Pricing:** $4.99/mo or $29.99/yr. 7-day free trial on annual.

### 11.2 Implementation

- **StoreKit 2** (native) on iOS. `Transaction.updates` stream keeps local status in sync.
- **Laravel Cashier** for StoreKit — receipt verification, subscription state, renewals, refunds.
- **App Store Server Notifications v2** → Laravel → Cashier.
- Server is source of truth cross-device; `User.subscription_status` cached in SwiftData for offline paid-feature access.

### 11.2.1 Entitlements system — non-negotiable flexibility

Paywall gating is a first-class architectural concern. The specific plan limits in §11.1 are **starting defaults, not load-bearing code**. The system must allow flipping, tuning, or A/B testing any limit without shipping an app update.

**Design:**

1. **Keyed entitlements.** Every gated capability has a stable string key:

   | Key | Type | Example config |
   |---|---|---|
   | `decks.create` | max count | `{max: 5}` free, `{max: null}` Plus |
   | `cards.create_in_deck` | max count | `{max: 200}` free, `{max: null}` Plus |
   | `cards.create_total` | max count | `{max: 500}` free, `{max: null}` Plus |
   | `study.smart` | boolean | `{allowed: true}` both tiers (today) |
   | `study.basic` | boolean | `{allowed: true}` both tiers |
   | `reminders.add` | max count | `{max: 1}` free, `{max: 3}` Plus |
   | `new_card_limit.above_10` | boolean | `{allowed: false}` free, `{allowed: true}` Plus |
   | `fsrs.personalized` | boolean | reserved for v1.5 |
   | `images.use` | boolean | reserved for v1.5 |
   | `import.csv` | boolean | reserved for v1.5 |
   | `export.csv` / `export.json` | boolean | reserved for v1.5 |

2. **Server-owned plans config, client-cached.** Laravel stores the plans-to-entitlements mapping in a `plans` DB table (or a versioned JSON config). iOS fetches it on login and caches it with a short TTL + refresh-on-foreground. Offline-safe.

3. **One resolver API.** iOS exposes a single `EntitlementsManager`:
   ```swift
   let result = entitlements.can(.decksCreate, currentCount: deckCount)
   // → .allowed | .paywall(reason: .decksCreate, limit: 5)
   ```
   Every gated code path calls this exactly once. No `if user.plan == .free` scattered through features.

4. **Paywall copy keyed by entitlement.** The paywall screen takes a `reason: EntitlementKey` and renders the right headline and feature list from a copy map. Content edits, not engineering.

5. **Server-side verification.** Client-side checks are for UX; the server re-validates on every mutation (deck create, card create, reminder add) against the same entitlements config. A stale or tampered client cannot bypass limits.

**What this enables:**

- Flip "Smart Study requires Plus" by changing `study.smart.allowed: false` in the free plan config. No app update.
- A/B test paywall thresholds by assigning users to variant plan configs.
- Grandfather launch-era users by assigning them a permanent "launch" plan with more generous limits.
- Add a v1.5 gated feature (e.g., images) by adding one entitlement key and one call site check.

**Packages:** none. Laravel `config()` + `plans` table + iOS `EntitlementsManager` class. Deliberately avoiding RevenueCat since their abstraction doesn't add value for an iOS-only build and adds a vendor + revenue share.

### 11.3 Paywall triggers

1. 6th deck attempt → paywall ("Unlimited decks").
2. 201st card in a deck → paywall ("Unlimited cards per deck").
3. Attempt to raise daily new-card limit above 10 → paywall ("Faster learning pace").
4. Attempt to add a 2nd daily reminder → paywall ("More reminders").
5. Settings → Subscription → manual upgrade.

**Restore purchases** exposed in Settings and paywall footer — mandatory per App Review 3.1.1.

### 11.4 Not using
- RevenueCat — iOS-only v1 doesn't need cross-platform subscription abstraction; Cashier is sufficient.

---

## 12. Notifications & reminders

- **Local daily reminder** — `UNUserNotificationCenter` with Notification Content Extension pulling live due count from SwiftData. Works fully offline. Re-scheduled on timezone change.
- **Streak-at-risk nudge** — 8pm local if user has an active streak and no study today.
- **Server-triggered pushes (APNs)** via `laravel-notification-channels/apn`: subscription renewal success / payment failure, security events.
- **Permission request** — only at the moment the user enables reminders (not at install).

---

## 13. Observability

- **Product analytics:** PostHog Cloud. Event convention `{domain}.{object}.{action}`.
- **Crash reporting:** Sentry (iOS + Laravel SDKs). Releases tagged by version. Breadcrumbs on sync events.
- **Backend logs:** Laravel stderr → Forge → CloudWatch Logs or Axiom.
- **Uptime:** `/healthz` endpoint → UptimeRobot or BetterStack.
- **Business dashboards:** PostHog (DAU, retention cohorts, session completion, paywall conversion).

---

## 14. Privacy, security, compliance

### 14.1 Data collection

Collected: email, review data, session metadata, usage analytics, device/version for debugging.

Not collected: card content in telemetry, contacts, photos (v1), location, ad IDs. No App Tracking Transparency prompt needed.

### 14.2 Security

- TLS 1.3 enforced (HSTS).
- Postgres + R2 encrypted at rest (managed defaults).
- iOS Keychain for tokens.
- Rate limiting (Laravel throttle): 5 magic-link requests/hour/email; 60 API requests/minute/user.
- Dependabot on both iOS SPM and Composer; weekly bumps auto-merged for patches.

### 14.3 Compliance

- **Account deletion** ships in v1 (App Review 5.1.1(v)). Soft-delete immediate, hard-delete + R2 purge at 30 days via Horizon.
- **GDPR/CCPA** data portability via JSON export lands in v1.5. Right-to-deletion lands in v1.
- **COPPA** — n/a; 13+ audience.
- **SOC 2** — deferred until B2B pull.

---

## 15. Quality & testing

**iOS:** `XCTest` / Swift Testing. 70%+ coverage on FSRS wrapper, sync engine, design system components. `swift-snapshot-testing` on every DS component. `XCUITest` on 4 critical flows (first card, Smart Study session, offline session, paywall purchase). SwiftLint + swift-format in pre-commit + CI.

**Backend:** PHPUnit or Pest. High feature-test coverage on all API endpoints — auth, sync push/pull, subscription webhooks. Tests run against real Postgres (not SQLite). Laravel Pint + PHPStan level 6+.

**CI:** GitHub Actions. Staging on `main` merge; production on release tag.

**QA:** TestFlight internal from week 6, external from week 8. Target 50-100 external testers.

**Definition of done** per feature: feature-flagged, one automated test on happy path, PostHog event, Sentry error boundary, 1-week internal dogfood.

---

## 16. Out of scope / roadmap

**v1.5 (3-4 months post-v1):**
- Images on cards.
- CSV import.
- CSV + JSON export.
- On-device FSRS personalization.
- Streak-at-risk smart notifications.

**v2 (6-12 months post-v1):**
- Anki `.apkg` import.
- Deck sharing (link → clone).
- Advanced stats (retention curves, forgetting heatmaps).
- Web client.
- Audio on cards.
- LaTeX/math rendering.

**Explicitly not on roadmap:**
- AI-generated cards (pending market validation).
- Social features beyond deck sharing.
- Android — revisit in v2 if iOS traction justifies.

---

## 17. Team, budget, timeline

### 17.1 Team

| Role | Allocation |
|---|---|
| iOS tech lead | 1 FTE × 5 months |
| iOS engineer | 1 FTE × 5 months |
| Backend lead | 1 FTE × 5 months |
| Product designer | 1 FTE × 5 months |
| Product manager | 0.5 FTE × 5 months |
| QA | 0.5 FTE × 3 months (from week 8) |

### 17.2 Budget ($1M envelope)

| Line | Estimate |
|---|---|
| Salaries/contractors | $650-750K |
| Infrastructure year 1 | $10-15K |
| Marketing site + App Store assets | $30-50K |
| Legal | $10-20K |
| User research | $20K |
| Buffer | $150-200K |

### 17.3 Timeline

| Weeks | Milestone |
|---|---|
| 0-2 | Design system + SwiftLint rules + component scaffold; backend auth skeleton |
| 2-6 | All 9 entities modeled iOS + Laravel; sync engine end-to-end |
| 6-10 | Deck/card CRUD, FSRS wrapper, Smart + Basic Study, Session summary, Home, Deck detail, Search |
| 8-12 | Settings, paywall, Cashier + StoreKit 2 wiring |
| 10-14 | Polish, external TestFlight |
| 14-18 | App Store submission, review iterations, soft launch |
| 18-20 | Public launch |

Total: ~5 months from kickoff to public launch; 6 months realistic with Apple-review buffer.

---

## 18. Open decisions flagged for separate review

These are intentional punts — calls that should go through design-team review rather than be locked here:

1. **Final paywall copy & pricing region strategy** — marketing-owned.
2. **Curated deck accent palette swatches** — design-owned; 5 colors TBD.
3. **Splash & Intro screen content** — design + product copy owned.
4. **App icon** — design-owned.

Everything else in this document is binding input to the implementation plan.

---

## 19. Package bill of materials

### 19.1 iOS (Swift Package Manager)

| Package | Purpose |
|---|---|
| `KeychainAccess` | Token storage |
| `swift-markdown-ui` | Markdown rendering on cards |
| `Nuke` | Async image loading + cache (v1.5 when images ship) |
| `swift-csv` | CSV parsing (v1.5 when import ships) |
| `swift-snapshot-testing` | Design system visual regression tests |
| `fsrs-rs` (via UniFFI bindings) | FSRS scheduling |
| `posthog-ios` | Product analytics |
| `sentry-cocoa` | Crash reporting |

Native frameworks used: `SwiftUI`, `SwiftData`, `StoreKit 2`, `AuthenticationServices`, `UserNotifications`, `PhotosUI` (v1.5), `ImageIO` (v1.5), `URLSession`, `Codable`.

### 19.2 Laravel (Composer)

| Package | Purpose |
|---|---|
| `laravel/sanctum` | API token auth |
| `laravel/cashier` (StoreKit) | Subscription/receipt handling |
| `laravel/horizon` | Queue worker UI + monitoring |
| `spatie/laravel-signed-url` | Magic link generation/verification |
| `spatie/laravel-query-builder` | `?since=` filtering on sync endpoints |
| `spatie/laravel-medialibrary` | Asset handling (v1.5 when images ship) |
| `league/csv` | CSV generation (v1.5 when export ships) |
| `laravel-notification-channels/apn` | APNs pushes |
| `sentry/sentry-laravel` | Crash reporting |

Native Laravel: Eloquent (with `SoftDeletes`), Horizon scheduler, API Resources, throttle middleware.

---

## 20. Non-negotiable principles (per owner directive)

1. **Offline-first.** Every user action works offline; sync happens opportunistically. No user action waits on the network.
2. **Prefer packages over reinvention.** Integrate well-maintained libraries. Custom code requires explicit justification.
3. **Design system rigor.** Tokens and reusable components. No inline styling. Enforcement is mechanical (SwiftLint), not aspirational.
4. **Sync engine is boring.** Standard REST delta. No gee-whiz. No CRDTs, no vector clocks, no custom frameworks.
5. **User data is sacred.** Client-generated UUIDs, review log immutable, 90-day tombstones, account deletion on day one.
