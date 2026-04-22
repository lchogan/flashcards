//
//  PlansCache.swift
//  Flashcards
//
//  Purpose: Persist the last-known plan snapshot in UserDefaults so the app
//           boots with a usable entitlement matrix even before the network
//           round-trip finishes.
//  Dependencies: Foundation, JSONDecoder.api / JSONEncoder.api from Networking.
//  Key concepts: Snapshot-shaped value + actor-isolated reader/writer. The
//                payload is keyed by camelCase (`planKey`) because the stored
//                blob is re-encoded by our own JSONEncoder.api, which maps
//                camelCase ↔ snake_case; the raw key strings used in
//                `entitlements` stay untouched since they are dictionary keys.
//

import Foundation

/// Cached copy of a `GET /v1/me/entitlements` response.
internal struct PlanSnapshot: Codable, Equatable, Sendable {
    internal let planKey: String
    internal let version: Int
    internal let entitlements: [String: EntitlementConfig]
}

/// Server-side entitlement rule. One of `boolean` or `max_count`; unused
/// fields are `nil`.
internal struct EntitlementConfig: Codable, Equatable, Sendable {
    internal let type: String
    internal let max: Int?
    internal let allowed: Bool?
}

/// Actor-isolated wrapper around a single UserDefaults slot for the plan
/// snapshot. Safe to call from any task; every operation is a single
/// synchronous defaults read/write under the actor.
internal actor PlansCache {
    private let defaults: UserDefaults
    private let storageKey = "mw.plansCache"

    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    internal func load() -> PlanSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder.api.decode(PlanSnapshot.self, from: data)
    }

    internal func store(_ snapshot: PlanSnapshot) {
        guard let data = try? JSONEncoder.api.encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    internal func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
