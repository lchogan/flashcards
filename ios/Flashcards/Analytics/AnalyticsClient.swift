//
//  AnalyticsClient.swift
//  Flashcards
//
//  Purpose: App-level facade around PostHog (product analytics) and Sentry
//           (crash + performance). Centralises SDK initialisation, event
//           capture, user identification, and session reset so the rest of
//           the app has a single, stable entry point — if we swap vendors
//           later, only this file changes.
//  Dependencies: Foundation, PostHog (`PostHogSDK`, `PostHogConfig`), Sentry
//                (`SentrySDK`, `Sentry.User`).
//  Key concepts: Configuration reads keys from the main bundle's Info.plist
//                (`POSTHOG_KEY`, `POSTHOG_HOST`, `SENTRY_DSN`) so secrets are
//                injected at build time via xcconfig or CI env — no secrets
//                in source. Each SDK is only initialised when its key is
//                non-empty, which means local developer builds without
//                secrets are a clean no-op instead of a loud failure. The
//                type is a `public enum` with only static members — a
//                namespace, never instantiated, so no actor/concurrency
//                shape is needed: all work is forwarded to the SDKs'
//                own thread-safe shared singletons.
//

import Foundation
import PostHog
import Sentry

/// Static facade over PostHog and Sentry. All app code that needs to track
/// events, identify a user, or reset on sign-out should call through here.
public enum AnalyticsClient {
    /// Initialises both SDKs. Call once from the app's `init()` before any
    /// scene is constructed. Missing keys are treated as "disabled" — the
    /// corresponding SDK is simply not started, so debug builds without
    /// secrets stay silent rather than crashing or spamming errors.
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

    /// Records a product analytics event with optional properties. Forwarded
    /// to PostHog. Safe to call before `configure()` — PostHog no-ops if
    /// the SDK hasn't been set up.
    ///
    /// - Parameters:
    ///   - event: The event name, e.g. `"review_card_flipped"`. Prefer
    ///     snake_case and keep the taxonomy stable — renames create
    ///     orphaned series in PostHog.
    ///   - properties: Optional bag of event attributes. Values must be
    ///     JSON-representable (strings, numbers, bools, arrays, dicts).
    public static func track(_ event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Binds the current session to a user id in both PostHog and Sentry.
    /// Call this immediately after a successful sign-in so subsequent
    /// events and crashes are attributed to the right user.
    ///
    /// - Parameter userId: The backend-issued stable user identifier.
    public static func identify(userId: String) {
        PostHogSDK.shared.identify(userId)
        SentrySDK.setUser(Sentry.User(userId: userId))
    }

    /// Clears identity in both SDKs. Call on sign-out so the next session
    /// starts anonymously and no events leak across user boundaries.
    public static func reset() {
        PostHogSDK.shared.reset()
        SentrySDK.setUser(nil)
    }
}
