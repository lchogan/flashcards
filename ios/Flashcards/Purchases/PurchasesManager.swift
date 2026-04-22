//
//  PurchasesManager.swift
//  Flashcards
//
//  Purpose: StoreKit 2 facade. Loads products, runs in-app purchases, listens
//           to transaction updates, and pipes signed JWS receipts to the
//           backend for server-side verification + plan assignment.
//  Dependencies: Foundation, StoreKit, Observation, APIClientProtocol.
//  Key concepts: Current-entitlement is NOT derived on-device — StoreKit's
//                `Transaction.currentEntitlement` is only used to surface
//                receipts to the server. The server's
//                `/v1/subscriptions/verify` response is the authority.
//

import Foundation
import Observation
import StoreKit

/// Top-level shape of the client→server verify handshake response.
public struct PurchaseVerifyResponse: Decodable, Sendable {
    public let planKey: String
    public let subscriptionStatus: String
    public let subscriptionExpiresAt: Date?
}

/// Outcome of a StoreKit purchase attempt.
public enum PurchaseOutcome: Equatable, Sendable {
    case success
    case userCancelled
    case pending
}

/// StoreKit 2 facade + server-verify bridge.
///
/// Call `load()` once near app boot to fetch products and start listening for
/// transaction updates. Views trigger `purchase(productId:)` from the paywall;
/// settings screens trigger `restore()`. Every successful transaction is
/// forwarded to `/v1/subscriptions/verify` and, on success, kicks an
/// `EntitlementsManager.load(force: true)` so the UI re-gates immediately.
@Observable
@MainActor
public final class PurchasesManager {
    public static let plusMonthlyProductId = "com.lukehogan.flashcards.plus.monthly"
    public static let plusAnnualProductId = "com.lukehogan.flashcards.plus.annual"

    public private(set) var products: [Product] = []
    public private(set) var isLoaded = false

    private let api: APIClientProtocol
    private let refreshEntitlements: @Sendable () async -> Void
    private var updatesTask: Task<Void, Never>?

    public init(
        api: APIClientProtocol,
        refreshEntitlements: @Sendable @escaping () async -> Void = {},
    ) {
        self.api = api
        self.refreshEntitlements = refreshEntitlements
    }

    /// Loads the two Plus product IDs from the App Store and starts the
    /// transaction-update listener. Idempotent.
    public func load() async {
        if !isLoaded {
            do {
                products = try await Product.products(for: [
                    Self.plusMonthlyProductId,
                    Self.plusAnnualProductId,
                ])
                isLoaded = true
            } catch {
                products = []
            }
        }
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else {
                        return
                    }
                    await self.handle(update)
                }
            }
        }
    }

    // PurchasesManager lives for the app lifetime, so `deinit` in practice
    // never fires. Cancelling `updatesTask` from a nonisolated deinit on iOS 17
    // is a Swift-6 strict-concurrency violation; skip it and rely on process
    // termination to tear down the transaction-update listener.

    /// Kicks off a purchase. Server-side verify runs on success.
    public func purchase(productId: String) async throws -> PurchaseOutcome {
        guard let product = products.first(where: { $0.id == productId }) else {
            throw PurchasesError.productUnavailable(productId)
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                try await verifyWithBackend(jws: verification.jwsRepresentation)
                await transaction.finish()
                await refreshEntitlements()
                return .success
            case .unverified:
                throw PurchasesError.unverifiedTransaction
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// Re-verifies whatever the device already has with the App Store +
    /// backend. Used by the "Restore purchases" button on the paywall and in
    /// Settings.
    public func restore() async throws {
        try await AppStore.sync()
        var forwarded = false
        for await result in Transaction.currentEntitlements {
            if case .verified = result {
                try await verifyWithBackend(jws: result.jwsRepresentation)
                forwarded = true
            }
        }
        if forwarded {
            await refreshEntitlements()
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else {
            return
        }
        try? await verifyWithBackend(jws: update.jwsRepresentation)
        await transaction.finish()
        await refreshEntitlements()
    }

    private func verifyWithBackend(jws: String) async throws {
        struct Body: Encodable { let jws: String }
        let body = try JSONEncoder.api.encode(Body(jws: jws))
        let endpoint = APIEndpoint<PurchaseVerifyResponse>(
            method: "POST",
            path: "/api/v1/subscriptions/verify",
            body: body,
            requiresAuth: true,
        )
        _ = try await api.send(endpoint)
    }
}

public enum PurchasesError: Error, Equatable {
    case productUnavailable(String)
    case unverifiedTransaction
}
