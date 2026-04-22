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
public struct PlanSnapshot: Codable, Equatable, Sendable {
    public let planKey: String
    public let version: Int
    public let entitlements: [String: EntitlementConfig]

    public init(planKey: String, version: Int, entitlements: [String: EntitlementConfig]) {
        self.planKey = planKey
        self.version = version
        self.entitlements = entitlements
    }
}

/// Server-side entitlement rule. One of `boolean` or `max_count`; unused
/// fields are `nil`.
public struct EntitlementConfig: Codable, Equatable, Sendable {
    public let type: String
    public let max: Int?
    public let allowed: Bool?

    public init(type: String, max: Int?, allowed: Bool?) {
        self.type = type
        self.max = max
        self.allowed = allowed
    }
}

/// Actor-isolated wrapper around a single UserDefaults slot for the plan
/// snapshot. Safe to call from any task; every operation is a single
/// synchronous defaults read/write under the actor.
public actor PlansCache {
    private let defaults: UserDefaults
    private let storageKey = "mw.plansCache"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> PlanSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder.api.decode(PlanSnapshot.self, from: data)
    }

    public func store(_ snapshot: PlanSnapshot) {
        guard let data = try? JSONEncoder.api.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
