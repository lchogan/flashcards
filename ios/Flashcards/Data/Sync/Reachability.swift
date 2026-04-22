//
//  Reachability.swift
//  Flashcards
//
//  Purpose: Actor wrapping NWPathMonitor so SyncManager can gate syncNow
//           on network connectivity. Reports a single isConnected bool.
//
//  Dependencies: Foundation, Network.
//
//  Key concepts: Actor-isolated monitor lives for the app lifetime. Path
//                updates land on a background queue; the actor hop serialises
//                isConnected writes. Consumers await isConnected to get the
//                current snapshot — no callbacks, no publishers.
//

import Foundation
import Network

/// Actor-based reachability probe. Reports whether any interface currently
/// satisfies NWPathMonitor's reachability check.
public actor Reachability {
    private let monitor = NWPathMonitor()
    /// True when NWPathMonitor reports any satisfying interface.
    public private(set) var isConnected: Bool = false

    /// Creates the reachability actor wrapping NWPathMonitor.
    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.updateConnected(path.status == .satisfied)
            }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    /// Actor-internal setter used by the path update handler.
    private func updateConnected(_ value: Bool) {
        isConnected = value
    }
}
