//
//  APIClientTests.swift
//  FlashcardsTests
//
//  Purpose: Exercise `APIClient` against a `URLProtocol` stub — happy
//           path decoding, 401 → `.unauthorized`, and offline →
//           `.offline` — so the error-mapping contract other layers
//           rely on is locked in.
//  Dependencies: XCTest, Flashcards module (`APIClient`, `APIEndpoint`,
//                `APIError`), URLProtocol for transport stubbing.
//  Key concepts: A custom `URLProtocol` intercepts every request made
//                through an ephemeral `URLSession`; `nextResponse` /
//                `nextError` are set per-test to shape what the stub
//                returns. Tests run serially so the static stub state
//                is safe — still marked `nonisolated(unsafe)` to appease
//                Swift 6 strict concurrency.
//

import XCTest
@testable import Flashcards

final class APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubProtocol.nextResponse = (200, "")
        StubProtocol.nextError = nil
    }

    override func tearDown() {
        StubProtocol.nextResponse = (200, "")
        StubProtocol.nextError = nil
        super.tearDown()
    }

    /// 2xx response with a JSON body should decode cleanly into the
    /// expected type via `JSONDecoder.api` (snake_case → camelCase).
    func test_sendHappyPath_decodesResponse() async throws {
        let client = makeClient(statusCode: 200, body: #"{"value":"ok"}"#)
        struct Payload: Decodable, Sendable { let value: String }
        let response: Payload = try await client.send(
            APIEndpoint(method: "GET", path: "/t")
        )
        XCTAssertEqual(response.value, "ok")
    }

    /// HTTP 401 should map to `APIError.unauthorized` regardless of body.
    func test_401_throwsUnauthorized() async {
        let client = makeClient(statusCode: 401, body: "")
        do {
            _ = try await client.send(APIEndpoint<Empty>(method: "GET", path: "/t"))
            XCTFail("expected APIError.unauthorized, got success")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("expected APIError, got \(error)")
        }
    }

    /// A transport-level `URLError.notConnectedToInternet` should surface
    /// as `APIError.offline` — that's the signal UI layers use to show
    /// the offline banner.
    func test_offline_throwsOffline() async {
        let client = makeClient(statusCode: 0, body: "")
        StubProtocol.nextError = URLError(.notConnectedToInternet)
        do {
            _ = try await client.send(APIEndpoint<Empty>(method: "GET", path: "/t"))
            XCTFail("expected APIError.offline, got success")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("expected APIError, got \(error)")
        }
    }

    private struct Empty: Decodable, Sendable {}

    private func makeClient(statusCode: Int, body: String) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.nextResponse = (statusCode, body)
        StubProtocol.nextError = nil
        let session = URLSession(configuration: config)
        return APIClient(
            baseURL: URL(string: "https://api.test")!,
            session: session
        ) { nil }
    }
}

/// `URLProtocol` subclass that short-circuits every request to the
/// values set in its static fields. Tests mutate `nextResponse` /
/// `nextError` before each call.
///
/// - Note: Swift 6 strict concurrency flags `static var` as shared
///   mutable state; tests run serially, so `nonisolated(unsafe)` is
///   the pragmatic fix here.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var nextResponse: (Int, String) = (200, "")
    nonisolated(unsafe) static var nextError: URLError?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.nextError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let (code, body) = Self.nextResponse
        let resp = HTTPURLResponse(
            url: request.url!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: .utf8) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
