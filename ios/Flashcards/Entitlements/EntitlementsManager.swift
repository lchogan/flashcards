//
//  EntitlementsManager.swift
//  Flashcards
//
//  Purpose: Single source of truth for the current user's plan + entitlement
//           matrix on iOS. Views inject it through the environment, call
//           `can(_:currentCount:)` synchronously before mutating state, and
//           route to PaywallView on denies.
//  Dependencies: Foundation, Observation, Networking (APIClientProtocol),
//                Entitlements (PlansCache, EntitlementKey).
//  Key concepts: Boot path loads the cached snapshot immediately (so the UI
//                doesn't flash "unknown"), then fires a background refresh
//                from /v1/me/entitlements. Cache is authoritative if the
//                refresh fails — failing open would be a revenue leak;
//                failing to cached state preserves the last known plan.
//                TTL is 5 minutes; callers can pass `force: true` after a
//                purchase to repopulate immediately.
//

import Foundation
import Observation

@Observable
@MainActor
internal final class EntitlementsManager {
    internal var planKey: String = "free"
    internal var planVersion: Int = 0
    internal var isLoaded = false

    private var config: [String: EntitlementConfig] = [:]
    private let api: APIClientProtocol
    private let cache: PlansCache
    private var lastFetchAt: Date?

    internal init(api: APIClientProtocol, cache: PlansCache = PlansCache()) {
        self.api = api
        self.cache = cache
    }

    /// Loads the cached snapshot if present, then refreshes from server when
    /// the cache is stale (>5 min) or missing. Safe to call repeatedly; a
    /// fresh cache short-circuits the network.
    internal func load(force: Bool = false) async {
        if let cached = await cache.load() {
            apply(cached)
            if !force, let last = lastFetchAt, Date().timeIntervalSince(last) < 300 {
                return
            }
        }

        do {
            let resp: EntitlementsResponse = try await api.send(
                APIEndpoint<EntitlementsResponse>(
                    method: "GET",
                    path: "/api/v1/me/entitlements",
                    body: nil,
                    requiresAuth: true
                ))
            let snapshot = PlanSnapshot(
                planKey: resp.planKey,
                version: resp.version,
                entitlements: resp.entitlements
            )
            await cache.store(snapshot)
            apply(snapshot)
            lastFetchAt = Date()
        } catch {
            // Keep whatever we had cached; a revenue-adjacent check must
            // never fail open. A later load() or purchase will refresh.
        }
    }

    /// Synchronous gate check. Caller supplies any current-count hint needed
    /// for `max_count` entitlements (e.g. the user's existing deck count for
    /// `decksCreate`).
    internal func can(_ key: EntitlementKey, currentCount: Int = 0) -> EntitlementResult {
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

    /// Reset to defaults (sign-out).
    internal func reset() async {
        planKey = "free"
        planVersion = 0
        config = [:]
        isLoaded = false
        lastFetchAt = nil
        await cache.clear()
    }

    private func apply(_ snapshot: PlanSnapshot) {
        planKey = snapshot.planKey
        planVersion = snapshot.version
        config = snapshot.entitlements
        isLoaded = true
    }
}

/// Wire shape of `GET /v1/me/entitlements`.
private struct EntitlementsResponse: Decodable, Sendable {
    let planKey: String
    let version: Int
    let entitlements: [String: EntitlementConfig]
}
