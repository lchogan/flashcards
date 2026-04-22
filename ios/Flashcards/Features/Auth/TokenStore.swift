//
//  TokenStore.swift
//  Flashcards
//
//  Purpose: Actor-isolated, Keychain-backed store for the bearer
//           access+refresh token pair used by the auth flow. Callers
//           (AuthManager, APIClient token providers) read the current
//           access token, persist new tokens after a login or refresh,
//           and clear both on sign-out.
//  Dependencies: Foundation, KeychainAccess.
//  Key concepts: Wrapping the `Keychain` reference in an `actor`
//                serialises reads and writes so concurrent auth flows
//                (e.g. a refresh racing a logout) cannot tear the
//                saved pair. Accessibility is pinned to
//                `.afterFirstUnlockThisDeviceOnly` — the tokens are
//                never iCloud-synced and are usable in background
//                refresh once the device has been unlocked at least
//                once since boot. This type is intentionally minimal:
//                no biometric prompts, no migration hooks, no change
//                notifications. Layer those on when a feature needs
//                them.
//

import Foundation
import KeychainAccess

/// Actor-isolated store for the bearer access + refresh token pair.
///
/// All persistence goes through the iOS Keychain via `KeychainAccess`
/// with `.afterFirstUnlockThisDeviceOnly` accessibility so tokens
/// survive process restarts and background launches but never leave
/// the device. Construct one instance at app start and inject it into
/// anything that needs to read, write, or clear tokens.
public actor TokenStore {
    private let keychain: Keychain

    /// Creates a token store backed by the Keychain service identifier
    /// `service`.
    ///
    /// - Parameter service: The Keychain `service` attribute that
    ///   namespaces the stored items. Defaults to
    ///   `"com.lukehogan.flashcards.tokens"`; override in tests or
    ///   secondary targets to isolate state.
    public init(service: String = "com.lukehogan.flashcards.tokens") {
        self.keychain = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    /// Persists both tokens atomically from the caller's perspective
    /// (the actor serialises the two writes).
    ///
    /// - Parameters:
    ///   - access: The short-lived bearer access token.
    ///   - refresh: The long-lived refresh token used to mint new
    ///     access tokens.
    /// - Throws: A `KeychainAccess.Status` error if either write
    ///   fails; the first failure aborts and the second key is not
    ///   written.
    public func save(access: String, refresh: String) throws {
        try keychain.set(access, key: "access")
        try keychain.set(refresh, key: "refresh")
    }

    /// Returns the currently stored access token, or `nil` if no token
    /// is stored or the Keychain read fails.
    public func access() -> String? { try? keychain.get("access") }

    /// Returns the currently stored refresh token, or `nil` if no
    /// token is stored or the Keychain read fails.
    public func refresh() -> String? { try? keychain.get("refresh") }

    /// Deletes both tokens. Silently ignores "item not found" errors
    /// so calling `clear()` on an already-empty store is a no-op.
    public func clear() {
        try? keychain.remove("access")
        try? keychain.remove("refresh")
    }
}
