//
//  APIEndpoint.swift
//  Flashcards
//
//  Purpose: Value type that describes a single HTTP call against the
//           Flashcards backend — method, path, optional body, whether auth
//           is required — and statically binds the expected decoded
//           response type via a phantom generic parameter.
//  Dependencies: Foundation (URL, Data).
//  Key concepts: Endpoints are tiny, immutable, and Sendable. They carry
//                no behavior; `APIClient` does the work. The `Response`
//                generic makes the decoded type inferable at the call site
//                (`client.send(Endpoints.me)` returns `User`, not `Any`).
//                `requiresAuth` defaults to `true` — the common case is
//                authenticated; the few public endpoints (sign-in, health)
//                opt out explicitly.
//

import Foundation

/// Describes a single HTTP request to the backend, parameterised by its
/// expected response type. Intentionally anemic: `APIClient` is responsible
/// for building the `URLRequest`, adding auth, and decoding `Response`.
///
/// - Note: `Response` is constrained to `Decodable & Sendable` because the
///   decoded value is returned across the `APIClient` actor boundary under
///   Swift 6 strict concurrency.
public struct APIEndpoint<Response: Decodable & Sendable>: Sendable {
    /// HTTP method, uppercased (`"GET"`, `"POST"`, `"PATCH"`, `"DELETE"`).
    public let method: String

    /// Path component appended to the client's base URL (e.g. `"/v1/decks"`).
    /// Leading slash is recommended but not required.
    public let path: String

    /// Optional JSON body, already encoded. `nil` for methods that don't
    /// send a body (`GET`, `DELETE` without payload).
    public let body: Data?

    /// When `true`, the client attaches a `Bearer` token (if the token
    /// provider returns one) to the `Authorization` header. Set `false`
    /// for unauthenticated endpoints like sign-in or health checks.
    public let requiresAuth: Bool

    /// Creates an endpoint. Prefer static factories (`Endpoints.me`, …)
    /// over constructing endpoints inline at call sites.
    ///
    /// - Parameters:
    ///   - method: HTTP method, uppercased.
    ///   - path: Path appended to the client base URL.
    ///   - body: Optional pre-encoded JSON body. Defaults to `nil`.
    ///   - requiresAuth: Whether to attach a bearer token. Defaults to `true`.
    public init(
        method: String,
        path: String,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) {
        self.method = method
        self.path = path
        self.body = body
        self.requiresAuth = requiresAuth
    }
}
