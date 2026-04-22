//
//  AppState.swift
//  Flashcards
//
//  Purpose: App-level observable state injected into the SwiftUI environment
//           at the scene root. Holds a shallow projection of identity,
//           entitlements, and sync status — just enough for any view to
//           branch on without reaching into a manager.
//  Dependencies: Foundation (Date), Observation (`@Observable`).
//  Key concepts: One instance, injected once in `FlashcardsApp`. Deeper state
//                (credentials, sync queues, today's progress) lives in the
//                owning manager (AuthManager, SyncManager, …) and is
//                projected up here as coarse-grained values. This keeps the
//                environment object narrow and the observation surface stable
//                — managers can churn internally without invalidating every
//                subscribing view.
//

import Foundation
import Observation

/// App-level observable state. One instance is injected into the SwiftUI environment.
/// Subscription, sync, and today's progress are intentionally shallow here — deeper
/// state lives in the owning manager (AuthManager, SyncManager, …) and is projected
/// up as needed.
@Observable
public final class AppState {
    /// Authentication lifecycle state. `.checking` is the initial value while the
    /// session is being restored from the keychain; it resolves to either
    /// `.unauthenticated` or `.authenticated(userId:)` once the check completes.
    public enum AuthStatus: Equatable {
        /// No active session; the user must sign in.
        case unauthenticated
        /// A session is active for the given user id.
        case authenticated(userId: String)
        /// Session restore in progress (initial app launch).
        case checking
    }

    /// Entitlement tier driving paywall and feature gating.
    public enum SubscriptionTier: String, Codable {
        /// Free tier — limited deck count and sync off.
        case free
        /// Paid "Plus" tier — full feature set.
        case plus
    }

    /// Current authentication state; defaults to `.checking` at launch.
    public var authStatus: AuthStatus = .checking

    /// Current entitlement tier; defaults to `.free` until a receipt/entitlement is verified.
    public var subscriptionTier: SubscriptionTier = .free

    /// Timestamp of the last successful sync pass, or `nil` if we haven't synced yet.
    public var lastSyncAt: Date?

    /// Number of local mutations waiting to be pushed to the server.
    public var pendingMutationCount: Int = 0

    /// Creates an `AppState` with default values. Managers mutate properties as they
    /// come online — nothing is fetched here.
    public init() {}
}
