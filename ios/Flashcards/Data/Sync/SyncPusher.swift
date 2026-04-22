//
//  SyncPusher.swift
//  Flashcards
//
//  Purpose: Drains the PendingMutationEntity queue and POSTs grouped batches
//           to /api/v1/sync/push. Deletes accepted mutations; marks rejected
//           ones with exponential backoff so a later call retries.
//
//  Dependencies: MutationQueue, Clock, APIClientProtocol/APIEndpoint.
//
//  Key concepts: Runs on @MainActor because the underlying MutationQueue/
//                ModelContext are main-actor-isolated. A single pushOnce()
//                call takes one batch (up to 100 mutations), groups them by
//                entityKey into the wire format, dispatches one POST, then
//                reconciles accepted/rejected IDs back into the queue. On
//                transport failure, every mutation in the batch is retry-
//                queued; on partial rejection, only the rejected IDs are
//                retry-queued. Successful IDs are deleted.
//                Emits sync.push.{ok,fail} analytics events.
//

import Foundation
import SwiftData

/// Decoded response body for POST /api/v1/sync/push.
public struct SyncPushResponse: Decodable, Sendable {
    /// Total number of records the server accepted and persisted.
    public let accepted: Int

    /// Records the server refused, with per-record reasons.
    public let rejected: [Rejected]

    /// Server wall-clock at the time of processing, in ms since Unix epoch.
    public let serverClockMs: Int64

    /// A single server-rejected record.
    public struct Rejected: Decodable, Sendable {
        /// `recordId` that was rejected.
        public let id: String

        /// Human-readable rejection reason (e.g. "stale", "invalid").
        public let reason: String
    }
}

/// Drains PendingMutationEntity into /v1/sync/push and reconciles outcomes.
///
/// All calls run on the main actor because they traverse MutationQueue and
/// the SwiftData ModelContext it wraps.
@MainActor
public final class SyncPusher {
    private let context: ModelContext
    private let api: APIClientProtocol

    /// Creates a pusher.
    ///
    /// - Parameters:
    ///   - context: The main SwiftData context; must be main-actor–isolated.
    ///   - api: Transport used to POST the batch. Typically the shared `APIClient`.
    public init(context: ModelContext, api: APIClientProtocol) {
        self.context = context
        self.api = api
    }

    /// Push up to `limit` pending mutations in one batch.
    ///
    /// On success: returns the server's `accepted` count; deletes accepted
    /// mutations; schedules rejected IDs for retry via exponential backoff.
    /// On transport failure: every mutation in the batch is retry-queued and
    /// the error is rethrown.
    ///
    /// - Parameter limit: Maximum mutations to send in this call. Default 100.
    /// - Returns: Number of records the server reported as accepted.
    /// - Throws: Any error thrown by the API transport or SwiftData context.
    public func pushOnce(limit: Int = 100) async throws -> Int {
        let q = MutationQueue(context: context)
        let batch = try q.takeBatch(now: Clock.nowMs(), limit: limit)
        guard !batch.isEmpty else {
            return 0
        }

        // Group payloads by entityKey for the wire format:
        // { "records": { "topics": [{…}, …], "decks": [{…}, …] } }
        var records: [String: [[String: Any]]] = [:]
        for m in batch {
            let payload = (try? JSONSerialization.jsonObject(with: m.payloadJSON)) as? [String: Any] ?? [:]
            records[m.entityKey, default: []].append(payload)
        }

        let body = try JSONSerialization.data(withJSONObject: [
            "client_clock_ms": Clock.nowMs(),
            "records": records,
        ] as [String: Any])

        do {
            let resp: SyncPushResponse = try await api.send(APIEndpoint<SyncPushResponse>(
                method: "POST",
                path: "/api/v1/sync/push",
                body: body,
                requiresAuth: true
            ))

            let rejectedIds = Set(resp.rejected.map(\.id))
            let nowMs = Clock.nowMs()
            for m in batch {
                if rejectedIds.contains(m.recordId) {
                    try q.markFailure(m, now: nowMs)
                } else {
                    try q.markSuccess(m)
                }
            }
            AnalyticsClient.track(
                "sync.push.ok",
                properties: [
                    "accepted": resp.accepted,
                    "rejected": resp.rejected.count,
                ]
            )
            return resp.accepted
        } catch {
            // Transport failure: retry-queue every mutation in this batch so
            // they are attempted again after the appropriate backoff window.
            let nowMs = Clock.nowMs()
            for m in batch {
                try? q.markFailure(m, now: nowMs)
            }
            AnalyticsClient.track(
                "sync.push.fail",
                properties: ["error": String(describing: error)]
            )
            throw error
        }
    }
}
