//
//  FlashcardsApp.swift
//  Flashcards
//
//  Purpose: `@main` entry point. Owns the single `AppState` instance and
//           injects it into the SwiftUI environment before mounting
//           `RootView`. Also owns the SwiftData `ModelContainer` that
//           backs all 10 persistent entity types and exposes it to the
//           view hierarchy via `.modelContainer(container)`.
//           Installs the scene-level `.onOpenURL` handler that converts
//           a magic-link universal link into a `Notification` broadcast
//           that `RootView` observes.
//  Dependencies: SwiftUI, SwiftData, `AppState`, `RootView`,
//                `MagicLinkConsumer`, `AnalyticsClient`, all *Entity types.
//  Key concepts: `AppState` is held via `@State` so SwiftUI owns its
//                lifetime for the life of the scene. `.environment(appState)`
//                publishes it for any descendant to observe. The
//                `.onOpenURL` closure is kept trivially Sendable — it
//                parses the URL synchronously and posts to
//                `NotificationCenter`, delegating the async token
//                exchange to `RootView`'s observer task. Analytics
//                initialisation (Sentry + PostHog) runs once in `init()`
//                before the scene is constructed so the SDKs are ready
//                for the first event.
//

import SwiftData
import SwiftUI

@main
struct FlashcardsApp: App {
    @State private var appState = AppState()
    let container: ModelContainer

    init() {
        AnalyticsClient.configure()
        let schema: [any PersistentModel.Type] = [
            UserEntity.self, TopicEntity.self, DeckEntity.self, SubTopicEntity.self,
            CardEntity.self, CardSubTopicEntity.self, ReviewEntity.self,
            SessionEntity.self, AssetEntity.self, PendingMutationEntity.self,
        ]
        do {
            if UITestLaunch.isActive {
                // UI tests run against an in-memory store for deterministic,
                // clean-slate state on every launch.
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Schema(schema), configurations: [config])
            } else {
                container = try ModelContainer(
                    for: UserEntity.self, TopicEntity.self, DeckEntity.self, SubTopicEntity.self,
                    CardEntity.self, CardSubTopicEntity.self, ReviewEntity.self,
                    SessionEntity.self, AssetEntity.self, PendingMutationEntity.self
                )
            }
        } catch {
            fatalError("Failed to initialise SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(appState)
                .modelContainer(container)
                .onOpenURL { url in
                    if let token = MagicLinkConsumer.extractToken(from: url) {
                        NotificationCenter.default.post(
                            name: .mwMagicLinkToken,
                            object: token
                        )
                    }
                }
        }
    }
}
