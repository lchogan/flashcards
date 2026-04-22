//
//  APIError.swift
//  Flashcards
//
//  Purpose: Single error type for every failure mode that surfaces from
//           `APIClient` — transport (offline, unknown), auth (401), HTTP
//           (non-2xx with status + body), and decoding.
//  Dependencies: Foundation.
//  Key concepts: One enum so callers can `switch` exhaustively rather than
//                inspecting loosely-typed `Error`s. `Equatable` so tests
//                can assert specific cases without reflection. Associated
//                values keep diagnostic context (status code, body string,
//                decoding details) without leaking framework types
//                (`URLError`, `DecodingError`) into the public surface.
//

import Foundation

/// All failure modes that `APIClient` can throw. Flat and `Equatable` on
/// purpose so tests can assert `XCTAssertEqual(error, .unauthorized)`.
///
/// Callers typically branch on the coarse case (`.offline` → banner,
/// `.unauthorized` → sign-in flow, `.http` → retry/report, everything
/// else → generic error UI).
public enum APIError: Error, Equatable, Sendable {
    /// Device has no network connectivity. Raised when `URLSession` fails
    /// with `URLError.notConnectedToInternet`.
    case offline

    /// Server returned HTTP 401. Surface as "re-authenticate" in UI; do
    /// not retry without a fresh token.
    case unauthorized

    /// Server returned a non-2xx status that isn't 401. Carries the raw
    /// status code and response body (decoded as UTF-8, empty string if
    /// the body isn't UTF-8) for diagnostics and error-reporting.
    case http(status: Int, body: String)

    /// Response body could not be decoded into the expected type. The
    /// associated value is a human-readable dump of the underlying
    /// `DecodingError` (via `String(describing:)`).
    case decoding(String)

    /// Anything else — usually a transport-level `URLError` that isn't
    /// `.notConnectedToInternet`, or a non-HTTP response. The associated
    /// value is a localized description for logging.
    case unknown(String)
}
