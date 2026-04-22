//
//  APIClient.swift
//  Flashcards
//
//  Purpose: Sendable actor-based HTTP client for the Flashcards backend.
//           Builds a `URLRequest` from an `APIEndpoint`, injects a bearer
//           token via a pluggable async token provider, dispatches through
//           `URLSession`, maps transport / HTTP / decoding failures onto
//           `APIError`, and returns a decoded value.
//  Dependencies: Foundation (URLSession, URLRequest, URLError, JSONDecoder).
//  Key concepts: Actor isolation guarantees the client is safe to share
//                across tasks. The token provider is an async `@Sendable`
//                closure so the caller (AuthManager, tests) owns the
//                source of truth — the client never caches tokens. The
//                JSON coders live as static properties on `JSONDecoder`
//                / `JSONEncoder` so every call uses identical
//                snake_case↔camelCase settings without duplication.
//                Empty-body responses (HTTP 204 No Content, or any 2xx
//                with a zero-length payload) are special-cased: if the
//                caller's `Response` generic is `Empty204`, the client
//                returns a freshly-constructed `Empty204()` and skips
//                JSON decoding entirely — otherwise an empty body on a
//                success response is still an error (`.decoding`).
//                No retries, no middleware, no logging — those layer on
//                top once we know what we actually need.
//

import Foundation

/// Abstract interface for sending `APIEndpoint`s. Exists so feature code
/// can depend on the protocol (and tests can substitute a stub) rather
/// than the concrete `APIClient` actor.
public protocol APIClientProtocol: Sendable {
    /// Sends the endpoint, returning the decoded response or throwing
    /// an `APIError`.
    ///
    /// - Parameter endpoint: The endpoint to invoke.
    /// - Returns: The decoded response of type `R`.
    /// - Throws: `APIError` — see each case for its meaning.
    func send<R: Decodable & Sendable>(_ endpoint: APIEndpoint<R>) async throws -> R
}

/// Concrete HTTP client. One instance per backend (base URL), shared
/// app-wide via DI. Thread-safe by virtue of being an actor.
public actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> String?

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - baseURL: Root URL; endpoint paths are appended to this.
    ///   - session: Transport. Defaults to `.shared`. Tests pass a session
    ///     configured with a custom `URLProtocol` for stubbing.
    ///   - tokenProvider: Async closure that returns the current bearer
    ///     token, or `nil` if unauthenticated. Invoked on every request
    ///     that has `requiresAuth == true`; the client never caches.
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: @Sendable @escaping () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    /// Dispatches `endpoint`, mapping any failure onto `APIError` and
    /// decoding a successful 2xx body into `R` using the shared
    /// `JSONDecoder.api` (snake_case → camelCase).
    public func send<R: Decodable & Sendable>(_ endpoint: APIEndpoint<R>) async throws -> R {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        req.httpMethod = endpoint.method
        req.httpBody = endpoint.body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if endpoint.requiresAuth, let token = await tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("no HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        // 204 No Content (or any 2xx with an empty body). Only valid if
        // the caller asked for `Empty204` — anything else is a contract
        // mismatch and surfaces as `.decoding`.
        if data.isEmpty {
            if let empty = Empty204() as? R {
                return empty
            }
            throw APIError.decoding("empty response body cannot decode to \(R.self)")
        }

        do {
            return try JSONDecoder.api.decode(R.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}

public extension JSONDecoder {
    /// Shared decoder for API responses. Converts `snake_case` keys to
    /// `camelCase` so Swift models can use idiomatic property names
    /// without per-type `CodingKeys`.
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

public extension JSONEncoder {
    /// Shared encoder for API request bodies. Mirrors `JSONDecoder.api`
    /// by converting `camelCase` property names to `snake_case` on the
    /// wire.
    static let api: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}
