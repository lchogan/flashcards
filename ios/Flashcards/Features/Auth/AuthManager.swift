//
//  AuthManager.swift
//  Flashcards
//
//  Purpose: Single orchestration point for the app's authentication
//           lifecycle. Owns the observable `state` (unknown / signedOut
//           / signedIn), drives the Sign in with Apple and magic-link
//           flows against the backend, persists the resulting bearer
//           tokens via `TokenStore`, and supports silent restore on
//           app launch.
//  Dependencies: Foundation (JSON coders), Observation (`@Observable`),
//                `APIClientProtocol`, `TokenStore`, `AppleSignInService`.
//  Key concepts: `@MainActor` isolation on the whole class because the
//                observable `state` is consumed by SwiftUI views and
//                the injected `AppleSignInService` is itself MainActor
//                — putting the coordinator on the main actor resolves
//                Sendability cleanly without sprinkling `@MainActor`
//                across individual methods. DTOs declared inside each
//                flow's method are camelCase Swift properties; the
//                shared `JSONDecoder.api` / `JSONEncoder.api` handle
//                snake_case translation on the wire. The magic-link
//                request uses `Empty204` as its response type because
//                the backend returns HTTP 204 No Content — `APIClient`
//                short-circuits empty-body decoding for that sentinel.
//

import Foundation
import Observation

/// Observable orchestrator for authentication. Injected once at app
/// startup and mutated by the sign-in / sign-out flows. Views read
/// `state` through `@Environment` to branch on authenticated vs.
/// signed-out UI.
@MainActor
@Observable
public final class AuthManager {
    /// Authentication lifecycle. `.unknown` is the initial value before
    /// `restore()` has run; it resolves to either `.signedOut` or
    /// `.signedIn(userId:email:)`.
    public enum State: Equatable {
        /// Session has not been checked yet. Transitional — holds only
        /// from init until `restore()` completes.
        case unknown
        /// No active session. The user must sign in.
        case signedOut
        /// A session is active for the given user id. The `email` is
        /// whatever the backend last reported; `nil` if unknown.
        case signedIn(userId: String, email: String?)
    }

    /// Current lifecycle state. Observable; SwiftUI views re-render on
    /// change.
    public var state: State = .unknown

    private let api: APIClientProtocol
    private let tokenStore: TokenStore
    private let apple: AppleSignInService

    /// Creates an `AuthManager`.
    ///
    /// - Parameters:
    ///   - api: The HTTP client used for auth endpoints.
    ///   - tokenStore: Keychain-backed persistence for the bearer
    ///     tokens. Defaults to a fresh instance using the shared
    ///     Keychain service.
    ///   - apple: Apple sign-in wrapper. Defaults to a fresh instance;
    ///     override in tests.
    public init(
        api: APIClientProtocol,
        tokenStore: TokenStore = TokenStore(),
        apple: AppleSignInService = AppleSignInService()
    ) {
        self.api = api
        self.tokenStore = tokenStore
        self.apple = apple
    }

    /// Restores session state from the token store. Call once at app
    /// launch. If an access token is present we mark the user as
    /// signed-in with a placeholder `userId` — a later task will hit
    /// `/me` to hydrate real identity. If no token is present we
    /// transition to `.signedOut`.
    public func restore() async {
        if await tokenStore.access() != nil {
            state = .signedIn(userId: "restored", email: nil)
        } else {
            state = .signedOut
        }
    }

    /// Runs the full Sign in with Apple flow: presents the system
    /// sheet, exchanges the identity token with the backend, persists
    /// the resulting bearer pair, and transitions `state` to
    /// `.signedIn(userId:email:)`.
    ///
    /// - Throws: Any error from `AppleSignInService.signIn()`
    ///   (typically `ASAuthorizationError.canceled`), `APIError` from
    ///   the exchange call, or a Keychain error from the token save.
    public func signInWithApple() async throws {
        let identity = try await apple.signIn()

        let body = try JSONEncoder.api.encode(
            AppleSignInBody(identityToken: identity.identityToken)
        )
        let resp: TokenResponse = try await api.send(
            APIEndpoint(
                method: "POST",
                path: "/api/v1/auth/apple",
                body: body,
                requiresAuth: false
            )
        )

        try await tokenStore.save(access: resp.accessToken, refresh: resp.refreshToken)
        state = .signedIn(userId: resp.user.id, email: resp.user.email)
    }

