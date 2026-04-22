/// UserEntity.swift
///
/// SwiftData model representing the authenticated user's profile as cached on-device.
/// User record sync travels through /v1/me (not /v1/sync/push), so this entity does
/// NOT conform to SyncableRecord — it is updated directly by the me-endpoint fetch.
///
/// Dependencies: SwiftData, Foundation.
/// Key concepts: single-row table (one user per device), syncUpdatedAtMs used for
/// LWW when the me-endpoint returns a fresher snapshot.

import Foundation
import SwiftData

/// Local representation of the authenticated user profile.
@Model
public final class UserEntity {
    /// Stable user UUID, matches server-side id.
    @Attribute(.unique) public var id: String

    /// Primary email address used for authentication.
    public var email: String

    /// Display name, optional until the user completes onboarding.
    public var name: String?

    /// Remote URL of the user's avatar image, if set.
    public var avatarUrl: String?

    /// Authentication provider used to sign in, e.g. "apple" or "magic_link".
    public var authProvider: String

    /// Number of cards the user wants to review per day.
    public var dailyGoalCards: Int

    /// Local time (HH:mm) at which the daily reminder fires, nil when not configured.
    public var reminderTimeLocal: String?

    /// Whether daily review reminders are active.
    public var reminderEnabled: Bool

    /// UI colour scheme preference: "system" | "light" | "dark".
    public var themePreference: String

    /// IAP subscription tier: "free" | "pro" | etc.
    public var subscriptionStatus: String

    /// Wall-clock time the subscription expires, nil for free tier.
    public var subscriptionExpiresAt: Date?

    /// Server-side updated_at_ms used for last-writer-wins comparisons.
    public var syncUpdatedAtMs: Int64

    /// Tombstone timestamp; retained for schema symmetry, not used in sync routing.
    public var syncDeletedAtMs: Int64?

    /// Creates a minimal UserEntity with sensible defaults for optional fields.
    ///
    /// - Parameters:
    ///   - id: Server-assigned user UUID.
    ///   - email: Primary email address.
    ///   - authProvider: Authentication provider identifier.
    ///   - syncUpdatedAtMs: Server's updated_at_ms at insertion time.
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
