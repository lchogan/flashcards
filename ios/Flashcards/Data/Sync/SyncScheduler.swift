//
//  SyncScheduler.swift
//  Flashcards
//
//  Purpose: Drives SyncManager on a 5-minute background tick plus a
//           foreground-resume trigger. Keeps a single Task<Void, Never>
//           alive so start() is idempotent.
//
//  Dependencies: SyncManager.
//
//  Key concepts: @MainActor aligns with SyncManager. The tick loop sleeps
//                between cycles; cancellation uses Task.isCancelled so
//                stop() returns promptly. onForeground spawns a one-shot
//                Task that schedules a single syncNow — it does NOT race
//                with the tick loop because syncNow guards its own
//                isSyncing flag.
//

import Foundation

/// Periodic and event-driven trigger for SyncManager.syncNow().
@MainActor
public final class SyncScheduler {
    private let manager: SyncManager
    private var timerTask: Task<Void, Never>?

    /// 5 minutes expressed in nanoseconds for Task.sleep(nanoseconds:).
    private static let tickInterval: UInt64 = 5 * 60 * 1_000_000_000

    public init(manager: SyncManager) {
        self.manager = manager
    }

    /// Begin periodic background ticks. Calling again cancels the prior task.
    public func start() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.tickInterval)
                if Task.isCancelled {
                    return
                }
                await self?.manager.syncNow()
            }
        }
    }

    /// Stop the periodic tick. Safe to call multiple times.
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Trigger an immediate sync, e.g. from scenePhase == .active.
    public func onForeground() {
        Task { [weak self] in
            await self?.manager.syncNow()
        }
    }
}