    /// Requests the backend to email a magic-link to `email`. The
    /// endpoint returns HTTP 204 No Content on success; the empty body
    /// is handled by `APIClient`'s `Empty204` special case.
    ///
    /// - Parameter email: Address to mail the link to.
    /// - Throws: `APIError` on transport / HTTP failure.
    public func requestMagicLink(email: String) async throws {
        let body = try JSONEncoder.api.encode(MagicLinkRequestBody(email: email))
        _ = try await api.send(
            APIEndpoint<Empty204>(
                method: "POST",
                path: "/api/v1/auth/magic-link/request",
                body: body,
                requiresAuth: false
            )
        )
    }

    /// Consumes a magic-link token (extracted from the universal link
    /// the user tapped in their email) by posting it to the backend,
    /// then persists the returned bearer pair and transitions `state`.
    ///
    /// - Parameter token: The opaque magic-link token.
    /// - Throws: `APIError` on transport / HTTP failure or a Keychain
    ///   error from the token save.
    public func consumeMagicLink(token: String) async throws {
        let body = try JSONEncoder.api.encode(MagicLinkConsumeBody(token: token))
        let resp: TokenResponse = try await api.send(
            APIEndpoint(
                method: "POST",
                path: "/api/v1/auth/magic-link/consume",
                body: body,
                requiresAuth: false
            )
        )
        try await tokenStore.save(access: resp.accessToken, refresh: resp.refreshToken)
        state = .signedIn(userId: resp.user.id, email: resp.user.email)
    }

    /// Clears the persisted tokens and transitions `state` to
    /// `.signedOut`. No backend round-trip — a future task may add a
    /// token-revocation call.
    public func signOut() async {
        await tokenStore.clear()
        state = .signedOut
    }
}

// MARK: - Wire DTOs
//
// Private, file-scope DTOs kept out of `AuthManager` to avoid
// triple-nesting (SwiftLint `nesting` violation). Camel-case property
// names; `JSONDecoder.api` / `JSONEncoder.api` handle snake_case on
// the wire.

/// Request body for `POST /api/v1/auth/apple`. Encodes as
/// `{"identity_token": "..."}`.
private struct AppleSignInBody: Encodable {
    let identityToken: String
}

/// Request body for `POST /api/v1/auth/magic-link/request`. Single
/// field — no snake_case conversion needed.
private struct MagicLinkRequestBody: Encodable {
    let email: String
}

/// Request body for `POST /api/v1/auth/magic-link/consume`.
private struct MagicLinkConsumeBody: Encodable {
    let token: String
}

/// Success response shared by the Apple sign-in and magic-link
/// consume endpoints. Decodes from
/// `{"access_token": "...", "refresh_token": "...", "user": {...}}`.
private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

/// Minimal user projection returned by the auth endpoints; the full
/// profile arrives later from `/me`.
private struct UserDTO: Decodable {
    let id: String
    let email: String?
}

/// Sentinel response type for endpoints that return HTTP 204 No
/// Content. `APIClient.send` recognises this type and returns an
/// instance without attempting to JSON-decode the empty body.
///
/// The custom `init(from:)` is defensive: it never actually runs for
/// 204 responses because `APIClient` short-circuits before calling
/// the decoder, but if a caller routes `Empty204` through a decoder
/// directly it will succeed against any input rather than throwing.
public struct Empty204: Decodable, Sendable {
    /// Creates an `Empty204`. Used by `APIClient` when a 2xx response
    /// carries no body.
    public init() {}

    /// Decodable initialiser that accepts anything. The decoder is
    /// never actually invoked for this type in the normal path;
    /// `APIClient` constructs instances directly via `init()`.
    public init(from decoder: Decoder) throws {
        // Deliberately ignore the decoder — no fields to decode.
        _ = decoder
    }
}
