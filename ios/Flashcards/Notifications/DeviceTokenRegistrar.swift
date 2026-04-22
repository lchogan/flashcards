//
//  DeviceTokenRegistrar.swift
//  Flashcards
//
//  Purpose: One-shot hand-off of the APNs device token from
//           UIApplicationDelegate.didRegisterForRemoteNotificationsWithDeviceToken
//           to the backend via POST /v1/me/device-token. Idempotent on the
//           server so repeat calls (re-install, token rotation) are safe.
//  Dependencies: Foundation, APIClient.
//

import Foundation

public enum DeviceTokenRegistrar {
    /// Converts the raw `Data` token to hex and posts it to the server.
    /// Fires best-effort: a failed network round-trip just means the next
    /// launch retries.
    public static func register(tokenData: Data) async {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        let tokenStore = TokenStore()
        let api = APIClient(baseURL: URL(string: "http://localhost:8000")!) {
            await tokenStore.access()
        }

        struct Body: Encodable { let deviceToken: String }
        guard let body = try? JSONEncoder.api.encode(Body(deviceToken: hex)) else {
            return
        }
        _ = try? await api.send(APIEndpoint<Empty204>(
            method: "POST",
            path: "/api/v1/me/device-token",
            body: body,
            requiresAuth: true,
        ))
    }
}
